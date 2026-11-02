# PortoTrack — Operações Portuárias e Comércio Exterior

MVP mobile em **Flutter** para acompanhar o ciclo operacional de cargas e
contêineres dentro de um terminal portuário: onde a carga está, em que etapa
se encontra, quais eventos já ocorreram, se há pendências e qual é a próxima
etapa.

## Módulos

| Módulo | Quem acessa | O que faz |
|---|---|---|
| **GRID de cargas** (principal) | Todos | Tabela paginada com colunas que variam por perfil, busca, filtro por status, filtro "com pendências", ordenação por coluna, células editáveis (✎) e ações rápidas por linha |
| **Dashboard** | Operador+ | Indicadores (no terminal, chegadas 24h, pendências, inspeção, retiradas), cargas por etapa, gate in × gate out em 7 dias, ocupação por bloco, tempos médios, pendências prioritárias. Supervisor+ vê produtividade da equipe e ocorrências por tipo; Admin vê usuários por perfil |
| **Documentos** | Todos (transportador só os da sua empresa) | Upload de NF, DANFE, DI, DUIMP, DU-E, BL, CE Mercante, Packing List; validação da chave de acesso NF-e; aba de pendências documentais |
| Detalhe da carga | Todos | Situação atual, linha do fluxo, pendências, informações (filtradas por nível), documentos e histórico de movimentações |
| Usuários | Admin | Hierarquia de acesso e alteração de perfil dos usuários |
| Perfil | Todos | Dados do usuário e lista de permissões efetivas |

Além de Login e Cadastro (com validação), são 7 telas funcionais.

## Perfis de acesso (hierarquia cumulativa)

| Nível | Perfil | Colunas no GRID | Principais permissões |
|---|---|---|---|
| 1 | Transportador | 7 | Vê **apenas cargas da sua transportadora** (CNPJ); envia documentos |
| 2 | Equipe de Gate | 10 | Vê todas as cargas; registra **Recepcionado** (gate in) e **Retirado** (gate out) |
| 3 | Conferente | 15 | Armazena, movimenta, envia à inspeção, registra ocorrências, vê quem registrou cada evento |
| 4 | Operador Portuário | 17 | Cadastra/edita cargas, resolve ocorrências, acessa o **Dashboard** |
| 5 | Supervisor Operacional | 18 | **Libera** cargas, exclui documentos, vê produtividade da equipe |
| 6 | Administrador | 18 | Exclui cargas e gerencia usuários/perfis |

As permissões são aplicadas em três camadas: interface (telas/botões/colunas),
regras de negócio no app (`BusinessRules`) e banco (RLS + função
`registrar_evento` no Supabase).

## Fluxo operacional e regras de negócio

```
Previsto → Recepcionado → Armazenado ⇄ Em inspeção → Liberado → Retirado
                       └──────────→ Em inspeção
```

- Sequência validada: não é possível retirar antes de liberar; retirado não volta para nenhuma etapa.
- Todo evento registra **data e horário** (obrigatórios, não podem estar no futuro nem antes do último evento).
- Informações adicionais por etapa:
  - **Recepcionado**: placa (Mercosul/antiga), motorista e peso bruto (≤ 40.000 kg)
  - **Armazenado / Movimentação**: posição no pátio no formato Bloco-Fila-Altura (`A-12-03`)
  - **Em inspeção**: órgão (Receita, MAPA, ANVISA, PF) e motivo
  - **Liberado**: nº do documento de liberação, **nenhuma ocorrência aberta** e documentos obrigatórios (NF/DANFE + DI/DUIMP/DU-E)
  - **Retirado**: placa e motorista de saída
- Número do contêiner validado pelo **dígito verificador ISO 6346**; CNPJ e chave NF-e validados por módulo 11.
- **Pendências calculadas**: ocorrência aberta (alta), chegada atrasada, documento ausente, inspeção > 48h (média), sem posição > 6h, liberado aguardando retirada > 72h (baixa).

## Requisitos da atividade × implementação

| Requisito | Onde |
|---|---|
| Flutter | todo o projeto |
| Login e cadastro com validação | `ui/auth/login_page.dart`, `ui/auth/signup_page.dart` |
| ≥ 4 telas além de login/cadastro | GRID, Detalhe, Nova/Editar carga, Dashboard, Documentos, Usuários, Perfil |
| Perfis de usuário | `models/user_role.dart`, `services/permissions.dart` |
| Navegação com permissões | `ui/shell/app_shell.dart`, `PermissionGuard` em `ui/widgets/common.dart` |
| Formulário com validação | `core/validators.dart`, `carga_form_page.dart`, `evento_form_sheet.dart`, `upload_documento_sheet.dart` |
| Listagem | GRID (`PaginatedDataTable`), Documentos, Usuários |
| Busca, filtro, ordenação | GRID (busca, chips de status/pendências, ordenação por coluna), Documentos |
| Gerenciamento de estado | `provider` + `ChangeNotifier` (`lib/state/`) |
| Persistência remota | Supabase: Auth, Postgres, Storage (`data/supabase_repository.dart`, `supabase/schema.sql`) |
| Integração com API | **BrasilAPI** (consulta de CNPJ da transportadora) + API própria (RPC `registrar_evento`) |
| Tratamento de erros | `AppException`, tradução de erros Supabase/Auth/Storage, `ErrorView`, `ErrosBox` |
| Feedback visual | SnackBars de sucesso/erro, loaders em botões, `LinearProgressIndicator` em upload, confirmações |
| Organização em arquivos/classes | ver estrutura abaixo |
| WidgetTree | `docs/WIDGET_TREE.md` e `docs/img/*.png` |

## Estrutura

```
lib/
  main.dart                 # inicialização (Supabase ou modo demonstração)
  app.dart                  # MultiProvider, MaterialApp, AuthGate
  core/                     # config, exceções, formatadores, validadores
  models/                   # Carga, StatusCarga, EventoOperacional, Documento, AppUser, UserRole, Pendencia
  services/                 # BusinessRules, Permissoes, BrasilApiService
  data/                     # PortoRepository (contrato), SupabaseRepository, DemoRepository + seed
  state/                    # AuthController, CargasController, UsuariosController, NavegacaoController
  ui/
    auth/  shell/  cargas/  dashboard/  documentos/  admin/  perfil/  widgets/
supabase/schema.sql         # tabelas, triggers, RPC registrar_evento, RLS, bucket Storage
supabase/seed.sql           # dados opcionais
test/regras_negocio_test.dart
docs/WIDGET_TREE.md
```

## Como executar

Requisitos: Flutter **3.35+** (Dart 3.9+).

```bash
cd porto_track
flutter create . --platforms=android,ios,web --project-name porto_track   # gera as pastas de plataforma
flutter pub get
flutter test
```

### Modo demonstração (sem backend)

```bash
flutter run
```

Os dados ficam em memória. Na tela de login, toque em um perfil para preencher
o acesso. Todas as contas usam a senha `porto123`:

| Perfil | E-mail |
|---|---|
| Administrador | admin@porto.com |
| Supervisor | supervisor@porto.com |
| Operador | operador@porto.com |
| Conferente | conferente@porto.com |
| Gate | gate@porto.com |
| Transportador (TransLog) | transportador@porto.com |

Para testar o upload de DANFE/NF use a chave válida
`35261100000000000001550010000123451000123453`. Para cadastrar uma carga, use
por exemplo o contêiner `CSQU3054383` e o CNPJ `33.000.167/0001-01` (consulta
real na BrasilAPI).

### Com Supabase

1. Crie um projeto em supabase.com.
2. No **SQL Editor**, execute `supabase/schema.sql` (e, se quiser, `supabase/seed.sql`).
3. Em *Authentication → Providers → Email*, desative "Confirm email" para facilitar os testes.
4. Rode o app com as credenciais:
   ```bash
   flutter run --dart-define=SUPABASE_URL=https://SEU-PROJETO.supabase.co \
               --dart-define=SUPABASE_ANON_KEY=SUA_ANON_KEY
   ```
5. Cadastre-se pelo app (o perfil inicial é Transportador) e promova a si mesmo
   a administrador no SQL Editor:
   ```sql
   update public.profiles set papel = 'admin' where email = 'seu.email@exemplo.com';
   ```
   Depois, promova os demais usuários pela tela **Usuários**.

> Android: para builds *release*, confirme que `android/app/src/main/AndroidManifest.xml`
> contém `<uses-permission android:name="android.permission.INTERNET"/>`.

## Roteiro sugerido de apresentação

1. Entrar como **Transportador** → GRID com 7 colunas e só as cargas da TransLog; enviar um DANFE.
2. Entrar como **Gate** → registrar a recepção de `MSCU1234566` (placa, motorista, peso).
3. Entrar como **Conferente** → armazenar em `A-05-02`; tentar liberar (bloqueado: requer Supervisor).
4. Entrar como **Supervisor** → tentar liberar `CMAU7890…` (bloqueado: ocorrência aberta e checklist); liberar `MAEU6789…`; ver Dashboard com produtividade.
5. Entrar como **Admin** → promover um usuário na tela Usuários.
