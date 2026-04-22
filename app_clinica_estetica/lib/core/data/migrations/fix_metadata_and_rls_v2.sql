-- 1. Adicionar coluna 'metadata' na tabela 'contas' (Causa do erro no pagamento)
DO $$ 
BEGIN 
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'contas' AND column_name = 'metadata') THEN
        ALTER TABLE public.contas ADD COLUMN metadata JSONB DEFAULT '{}'::jsonb;
    END IF;
END $$;

-- 2. Garantir que 'dashboard_atividades' também tenha a coluna 'metadata' (Garantia de integridade)
DO $$ 
BEGIN 
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'dashboard_atividades' AND column_name = 'metadata') THEN
        ALTER TABLE public.dashboard_atividades ADD COLUMN metadata JSONB DEFAULT '{}'::jsonb;
    END IF;
END $$;

-- 3. Corrigir RLS da tabela 'vendas_produtos' para que o cliente possa ver suas compras
-- Primeiro removemos a política restritiva se existir
DROP POLICY IF EXISTS "Clientes podem ver suas próprias compras" ON public.vendas_produtos;

-- Criamos a política correta
CREATE POLICY "Clientes podem ver suas próprias compras"
ON public.vendas_produtos
FOR SELECT
TO authenticated
USING (
    (auth.uid() = cliente_id) OR 
    (EXISTS (
        SELECT 1 FROM public.perfis 
        WHERE id = auth.uid() AND (tipo = 'admin' OR tipo = 'profissional')
    ))
);

-- 4. Ajustar visibilidade da tabela 'historico_estoque' (Admin e Profissionais)
DROP POLICY IF EXISTS "Apenas admin e profissionais veem histórico" ON public.historico_estoque;
CREATE POLICY "Apenas admin e profissionais veem histórico"
ON public.historico_estoque
FOR ALL
TO authenticated
USING (
    EXISTS (
        SELECT 1 FROM public.perfis 
        WHERE id = auth.uid() AND (tipo = 'admin' OR tipo = 'profissional')
    )
);

-- 5. Atualizar função de processamento de venda para garantir que preencha o metadata se necessário
-- (Opcional, mas recomendado para rastreabilidade)
CREATE OR REPLACE FUNCTION public.fn_processar_venda_produto()
RETURNS trigger AS $$
DECLARE
    v_item RECORD;
BEGIN
    -- Registro no financeiro
    INSERT INTO public.contas (
        cliente_id,
        profissional_id,
        descricao,
        valor,
        tipo,
        status,
        data_vencimento,
        metadata
    ) VALUES (
        NEW.cliente_id,
        NEW.profissional_id,
        'Venda de Produto: ' || (SELECT nome FROM public.produtos WHERE id = NEW.produto_id),
        NEW.valor_total,
        'receita',
        CASE WHEN NEW.status_pagamento = 'pago' THEN 'pago' ELSE 'pendente' END,
        CURRENT_DATE,
        jsonb_build_object(
            'venda_id', NEW.id,
            'produto_id', NEW.produto_id,
            'quantidade', NEW.quantidade
        )
    );

    -- Log de atividade no dashboard
    INSERT INTO public.dashboard_atividades (
        tipo,
        titulo,
        descricao,
        metadata
    ) VALUES (
        'venda',
        'Venda de Produto',
        'Produto vendido para ' || (SELECT nome_completo FROM public.perfis WHERE id = NEW.cliente_id),
        jsonb_build_object(
            'venda_id', NEW.id,
            'cliente_id', NEW.cliente_id,
            'valor', NEW.valor_total
        )
    );

    -- Atualiza estoque
    UPDATE public.produtos
    SET estoque_atual = estoque_atual - NEW.quantidade
    WHERE id = NEW.produto_id;

    -- Registra no histórico de estoque
    INSERT INTO public.historico_estoque (
        produto_id,
        tipo_movimentacao,
        quantidade,
        motivo,
        usuario_id
    ) VALUES (
        NEW.produto_id,
        'saida',
        NEW.quantidade,
        'Venda (ID: ' || NEW.id || ')',
        NEW.profissional_id
    );

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;
