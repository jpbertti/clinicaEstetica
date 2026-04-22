
-- SQL Migration: Fix Dashboard Activities Metadata column and RPC
-- This script ensures the metadata column exists and the RPC function is updated.

-- 1. Ensure the column exists
DO $$ 
BEGIN
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
                   WHERE table_name='dashboard_atividades' AND column_name='metadata') THEN
        ALTER TABLE public.dashboard_atividades ADD COLUMN metadata JSONB DEFAULT '{}'::jsonb;
    END IF;
END $$;

-- 2. Update/Create the RPC function
CREATE OR REPLACE FUNCTION public.registrar_atividade_dashboard(
    p_tipo TEXT,
    p_titulo TEXT,
    p_descricao TEXT,
    p_metadata JSONB DEFAULT '{}'::jsonb,
    p_user_id UUID DEFAULT NULL
)
RETURNS VOID AS $$
BEGIN
    INSERT INTO public.dashboard_atividades (
        tipo,
        titulo,
        descricao,
        metadata,
        user_id,
        criado_em,
        is_lida
    ) VALUES (
        p_tipo,
        p_titulo,
        p_descricao,
        COALESCE(p_metadata, '{}'::jsonb),
        p_user_id,
        now(),
        false
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
