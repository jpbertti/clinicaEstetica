
-- SQL Migration: Fix Metadata Column and RLS Policies
-- Execute este script no SQL Editor do Supabase.

-- 1. ADICIONAR COLUNA METADATA NA TABELA CONTAS
-- Resolve o erro "column metadata does not exist" ao processar pagamentos
DO $$ 
BEGIN
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
                   WHERE table_name='contas' AND column_name='metadata') THEN
        ALTER TABLE public.contas ADD COLUMN metadata JSONB DEFAULT '{}'::jsonb;
    END IF;
END $$;

-- 2. CORRIGIR RLS PARA VENDAS_PRODUTOS
-- Permite que os clientes visualizem seu próprio histórico de compras
DROP POLICY IF EXISTS "Admins veem vendas" ON public.vendas_produtos;
DROP POLICY IF EXISTS "Admins gerenciam vendas" ON public.vendas_produtos;
DROP POLICY IF EXISTS "Clientes veem próprias compras" ON public.vendas_produtos;

CREATE POLICY "Vendas visíveis para dono/admin" ON public.vendas_produtos 
    FOR SELECT 
    TO authenticated 
    USING (auth.uid() = cliente_id OR public.is_admin());

CREATE POLICY "Admins gerenciam vendas" ON public.vendas_produtos 
    FOR ALL 
    TO authenticated 
    USING (public.is_admin())
    WITH CHECK (public.is_admin());

-- 3. PERMISSÕES PARA HISTÓRICO DE ESTOQUE (Visualização do Admin)
DROP POLICY IF EXISTS "Histórico visível para todos autenticados" ON public.historico_estoque;
CREATE POLICY "Histórico visível para todos autenticados" ON public.historico_estoque
    FOR SELECT
    TO authenticated
    USING (true);

-- Feedback
SELECT 'Migração concluída: Coluna metadata adicionada e RLS atualizado.' as mensagem;
