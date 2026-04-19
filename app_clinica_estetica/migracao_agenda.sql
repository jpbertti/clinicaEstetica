-- Migração para Adicionar Funcionalidades de Horário de Almoço e Bloqueios Parciais no Supabase

-- 1. Adicionar campos de Horário de Almoço na tabela de perfis 
-- O profissional terá um horário de almoço padrão
ALTER TABLE public.perfis 
ADD COLUMN se_not_exists almoco_inicio TIME,
ADD COLUMN se_not_exists almoco_fim TIME;

-- 2. Adicionar campos de Início e Fim na tabela bloqueios_agenda
-- Isso permitirá fechar a agenda por dias inteiros (NULL) ou em períodos parciais no dia.
ALTER TABLE public.bloqueios_agenda 
ADD COLUMN se_not_exists hora_inicio TIME,
ADD COLUMN se_not_exists hora_fim TIME;

-- Para as bases que podem não suportar `se_not_exists` no ADD COLUMN do Supabase, 
-- rodar os comandos abaixo caso o de cima falhe:
-- ALTER TABLE public.perfis ADD COLUMN almoco_inicio TIME;
-- ALTER TABLE public.perfis ADD COLUMN almoco_fim TIME;
-- ALTER TABLE public.bloqueios_agenda ADD COLUMN hora_inicio TIME;
-- ALTER TABLE public.bloqueios_agenda ADD COLUMN hora_fim TIME;
