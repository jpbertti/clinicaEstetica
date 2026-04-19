-- PHASE 1: NO-SHOW STATUS SUPPORT
-- Update status check constraint for agendamentos table
DO $$ 
BEGIN
    -- Drop the old constraint
    ALTER TABLE agendamentos DROP CONSTRAINT IF EXISTS agendamentos_status_check;
    
    -- Add the new constraint with 'no_show'
    ALTER TABLE agendamentos ADD CONSTRAINT agendamentos_status_check 
    CHECK (status IN ('pendente', 'confirmado', 'concluido', 'cancelado', 'no_show'));
END $$;

-- PHASE 2: PER-DAY LUNCH HOUR SUPPORT
-- Create table for professional lunch breaks by day of week
CREATE TABLE IF NOT EXISTS horarios_almoco_profissional (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    profissional_id UUID NOT NULL REFERENCES perfis(id) ON DELETE CASCADE,
    dia_semana INT NOT NULL CHECK (dia_semana BETWEEN 0 AND 6), -- 0: Sunday, 6: Saturday
    hora_inicio TIME NOT NULL,
    hora_fim TIME NOT NULL,
    ativo BOOLEAN DEFAULT true,
    created_at TIMESTAMPTZ DEFAULT now(),
    UNIQUE(profissional_id, dia_semana)
);

-- Index for faster lookups during scheduling
CREATE INDEX IF NOT EXISTS idx_lunch_prof_id ON horarios_almoco_profissional(profissional_id);
CREATE INDEX IF NOT EXISTS idx_lunch_day_of_week ON horarios_almoco_profissional(dia_semana);

-- PHASE 3: PARTIAL DAY CLOSURE SUPPORT
-- Add columns to bloqueios_agenda to allow blocking specific time ranges
DO $$ 
BEGIN
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='bloqueios_agenda' AND column_name='hora_inicio') THEN
        ALTER TABLE bloqueios_agenda ADD COLUMN hora_inicio TIME;
    END IF;

    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='bloqueios_agenda' AND column_name='hora_fim') THEN
        ALTER TABLE bloqueios_agenda ADD COLUMN hora_fim TIME;
    END IF;

    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='bloqueios_agenda' AND column_name='profissional_id') THEN
        ALTER TABLE bloqueios_agenda ADD COLUMN profissional_id UUID REFERENCES perfis(id) ON DELETE CASCADE;
    END IF;
END $$;

COMMENT ON COLUMN bloqueios_agenda.hora_inicio IS 'Start time for partial day block. If NULL, the full day is blocked.';
COMMENT ON COLUMN bloqueios_agenda.hora_fim IS 'End time for partial day block. If NULL, the full day is blocked.';
COMMENT ON COLUMN bloqueios_agenda.profissional_id IS 'If set, indicates the block only applies to this professional. If NULL, applies to the entire clinic.';
