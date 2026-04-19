-- Tabela de Promoções para a tela inicial
CREATE TABLE IF NOT EXISTS public.promocoes (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    titulo TEXT NOT NULL,
    subtitulo TEXT NOT NULL,
    imagem_url TEXT NOT NULL,
    servico_id UUID REFERENCES public.servicos(id) ON DELETE SET NULL,
    ordem INT NOT NULL DEFAULT 0,
    ativo BOOLEAN NOT NULL DEFAULT true,
    criado_em TIMESTAMPTZ DEFAULT NOW(),
    atualizado_em TIMESTAMPTZ DEFAULT NOW()
);

-- Habilitar RLS
ALTER TABLE public.promocoes ENABLE ROW LEVEL SECURITY;

-- Políticas de RLS
CREATE POLICY "Promoções visíveis por todos" ON public.promocoes
    FOR SELECT USING (ativo = true);

CREATE POLICY "Admins podem tudo em promoções" ON public.promocoes
    FOR ALL USING (
        EXISTS (
            SELECT 1 FROM public.perfis
            WHERE id = auth.uid() AND tipo = 'admin'
        )
    );

-- Inserir dados iniciais (baseados nos cards atuais)
INSERT INTO public.promocoes (titulo, subtitulo, imagem_url, ordem)
VALUES 
('Limpeza de Pele Profunda', '30% de desconto hoje', 'https://images.unsplash.com/photo-1570172619644-dfd03ed5d881?w=800', 0),
('Massagem Relaxante', 'Ganhe uma esfoliação', 'https://images.unsplash.com/photo-1570172619644-dfd03ed5d881?w=800', 1),
('Botox Facial', 'Consulte condições especiais', 'https://images.unsplash.com/photo-1616394584738-fc6e612e71b9?w=800', 2);
