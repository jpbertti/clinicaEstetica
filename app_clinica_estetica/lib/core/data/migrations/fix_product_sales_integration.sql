
-- SQL Migration: Fix Product Sales Integration and Stock Duplication
-- This script should be run in the Supabase SQL Editor.

-- 1. CLEANUP: Drop ALL potentially conflicting triggers or functions on vendas_produtos
-- This prevents the "decrement by 2" issue (double decrement).
DROP TRIGGER IF EXISTS trg_venda_produto_processamento ON public.vendas_produtos;
DROP TRIGGER IF EXISTS trg_venda_produto_estoque ON public.vendas_produtos;
DROP TRIGGER IF EXISTS trg_vendas_estoque ON public.vendas_produtos;
DROP TRIGGER IF EXISTS trg_processar_venda_produto ON public.vendas_produtos;
DROP TRIGGER IF EXISTS trg_atualizar_estoque_venda ON public.vendas_produtos;
DROP TRIGGER IF EXISTS trg_venda_produto_financeiro ON public.vendas_produtos;

DROP FUNCTION IF EXISTS public.handle_venda_produto_processamento();
DROP FUNCTION IF EXISTS public.handle_venda_produto_financeiro();

-- 2. CREATE THE CONSOLIDATED PROCESSING FUNCTION
-- This function handles:
-- A. Stock decrement
-- B. Financial entry creation (so it appears in the Caixa)
-- C. Movement history logging
CREATE OR REPLACE FUNCTION public.handle_venda_produto_processamento()
RETURNS TRIGGER AS $$
DECLARE
    v_produto_nome TEXT;
BEGIN
    -- Obter nome do produto para registros relacionados
    -- Usando atribuição direta para máxima compatibilidade
    v_produto_nome := (SELECT nome FROM public.produtos WHERE id = NEW.produto_id LIMIT 1);

    -- A. ATUALIZAR ESTOQUE (DECREMENTAR)
    -- Decrementa exatamente a quantidade vendida.
    UPDATE public.produtos 
    SET estoque_atual = COALESCE(estoque_atual, 0) - NEW.quantidade,
        atualizado_em = now()
    WHERE id = NEW.produto_id;

    -- B. CRIAR REGISTRO NO FINANCEIRO (Tabela 'contas')
    -- Isso garante que a venda apareça no relatorio do caixa (AdminCaixaPage)
    -- Categoria 'venda_produto' e status 'pago' são fundamentais para o filtro do dashboard.
    INSERT INTO public.contas (
        titulo,
        valor,
        tipo_conta,
        status_pagamento,
        forma_pagamento,
        caixa_id,
        cliente_id,
        profissional_id,
        categoria,
        data_vencimento,
        data_pagamento,
        descricao,
        created_at
    ) VALUES (
        'Venda de Produto: ' || COALESCE(v_produto_nome, 'Indefinido'),
        NEW.valor_total,
        'receber',
        'pago',
        NEW.forma_pagamento,
        NEW.caixa_id,
        NEW.cliente_id,
        NEW.profissional_id,
        'venda_produto',
        CURRENT_DATE,
        now(),
        'Venda de ' || NEW.quantidade || ' unid. do produto ID: ' || NEW.produto_id,
        now()
    );

    -- C. REGISTRAR NO HISTÓRICO DE ESTOQUE
    -- Isso alimenta a visualização de movimentações no Admin
    INSERT INTO public.historico_estoque (
        produto_id,
        tipo_movimentacao,
        quantidade,
        motivo,
        criado_por,
        criado_em
    ) VALUES (
        NEW.produto_id,
        'saida',
        NEW.quantidade,
        'Venda direta (Ref: ' || NEW.id || ')',
        NEW.profissional_id,
        now()
    );

    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 3. APPLY THE TRIGGER (Definitive name)
CREATE TRIGGER trg_venda_produto_processamento_v2
AFTER INSERT ON public.vendas_produtos
FOR EACH ROW
EXECUTE FUNCTION public.handle_venda_produto_processamento();
