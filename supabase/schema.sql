-- =============================================================================
-- PortoTrack — esquema do banco (Supabase / PostgreSQL)
-- Execute no SQL Editor do Supabase. O script é idempotente.
-- =============================================================================

create extension if not exists pgcrypto;

-- -----------------------------------------------------------------------------
-- Tabelas
-- -----------------------------------------------------------------------------

create table if not exists public.profiles (
  id            uuid primary key references auth.users (id) on delete cascade,
  nome          text not null,
  email         text not null,
  papel         text not null default 'transportador'
                check (papel in ('transportador','gate','conferente','operador','supervisor','admin')),
  empresa       text,
  empresa_cnpj  text,
  criado_em     timestamptz not null default now()
);

create table if not exists public.cargas (
  id                   uuid primary key default gen_random_uuid(),
  conteiner            text not null unique check (conteiner ~ '^[A-Z]{3}[UJZ][0-9]{7}$'),
  booking              text not null,
  navio                text not null,
  viagem               text not null,
  transportadora       text not null,
  transportadora_cnpj  text,
  placa                text,
  motorista            text,
  peso_kg              numeric(10,2) check (peso_kg is null or (peso_kg > 0 and peso_kg <= 40000)),
  data_prevista        timestamptz not null,
  data_entrada         timestamptz,
  data_saida           timestamptz,
  posicao              text check (posicao is null or posicao ~ '^[A-Z]-[0-9]{2}-[0-9]{2}$'),
  status               text not null default 'previsto'
                       check (status in ('previsto','recepcionado','armazenado','em_inspecao','liberado','retirado')),
  criado_por           uuid references auth.users (id),
  criado_em            timestamptz not null default now(),
  atualizado_em        timestamptz not null default now()
);

create index if not exists cargas_status_idx on public.cargas (status);
create index if not exists cargas_transp_idx on public.cargas (transportadora_cnpj);

create table if not exists public.eventos (
  id               uuid primary key default gen_random_uuid(),
  carga_id         uuid not null references public.cargas (id) on delete cascade,
  tipo             text not null check (tipo in ('criacao','status','movimentacao','ocorrencia','resolucao')),
  status_anterior  text,
  status_novo      text,
  data_hora        timestamptz not null,           -- quando ocorreu (informado)
  registrado_em    timestamptz not null default now(), -- auditoria
  usuario_id       uuid references auth.users (id),
  usuario_nome     text not null default 'Sistema',
  dados            jsonb not null default '{}'::jsonb,
  observacao       text
);

create index if not exists eventos_carga_idx on public.eventos (carga_id, data_hora);

create table if not exists public.documentos (
  id                uuid primary key default gen_random_uuid(),
  carga_id          uuid not null references public.cargas (id) on delete cascade,
  tipo              text not null check (tipo in ('nf','danfe','di','duimp','due','bl','ce_mercante','packing_list','outro')),
  numero            text,
  nome_arquivo      text not null,
  caminho           text not null,
  tamanho_bytes     bigint not null check (tamanho_bytes <= 10485760),
  mime_type         text not null,
  enviado_por       uuid references auth.users (id),
  enviado_por_nome  text not null,
  enviado_em        timestamptz not null default now()
);

create index if not exists documentos_carga_idx on public.documentos (carga_id);

-- -----------------------------------------------------------------------------
-- Funções auxiliares de permissão (hierarquia por nível)
-- -----------------------------------------------------------------------------

create or replace function public.nivel_papel(p text) returns int
language sql immutable as $$
  select case p
    when 'transportador' then 1 when 'gate' then 2 when 'conferente' then 3
    when 'operador' then 4 when 'supervisor' then 5 when 'admin' then 6
    else 0 end
$$;

create or replace function public.meu_nivel() returns int
language sql stable security definer set search_path = public as $$
  select coalesce((select public.nivel_papel(papel) from public.profiles where id = auth.uid()), 0)
$$;

create or replace function public.minha_empresa_cnpj() returns text
language sql stable security definer set search_path = public as $$
  select empresa_cnpj from public.profiles where id = auth.uid()
$$;

-- Transportador (nível 1) só enxerga cargas da própria empresa.
create or replace function public.pode_ver_carga(p_carga_id uuid) returns boolean
language sql stable security definer set search_path = public as $$
  select exists (
    select 1 from public.cargas c
    where c.id = p_carga_id
      and (public.meu_nivel() >= 2
           or (c.transportadora_cnpj is not null
               and c.transportadora_cnpj = public.minha_empresa_cnpj()))
  )
$$;

-- -----------------------------------------------------------------------------
-- Triggers
-- -----------------------------------------------------------------------------

-- Cria o perfil ao cadastrar usuário. Todo cadastro inicia como transportador.
create or replace function public.handle_new_user() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  insert into public.profiles (id, nome, email, papel, empresa, empresa_cnpj)
  values (
    new.id,
    coalesce(nullif(new.raw_user_meta_data->>'nome', ''), split_part(new.email, '@', 1)),
    new.email,
    'transportador',
    nullif(new.raw_user_meta_data->>'empresa', ''),
    nullif(new.raw_user_meta_data->>'empresa_cnpj', '')
  );
  return new;
end $$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

-- Evento automático de cadastro da carga.
create or replace function public.tg_carga_criada() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  insert into public.eventos (carga_id, tipo, status_novo, data_hora, usuario_id, usuario_nome)
  values (new.id, 'criacao', new.status, now(), auth.uid(),
          coalesce((select nome from public.profiles where id = auth.uid()), 'Sistema'));
  return new;
end $$;

drop trigger if exists carga_criada on public.cargas;
create trigger carga_criada
  after insert on public.cargas
  for each row execute function public.tg_carga_criada();

-- Atualiza "atualizado_em" e impede mudança de status fora do fluxo oficial.
create or replace function public.tg_carga_update() returns trigger
language plpgsql as $$
begin
  if new.status is distinct from old.status
     and coalesce(current_setting('app.via_registrar_evento', true), '') <> 'on' then
    raise exception 'O status só pode ser alterado registrando um evento.';
  end if;
  if tg_op = 'UPDATE' and new.status = old.status and old.status <> 'previsto'
     and new.conteiner is distinct from old.conteiner then
    raise exception 'O número do contêiner só pode ser alterado enquanto a carga está prevista.';
  end if;
  new.atualizado_em := now();
  return new;
end $$;

drop trigger if exists carga_update on public.cargas;
create trigger carga_update
  before update on public.cargas
  for each row execute function public.tg_carga_update();

-- Documentos novos também atualizam a carga (ordenação do GRID).
create or replace function public.tg_documento_inserido() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  update public.cargas set atualizado_em = now() where id = new.carga_id;
  return new;
end $$;

drop trigger if exists documento_inserido on public.documentos;
create trigger documento_inserido
  after insert on public.documentos
  for each row execute function public.tg_documento_inserido();

-- -----------------------------------------------------------------------------
-- API própria: registro de eventos com validação das regras de negócio
-- (mesmas regras de lib/services/business_rules.dart).
-- -----------------------------------------------------------------------------

create or replace function public.registrar_evento(
  p_carga_id    uuid,
  p_tipo        text,
  p_status_novo text default null,
  p_data_hora   timestamptz default now(),
  p_dados       jsonb default '{}'::jsonb,
  p_observacao  text default null
) returns uuid
language plpgsql security definer set search_path = public as $$
declare
  v_carga      public.cargas%rowtype;
  v_nivel      int := public.meu_nivel();
  v_nome       text;
  v_ultimo     timestamptz;
  v_abertas    int;
  v_permitidos text[];
  v_minimo     int;
  v_id         uuid;
  v_dados      jsonb := coalesce(p_dados, '{}'::jsonb);
begin
  if auth.uid() is null then
    raise exception 'Usuário não autenticado.';
  end if;

  select * into v_carga from public.cargas where id = p_carga_id for update;
  if not found or not public.pode_ver_carga(p_carga_id) then
    raise exception 'Carga não encontrada ou sem acesso.';
  end if;

  select nome into v_nome from public.profiles where id = auth.uid();

  -- Data e horário obrigatórios e coerentes
  if p_data_hora is null then
    raise exception 'Informe a data e o horário do evento.';
  end if;
  if p_data_hora > now() + interval '5 minutes' then
    raise exception 'A data/hora do evento não pode estar no futuro.';
  end if;
  select max(data_hora) into v_ultimo from public.eventos where carga_id = p_carga_id;
  if v_ultimo is not null and p_data_hora < v_ultimo then
    raise exception 'A data/hora não pode ser anterior ao último evento registrado.';
  end if;

  select count(*) into v_abertas
  from public.eventos o
  where o.carga_id = p_carga_id and o.tipo = 'ocorrencia'
    and not exists (
      select 1 from public.eventos r
      where r.carga_id = p_carga_id and r.tipo = 'resolucao'
        and r.dados->>'ocorrencia_id' = o.id::text);

  perform set_config('app.via_registrar_evento', 'on', true);

  -- ----------------------------------------------------------- mudança de status
  if p_tipo = 'status' then
    v_permitidos := case v_carga.status
      when 'previsto'     then array['recepcionado']
      when 'recepcionado' then array['armazenado','em_inspecao']
      when 'armazenado'   then array['em_inspecao','liberado']
      when 'em_inspecao'  then array['armazenado','liberado']
      when 'liberado'     then array['retirado']
      else array[]::text[] end;

    if p_status_novo is null or not (p_status_novo = any (v_permitidos)) then
      if p_status_novo = 'retirado' then
        raise exception 'Um contêiner só pode ser retirado depois de ser liberado.';
      elsif v_carga.status = 'retirado' then
        raise exception 'Contêiner já retirado: não pode voltar para "%".', p_status_novo;
      end if;
      raise exception 'Transição não permitida: % → %.', v_carga.status, coalesce(p_status_novo, '?');
    end if;

    v_minimo := case p_status_novo
      when 'recepcionado' then 2 when 'retirado' then 2
      when 'armazenado' then 3 when 'em_inspecao' then 3
      when 'liberado' then 5 else 99 end;
    if v_nivel < v_minimo then
      raise exception 'Seu perfil não pode registrar o status "%".', p_status_novo;
    end if;

    -- Informações adicionais exigidas por status
    if p_status_novo in ('recepcionado','retirado') then
      if coalesce(v_dados->>'placa','') !~ '^[A-Z]{3}[0-9][A-Z0-9][0-9]{2}$' then
        raise exception 'Placa do veículo inválida.';
      end if;
      if coalesce(trim(v_dados->>'motorista'),'') = '' then
        raise exception 'Informe o motorista.';
      end if;
    end if;
    if p_status_novo = 'recepcionado' then
      if coalesce(v_dados->>'peso','') !~ '^[0-9]+(\.[0-9]+)?$' then
        raise exception 'Peso bruto inválido.';
      end if;
      if (v_dados->>'peso')::numeric <= 0 or (v_dados->>'peso')::numeric > 40000 then
        raise exception 'Peso bruto deve estar entre 1 e 40.000 kg.';
      end if;
    end if;
    if p_status_novo = 'armazenado'
       and coalesce(v_dados->>'posicao','') !~ '^[A-Z]-[0-9]{2}-[0-9]{2}$' then
      raise exception 'Posição inválida (formato Bloco-Fila-Altura, ex.: A-12-03).';
    end if;
    if p_status_novo = 'em_inspecao'
       and (coalesce(v_dados->>'orgao','') = '' or coalesce(trim(v_dados->>'motivo'),'') = '') then
      raise exception 'Informe o órgão e o motivo da inspeção.';
    end if;
    if p_status_novo = 'liberado' then
      if coalesce(trim(v_dados->>'documento_liberacao'),'') = '' then
        raise exception 'Informe o número do documento de liberação.';
      end if;
      if v_abertas > 0 then
        raise exception 'Existem % ocorrência(s) aberta(s). Resolva antes de liberar.', v_abertas;
      end if;
      if not exists (select 1 from public.documentos where carga_id = p_carga_id and tipo in ('nf','danfe')) then
        raise exception 'Documento obrigatório ausente: documento fiscal (NF ou DANFE).';
      end if;
      if not exists (select 1 from public.documentos where carga_id = p_carga_id and tipo in ('di','duimp','due')) then
        raise exception 'Documento obrigatório ausente: documento de despacho (DI, DUIMP ou DU-E).';
      end if;
    end if;

    insert into public.eventos (carga_id, tipo, status_anterior, status_novo, data_hora,
                                usuario_id, usuario_nome, dados, observacao)
    values (p_carga_id, 'status', v_carga.status, p_status_novo, p_data_hora,
            auth.uid(), coalesce(v_nome, 'Usuário'), v_dados, p_observacao)
    returning id into v_id;

    update public.cargas set
      status       = p_status_novo,
      placa        = case when p_status_novo in ('recepcionado','retirado') then v_dados->>'placa' else placa end,
      motorista    = case when p_status_novo in ('recepcionado','retirado') then v_dados->>'motorista' else motorista end,
      peso_kg      = case when p_status_novo = 'recepcionado' then (v_dados->>'peso')::numeric else peso_kg end,
      data_entrada = case when p_status_novo = 'recepcionado' then p_data_hora else data_entrada end,
      posicao      = case when p_status_novo = 'armazenado' then v_dados->>'posicao'
                          when p_status_novo = 'retirado' then null else posicao end,
      data_saida   = case when p_status_novo = 'retirado' then p_data_hora else data_saida end
    where id = p_carga_id;

  -- ------------------------------------------------------- movimentação no pátio
  elsif p_tipo = 'movimentacao' then
    if v_nivel < 3 then
      raise exception 'Seu perfil não pode movimentar contêineres.';
    end if;
    if v_carga.status not in ('recepcionado','armazenado','em_inspecao','liberado') then
      raise exception 'Não é possível movimentar uma carga com status "%".', v_carga.status;
    end if;
    if coalesce(v_dados->>'posicao','') !~ '^[A-Z]-[0-9]{2}-[0-9]{2}$' then
      raise exception 'Posição inválida (formato Bloco-Fila-Altura, ex.: A-12-03).';
    end if;
    if v_dados->>'posicao' = v_carga.posicao then
      raise exception 'A nova posição é igual à posição atual.';
    end if;
    v_dados := v_dados || jsonb_build_object('posicao_anterior', v_carga.posicao);

    insert into public.eventos (carga_id, tipo, data_hora, usuario_id, usuario_nome, dados, observacao)
    values (p_carga_id, 'movimentacao', p_data_hora, auth.uid(), coalesce(v_nome, 'Usuário'), v_dados, p_observacao)
    returning id into v_id;

    update public.cargas set posicao = v_dados->>'posicao' where id = p_carga_id;

  -- ------------------------------------------------------------------ ocorrência
  elsif p_tipo = 'ocorrencia' then
    if v_nivel < 3 then
      raise exception 'Seu perfil não pode registrar ocorrências.';
    end if;
    if v_carga.status = 'retirado' then
      raise exception 'A carga já foi retirada do terminal.';
    end if;
    if coalesce(v_dados->>'tipo_ocorrencia','') = ''
       or length(coalesce(trim(v_dados->>'descricao'),'')) < 5 then
      raise exception 'Informe o tipo e a descrição da ocorrência.';
    end if;

    insert into public.eventos (carga_id, tipo, data_hora, usuario_id, usuario_nome, dados, observacao)
    values (p_carga_id, 'ocorrencia', p_data_hora, auth.uid(), coalesce(v_nome, 'Usuário'), v_dados, p_observacao)
    returning id into v_id;

    update public.cargas set atualizado_em = now() where id = p_carga_id;

  -- ------------------------------------------------------------------- resolução
  elsif p_tipo = 'resolucao' then
    if v_nivel < 4 then
      raise exception 'Seu perfil não pode resolver ocorrências.';
    end if;
    if not exists (
      select 1 from public.eventos o
      where o.carga_id = p_carga_id and o.tipo = 'ocorrencia'
        and o.id::text = v_dados->>'ocorrencia_id'
        and not exists (select 1 from public.eventos r
                        where r.tipo = 'resolucao' and r.dados->>'ocorrencia_id' = o.id::text)) then
      raise exception 'Selecione uma ocorrência aberta.';
    end if;
    if length(coalesce(trim(v_dados->>'descricao'),'')) < 5 then
      raise exception 'Descreva a solução (mínimo 5 caracteres).';
    end if;

    insert into public.eventos (carga_id, tipo, data_hora, usuario_id, usuario_nome, dados, observacao)
    values (p_carga_id, 'resolucao', p_data_hora, auth.uid(), coalesce(v_nome, 'Usuário'), v_dados, p_observacao)
    returning id into v_id;

    update public.cargas set atualizado_em = now() where id = p_carga_id;

  else
    raise exception 'Tipo de evento inválido: %', p_tipo;
  end if;

  return v_id;
end $$;

revoke all on function public.registrar_evento(uuid, text, text, timestamptz, jsonb, text) from public, anon;
grant execute on function public.registrar_evento(uuid, text, text, timestamptz, jsonb, text) to authenticated;

-- -----------------------------------------------------------------------------
-- Row Level Security — quanto maior o nível, mais o usuário enxerga/faz
-- -----------------------------------------------------------------------------

alter table public.profiles   enable row level security;
alter table public.cargas     enable row level security;
alter table public.eventos    enable row level security;
alter table public.documentos enable row level security;

-- profiles: cada um vê o próprio; admin vê e altera todos
drop policy if exists profiles_select on public.profiles;
create policy profiles_select on public.profiles for select to authenticated
  using (id = auth.uid() or public.meu_nivel() >= 6);

drop policy if exists profiles_update on public.profiles;
create policy profiles_update on public.profiles for update to authenticated
  using (public.meu_nivel() >= 6 and id <> auth.uid())
  with check (public.meu_nivel() >= 6);

-- cargas
drop policy if exists cargas_select on public.cargas;
create policy cargas_select on public.cargas for select to authenticated
  using (public.meu_nivel() >= 2
         or (transportadora_cnpj is not null and transportadora_cnpj = public.minha_empresa_cnpj()));

drop policy if exists cargas_insert on public.cargas;
create policy cargas_insert on public.cargas for insert to authenticated
  with check (public.meu_nivel() >= 4 and status = 'previsto');

drop policy if exists cargas_update on public.cargas;
create policy cargas_update on public.cargas for update to authenticated
  using (public.meu_nivel() >= 4) with check (public.meu_nivel() >= 4);

drop policy if exists cargas_delete on public.cargas;
create policy cargas_delete on public.cargas for delete to authenticated
  using (public.meu_nivel() >= 6);

-- eventos: leitura conforme a carga; escrita somente via registrar_evento()
drop policy if exists eventos_select on public.eventos;
create policy eventos_select on public.eventos for select to authenticated
  using (public.pode_ver_carga(carga_id));

-- documentos
drop policy if exists documentos_select on public.documentos;
create policy documentos_select on public.documentos for select to authenticated
  using (public.pode_ver_carga(carga_id));

drop policy if exists documentos_insert on public.documentos;
create policy documentos_insert on public.documentos for insert to authenticated
  with check (public.pode_ver_carga(carga_id) and enviado_por = auth.uid());

drop policy if exists documentos_delete on public.documentos;
create policy documentos_delete on public.documentos for delete to authenticated
  using (public.meu_nivel() >= 5);

-- -----------------------------------------------------------------------------
-- Storage: bucket privado "documentos" (arquivos em <carga_id>/<arquivo>)
-- -----------------------------------------------------------------------------

insert into storage.buckets (id, name, public, file_size_limit)
values ('documentos', 'documentos', false, 10485760)
on conflict (id) do nothing;

drop policy if exists docs_storage_select on storage.objects;
create policy docs_storage_select on storage.objects for select to authenticated
  using (bucket_id = 'documentos'
         and public.pode_ver_carga(((storage.foldername(name))[1])::uuid));

drop policy if exists docs_storage_insert on storage.objects;
create policy docs_storage_insert on storage.objects for insert to authenticated
  with check (bucket_id = 'documentos'
              and public.pode_ver_carga(((storage.foldername(name))[1])::uuid));

drop policy if exists docs_storage_delete on storage.objects;
create policy docs_storage_delete on storage.objects for delete to authenticated
  using (bucket_id = 'documentos' and public.meu_nivel() >= 5);
