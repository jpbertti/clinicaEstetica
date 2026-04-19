-- Migration: Rename and add commission columns, and create professional_pacotes table

-- Rename existing commission column
ALTER TABLE perfis 
RENAME COLUMN comissao_percentual TO comissao_produtos_percentual;

-- Add new commission column for appointments
ALTER TABLE perfis 
ADD COLUMN comissao_agendamentos_percentual decimal DEFAULT 0;

-- Create junction table for professional <-> packages
CREATE TABLE IF NOT EXISTS profissional_pacotes (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    profissional_id UUID NOT NULL REFERENCES perfis(id) ON DELETE CASCADE,
    pacote_id UUID NOT NULL REFERENCES pacotes_templates(id) ON DELETE CASCADE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL,
    UNIQUE(profissional_id, pacote_id)
);

-- Enable RLS for the new table
ALTER TABLE profissional_pacotes ENABLE ROW LEVEL SECURITY;

-- Basic policy for profissional_pacotes (admin bypass)
CREATE POLICY "Admin full access on profissional_pacotes" 
ON profissional_pacotes FOR ALL 
USING (EXISTS (SELECT 1 FROM perfis WHERE id = auth.uid() AND tipo = 'admin'));

CREATE POLICY "Public read profissional_pacotes" 
ON profissional_pacotes FOR SELECT 
USING (true);
