-- =============================================================================
-- PortoTrack — dados iniciais opcionais (execute após schema.sql)
-- =============================================================================

-- 1) Promova seu usuário a administrador (troque o e-mail):
-- update public.profiles set papel = 'admin' where email = 'seu.email@exemplo.com';

-- 2) Cargas previstas de exemplo (o trigger cria o evento "criacao").
insert into public.cargas (conteiner, booking, navio, viagem, transportadora,
                           transportadora_cnpj, data_prevista)
values
  ('CSQU3054383', 'BKG482137', 'MV ATLÂNTICO SUL', '045S', 'TransLog Cargas Ltda',
   '12345678000195', now() + interval '6 hours'),
  ('MSCU1234566', 'BKG482174', 'MV CORAL BAY', '112N', 'Rodomar Transportes S.A.',
   '45678912000155', now() + interval '1 day'),
  ('MAEU7654320', 'BKG482211', 'MV ORIENT STAR', '019E', 'Santos Express Logística',
   '78912345000109', now() - interval '20 hours')
on conflict (conteiner) do nothing;
