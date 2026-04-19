-- Adiciona coluna de comissão nos templates de pacotes
ALTER TABLE pacotes_templates ADD COLUMN IF NOT EXISTS comissao_percentual DOUBLE PRECISION DEFAULT 0;

-- Adiciona coluna de comissão nos pacotes contratados (para snapshot no momento da venda)
ALTER TABLE pacotes_contratados ADD COLUMN IF NOT EXISTS comissao_percentual DOUBLE PRECISION DEFAULT 0;


-- Optional: Update existing records to 0 if null
UPDATE pacotes_templates SET comissao_percentual = 0 WHERE comissao_percentual IS NULL;
