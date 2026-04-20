
-- SQL Migration: FINAL Fix for Product Sales and Financial Integration
-- This script ensures atomic stock management and visibility in CAIXA.

-- 1. CLEANUP: Drop ALL potentially conflicting triggers or functions on vendas_produtos
-- This solves the "subtraction by 2" bug.
DROP TRIGGER IF EXISTS trg_venda_produto_processamento ON public.vendas_produtos;
DROP TRIGGER IF EXISTS trg_venda_produto_processamento_v1 ON public.vendas_produtos;
DROP TRIGGER IF EXISTS trg_venda_produto_processamento_v2 ON public.vendas_produtos;
DROP TRIGGER IF EXISTS trg_venda_produto_estoque ON public.vendas_produtos;
DROP TRIGGER IF EXISTS trg_vendas_estoque ON public.vendas_produtos;
DROP TRIGGER IF EXISTS trg_processar_venda_produto ON public.vendas_produtos;
DROP TRIGGER IF EXISTS trg_atualizar_estoque_venda ON public.vendas_produtos;
DROP TRIGGER IF EXISTS trg_venda_produto_financeiro ON public.vendas_produtos;

DROP FUNCTION IF EXISTS public.handle_venda_produto_processamento();
DROP FUNCTION IF EXISTS public.fn_processar_venda_produto();

-- 2. UNIFIED PROCESSING FUNCTION
CREATE OR REPLACE FUNCTION public.fn_processar_venda_produto()
RETURNS TRIGGER AS $$
DECLARE
    v_produto_nome TEXT;
    v_estoque_atual INT;
    v_estoque_minimo INT;
    v_comissao_percentual DECIMAL;
    v_comissao_valor DECIMAL;
    v_net_valor DECIMAL;
    v_autor_nome TEXT;
BEGIN
    -- 1. Obter informações do produto
    SELECT nome, estoque_atual, estoque_minimo, comissao_percentual 
    INTO v_produto_nome, v_estoque_atual, v_estoque_minimo, v_comissao_percentual
    FROM public.produtos WHERE id = NEW.produto_id;

    -- 2. Calcular comissões (se houver profissional)
    IF NEW.profissional_id IS NOT NULL THEN
        v_comissao_valor := (NEW.valor_total * COALESCE(v_comissao_percentual, 0)) / 100;
        v_net_valor := NEW.valor_total - v_comissao_valor;
    ELSE
        v_comissao_valor := 0;
        v_net_valor := NEW.valor_total;
    END IF;

    -- 3. Atualizar a própria venda com a comissão calculada (se colunas existirem)
    BEGIN
        UPDATE public.vendas_produtos 
        SET comissao_aplicada = v_comissao_valor,
            valor_liquido = v_net_valor
        WHERE id = NEW.id;
    EXCEPTION WHEN OTHERS THEN
        -- Silenciosamente ignora se colunas não existirem
    END;

    -- 4. DECREMENTAR ESTOQUE (Ação principal)
    UPDATE public.produtos 
    SET estoque_atual = COALESCE(estoque_atual, 0) - NEW.quantidade
    WHERE id = NEW.produto_id;

    -- 5. Inserir no HISTÓRICO DE ESTOQUE
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

    -- 6. CRIAR REGISTRO NO FINANCEIRO (CONTAS)
    -- Fundamental para aparecer no AdminCaixaPage
    INSERT INTO public.contas (
        titulo,
        descricao,
        valor,
        tipo_conta,
        status_pagamento,
        categoria,
        forma_pagamento,
        cliente_id,
        profissional_id,
        data_vencimento,
        data_pagamento,
        caixa_id,
        criado_em
    ) VALUES (
        'Venda: ' || COALESCE(v_produto_nome, 'Produto'),
        'Venda de ' || NEW.quantidade || ' unid. do produto ' || COALESCE(v_produto_nome, '') || 
        ' (Comissão: ' || COALESCE(v_comissao_percentual, 0) || '%)',
        NEW.valor_total,
        'receber',
        'pago',
        'venda_produto',
        NEW.forma_pagamento,
        NEW.cliente_id,
        NEW.profissional_id,
        CURRENT_DATE,
        now(),
        NEW.caixa_id,
        now()
    );

    -- 7. Registrar na DASHBOARD_ATIVIDADES
    BEGIN
        PERFORM public.registrar_atividade_dashboard(
            'venda',
            'Venda',
            'Produto ' || COALESCE(v_produto_nome, 'Indefinido') || ' vendido por R$ ' || NEW.valor_total,
            jsonb_build_object('venda_id', NEW.id, 'produto', v_produto_nome)
        );
    EXCEPTION WHEN OTHERS THEN NULL;
    END;

    -- 8. Notificar se estoque estiver baixo
    IF (v_estoque_atual - NEW.quantidade) <= v_estoque_minimo THEN
        BEGIN
            PERFORM public.notificar_admins(
                'Estoque Baixo',
                'O produto ' || v_produto_nome || ' atingiu o nível crítico (' || (v_estoque_atual - NEW.quantidade) || ' unidades).',
                'estoque_baixo'
            );
        EXCEPTION WHEN OTHERS THEN NULL;
        END;
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 3. APPLY SINGLE DEFINITIVE TRIGGER
CREATE TRIGGER trg_venda_produto_processamento
AFTER INSERT ON public.vendas_produtos
FOR EACH ROW
EXECUTE FUNCTION public.fn_processar_venda_produto();
