-- ========================================================
-- SCRIPT DE ESTRUTURA COMPLETA E DADOS FICTﾃ垢IOS - CLﾃ康ICA ESTﾃ欝ICA
-- Limpa tudo e recria o banco de dados do zero corretamente (V5)
-- ========================================================

-- Garante que a extensﾃ｣o pgcrypto existe (para o crypt se necessﾃ｡rio)
CREATE EXTENSION IF NOT EXISTS pgcrypto;

-- --------------------------------------------------------
-- 0. LIMPEZA E CONFIGURAﾃ�髭S INICIAIS
-- --------------------------------------------------------

-- Limpeza total de tabelas para recriaﾃｧﾃ｣o limpa
DROP TABLE IF EXISTS public.pacote_servicos CASCADE;
DROP TABLE IF EXISTS public.pacotes_contratados CASCADE;
DROP TABLE IF EXISTS public.pacotes_templates CASCADE;
DROP TABLE IF EXISTS public.vendas_produtos CASCADE;
DROP TABLE IF EXISTS public.historico_estoque CASCADE;
DROP TABLE IF EXISTS public.produtos CASCADE;
DROP TABLE IF EXISTS public.dashboard_atividades CASCADE;
DROP TABLE IF EXISTS public.bloqueios_agenda CASCADE;
DROP TABLE IF EXISTS public.avaliacoes CASCADE;
DROP TABLE IF EXISTS public.agendamentos CASCADE;
DROP TABLE IF EXISTS public.profissional_servicos CASCADE;
DROP TABLE IF EXISTS public.profissional_pacotes CASCADE;
DROP TABLE IF EXISTS public.disponibilidade_profissional CASCADE;
DROP TABLE IF EXISTS public.horarios_almoco_profissional CASCADE;
DROP TABLE IF EXISTS public.horarios_trabalho_profissional CASCADE;
DROP TABLE IF EXISTS public.horarios_clinica CASCADE;
DROP TABLE IF EXISTS public.servicos CASCADE;
DROP TABLE IF EXISTS public.categorias CASCADE;
DROP TABLE IF EXISTS public.notificacoes CASCADE;
DROP TABLE IF EXISTS public.logs_admin CASCADE;
DROP TABLE IF EXISTS public.configuracoes_clinica CASCADE;
DROP TABLE IF EXISTS public.caixas CASCADE;
DROP TABLE IF EXISTS public.contas CASCADE;
DROP TABLE IF EXISTS public.promocoes CASCADE;
DROP TABLE IF EXISTS public.perfis CASCADE;



-- --------------------------------------------------------
-- 1. TABELAS PRINCIPAIS
-- --------------------------------------------------------

-- Tabela de Perfis
CREATE TABLE IF NOT EXISTS public.perfis (
    id UUID PRIMARY KEY, -- Relacionado ao auth.users(id) via aplicação
    nome_completo TEXT NOT NULL,
    email TEXT UNIQUE NOT NULL,
    telefone TEXT,
    tipo TEXT NOT NULL DEFAULT 'cliente' CHECK (tipo IN ('cliente', 'profissional', 'admin')),
    cargo TEXT,
    avatar_url TEXT,
    observacoes_internas TEXT,
    ativo BOOLEAN NOT NULL DEFAULT true,
    comissao_produtos_percentual DECIMAL(5,2) DEFAULT 0,
    comissao_agendamentos_percentual DECIMAL(5,2) DEFAULT 0,
    ultimo_login TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()),
    almoco_inicio TIME DEFAULT NULL,
    almoco_fim TIME DEFAULT NULL,
    criado_em TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- Tabela de Categorias
CREATE TABLE IF NOT EXISTS public.categorias (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    nome TEXT NOT NULL UNIQUE,
    icone_url TEXT,
    ordem INT DEFAULT 0,
    criado_em TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- Tabela de Serviﾃｧos (Procedimentos)
CREATE TABLE IF NOT EXISTS public.servicos (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    nome TEXT NOT NULL,
    descricao TEXT,
    preco DECIMAL(10,2) NOT NULL,
    preco_promocional DECIMAL(10,2),
    data_inicio_promocao TIMESTAMP WITH TIME ZONE,
    data_fim_promocao TIMESTAMP WITH TIME ZONE,
    duracao_minutos INT DEFAULT 60,
    categoria_id UUID REFERENCES public.categorias(id) ON DELETE SET NULL,
    ativo BOOLEAN DEFAULT true,
    imagem_url TEXT,
    admin_promocao_id UUID REFERENCES public.perfis(id),
    criado_em TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- Tabela de Templates de Pacotes
CREATE TABLE IF NOT EXISTS public.pacotes_templates (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    titulo TEXT NOT NULL,
    descricao TEXT,
    valor_total DECIMAL(10,2) NOT NULL,
    valor_promocional DECIMAL(10,2),
    data_inicio_promocao TIMESTAMP WITH TIME ZONE,
    data_fim_promocao TIMESTAMP WITH TIME ZONE,
    quantidade_sessoes INT NOT NULL,
    imagem_url TEXT,
    categoria_id UUID REFERENCES public.categorias(id) ON DELETE SET NULL,
    ativo BOOLEAN NOT NULL DEFAULT true,
    comissao_percentual DOUBLE PRECISION DEFAULT 0,
    admin_promocao_id UUID REFERENCES public.perfis(id),
    criado_em TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- Tabela de Junﾃｧﾃ｣o Pacote - Serviﾃｧos
CREATE TABLE IF NOT EXISTS public.pacote_servicos (
    pacote_id UUID NOT NULL REFERENCES public.pacotes_templates(id) ON DELETE CASCADE,
    servico_id UUID NOT NULL REFERENCES public.servicos(id) ON DELETE CASCADE,
    quantidade_sessoes INT NOT NULL DEFAULT 1 CHECK (quantidade_sessoes BETWEEN 1 AND 20),
    PRIMARY KEY (pacote_id, servico_id)
);

-- Tabela de Pacotes Contratados (Vendas de Pacotes)
CREATE TABLE IF NOT EXISTS public.pacotes_contratados (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    template_id UUID,
    cliente_id UUID NOT NULL,
    profissional_id UUID, -- NOVO: Profissional vinculado ao pacote
    valor_pago DECIMAL(10,2) NOT NULL,
    sessoes_totais INT NOT NULL,
    sessoes_realizadas INT NOT NULL DEFAULT 0,
    status TEXT NOT NULL DEFAULT 'ativo' CHECK (status IN ('ativo', 'finalizado', 'cancelado')),
    caixa_id UUID, -- Referﾃｪncia manual para evitar circularidade pesada se necessﾃ｡rio
    comissao_percentual DOUBLE PRECISION DEFAULT 0,
    criado_em TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL,

    -- Restriﾃｧﾃｵes de Chave Estrangeira Nomeadas (Melhora compatibilidade PostgREST)
    CONSTRAINT pacotes_contratados_template_id_fkey FOREIGN KEY (template_id) REFERENCES public.pacotes_templates(id) ON DELETE SET NULL,
    CONSTRAINT pacotes_contratados_cliente_id_fkey FOREIGN KEY (cliente_id) REFERENCES public.perfis(id) ON DELETE CASCADE,
    CONSTRAINT pacotes_contratados_profissional_id_fkey FOREIGN KEY (profissional_id) REFERENCES public.perfis(id) ON DELETE SET NULL
);

-- Tabela de Caixas
CREATE TABLE IF NOT EXISTS public.caixas (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    usuario_id UUID NOT NULL REFERENCES public.perfis(id),
    aberto_em TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL,
    fechado_em TIMESTAMP WITH TIME ZONE,
    saldo_inicial DECIMAL(10,2) NOT NULL DEFAULT 0,
    total_entradas DECIMAL(10,2) DEFAULT 0,
    total_saidas DECIMAL(10,2) DEFAULT 0,
    saldo_final_real DECIMAL(10,2),
    status TEXT NOT NULL DEFAULT 'aberto' CHECK (status IN ('aberto', 'fechado')),
    observacoes TEXT
);

-- Tabela de Agendamentos
CREATE TABLE IF NOT EXISTS public.agendamentos (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    cliente_id UUID NOT NULL REFERENCES public.perfis(id) ON DELETE CASCADE,
    profissional_id UUID NOT NULL REFERENCES public.perfis(id) ON DELETE CASCADE,
    servico_id UUID NOT NULL REFERENCES public.servicos(id) ON DELETE CASCADE,
    data_hora TIMESTAMP WITH TIME ZONE NOT NULL,
    valor_total DECIMAL(10,2),
    status TEXT NOT NULL DEFAULT 'pendente' CHECK (status IN ('pendente', 'confirmado', 'cancelado', 'concluido', 'ausente', 'no_show')),
    forma_pagamento TEXT CHECK (forma_pagamento IN ('pix', 'cartao_credito', 'cartao_debito', 'dinheiro', 'convenio')),
    parcelas INT DEFAULT 1,
    convenio_nome TEXT,
    observacoes TEXT,
    caixa_id UUID REFERENCES public.caixas(id),
    data_pagamento TIMESTAMP WITH TIME ZONE,
    pago BOOLEAN DEFAULT false,
    valor_comissao DECIMAL(10,2) DEFAULT 0,
    pacote_contratado_id UUID REFERENCES public.pacotes_contratados(id) ON DELETE SET NULL,
    sessao_numero INT, -- NOVO: Nﾃｺmero da sessﾃ｣o neste pacote
    criado_em TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL,
    CONSTRAINT chk_data_hora_futura CHECK (data_hora >= criado_em - interval '1 minute')
);

-- Tabela de Avaliaﾃｧﾃｵes
CREATE TABLE IF NOT EXISTS public.avaliacoes (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    agendamento_id UUID NOT NULL UNIQUE REFERENCES public.agendamentos(id) ON DELETE CASCADE,
    cliente_id UUID NOT NULL REFERENCES public.perfis(id),
    profissional_id UUID NOT NULL REFERENCES public.perfis(id),
    nota INT NOT NULL CHECK (nota BETWEEN 1 AND 5),
    comentario TEXT,
    tags JSONB DEFAULT '[]'::jsonb,
    fotos JSONB DEFAULT '[]'::jsonb,
    criado_em TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- --------------------------------------------------------
-- 2. TABELAS DE APOIO E CONFIGURAﾃ�グ
-- --------------------------------------------------------

CREATE TABLE IF NOT EXISTS public.profissional_servicos (
    profissional_id UUID REFERENCES public.perfis(id) ON DELETE CASCADE,
    servico_id UUID REFERENCES public.servicos(id) ON DELETE CASCADE,
    PRIMARY KEY (profissional_id, servico_id)
);

-- Vﾃｭnculo Profissional - Pacote
CREATE TABLE IF NOT EXISTS public.profissional_pacotes (
    profissional_id UUID REFERENCES public.perfis(id) ON DELETE CASCADE,
    pacote_id UUID REFERENCES public.pacotes_templates(id) ON DELETE CASCADE,
    PRIMARY KEY (profissional_id, pacote_id)
);

-- Disponibilidade Semanal
CREATE TABLE IF NOT EXISTS public.disponibilidade_profissional (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    profissional_id UUID NOT NULL REFERENCES public.perfis(id) ON DELETE CASCADE,
    dia_semana INTEGER NOT NULL CHECK (dia_semana >= 0 AND dia_semana <= 6),
    hora_inicio TIME NOT NULL,
    hora_fim TIME NOT NULL,
    UNIQUE (profissional_id, dia_semana, hora_inicio)
);

-- Horﾃ｡rios de Almoﾃｧo por Profissional (Especﾃｭfico por dia)
CREATE TABLE IF NOT EXISTS public.horarios_almoco_profissional (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    profissional_id UUID NOT NULL REFERENCES public.perfis(id) ON DELETE CASCADE,
    dia_semana INT NOT NULL CHECK (dia_semana BETWEEN 0 AND 6),
    hora_inicio TIME NOT NULL DEFAULT '12:00:00',
    hora_fim TIME NOT NULL DEFAULT '13:00:00',
    ativo BOOLEAN DEFAULT true,
    criado_em TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL,
    UNIQUE(profissional_id, dia_semana)
);

CREATE INDEX IF NOT EXISTS idx_lunch_prof_id ON public.horarios_almoco_profissional(profissional_id);
CREATE INDEX IF NOT EXISTS idx_lunch_day_of_week ON public.horarios_almoco_profissional(dia_semana);

-- NOVO: Horﾃ｡rios de Trabalho por Profissional (Granular)
CREATE TABLE IF NOT EXISTS public.horarios_trabalho_profissional (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    profissional_id UUID NOT NULL REFERENCES public.perfis(id) ON DELETE CASCADE,
    dia_semana INT NOT NULL CHECK (dia_semana BETWEEN 0 AND 6),
    hora_inicio TIME NOT NULL DEFAULT '08:00:00',
    hora_fim TIME NOT NULL DEFAULT '18:00:00',
    fechado BOOLEAN DEFAULT false,
    criado_em TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL,
    UNIQUE(profissional_id, dia_semana)
);

CREATE INDEX IF NOT EXISTS idx_work_prof_id ON public.horarios_trabalho_profissional(profissional_id);
CREATE INDEX IF NOT EXISTS idx_work_day_of_week ON public.horarios_trabalho_profissional(dia_semana);

-- Horﾃ｡rios de Funcionamento da Clﾃｭnica
CREATE TABLE IF NOT EXISTS public.horarios_clinica (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    dia_semana INT NOT NULL CHECK (dia_semana BETWEEN 0 AND 6),
    hora_inicio TIME NOT NULL DEFAULT '08:00',
    hora_fim TIME NOT NULL DEFAULT '18:00',
    fechado BOOLEAN DEFAULT false,
    UNIQUE (dia_semana)
);

-- Bloqueios de Agenda
CREATE TABLE IF NOT EXISTS public.bloqueios_agenda (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    profissional_id UUID REFERENCES public.perfis(id) ON DELETE CASCADE, 
    usuario_id UUID REFERENCES public.perfis(id) ON DELETE SET NULL, -- Novo: Quem realizou o bloqueio
    data DATE NOT NULL,
    hora_inicio TIME DEFAULT NULL,
    hora_fim TIME DEFAULT NULL,
    dia_todo BOOLEAN DEFAULT true,
    motivo TEXT,
    criado_em TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

COMMENT ON COLUMN public.bloqueios_agenda.hora_inicio IS 'Hora de inﾃｭcio para bloqueio parcial. Se NULL, o dia todo ﾃｩ bloqueado.';
COMMENT ON COLUMN public.bloqueios_agenda.hora_fim IS 'Hora de fim para bloqueio parcial. Se NULL, o dia todo ﾃｩ bloqueado.';
COMMENT ON COLUMN public.bloqueios_agenda.profissional_id IS 'Se definido, o bloqueio aplica-se apenas a este profissional. Se NULL, aplica-se a toda a clﾃｭnica.';


-- Notificaﾃｧﾃｵes do Sistema
CREATE TABLE IF NOT EXISTS public.notificacoes (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES public.perfis(id) ON DELETE CASCADE,
    remetente_id UUID REFERENCES public.perfis(id) ON DELETE SET NULL,
    titulo TEXT NOT NULL,
    mensagem TEXT NOT NULL,
    tipo TEXT NOT NULL DEFAULT 'sistema', 
    is_lida BOOLEAN DEFAULT FALSE,
    data_criacao TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()),
    metadata JSONB DEFAULT '{}'::jsonb
);


-- Configuraﾃｧﾃｵes da Clﾃｭnica
CREATE TABLE IF NOT EXISTS public.configuracoes_clinica (
    id SERIAL PRIMARY KEY,
    nome_comercial TEXT NOT NULL,
    endereco TEXT NOT NULL,
    telefone_fixo TEXT NOT NULL,
    telefone_fixo_ativo BOOLEAN DEFAULT TRUE,
    whatsapp TEXT NOT NULL,
    email_contato TEXT, -- NOVO
    logo_url TEXT,
    mapa_iframe TEXT,
    descricao TEXT,
    taxa_debito DECIMAL(5,2) DEFAULT 0,
    taxa_credito DECIMAL(5,2) DEFAULT 0,
    taxa_credito_parcelado DECIMAL(5,2) DEFAULT 0,
    taxa_pix DECIMAL(5,2) DEFAULT 0,
    atualizado_em TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- Tabela de Logs de Administraﾃｧﾃ｣o (Auditoria)
CREATE TABLE IF NOT EXISTS public.logs_admin (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    admin_id UUID NOT NULL REFERENCES public.perfis(id) ON DELETE CASCADE,
    admin_nome TEXT,
    acao TEXT NOT NULL,
    detalhes TEXT,
    tabela_afetada TEXT,
    item_id TEXT,
    criado_em TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- Tabela de Promoﾃｧﾃｵes (Banner Inicial)
CREATE TABLE IF NOT EXISTS public.promocoes (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    titulo TEXT NOT NULL,
    subtitulo TEXT NOT NULL,
    imagem_url TEXT NOT NULL,
    servico_id UUID REFERENCES public.servicos(id) ON DELETE SET NULL,
    pacote_id UUID REFERENCES public.pacotes_templates(id) ON DELETE SET NULL,
    ordem INT NOT NULL DEFAULT 0,
    ativo BOOLEAN NOT NULL DEFAULT true,
    criado_em TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL,
    atualizado_em TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);


-- Tabela de Contas (Financeiro: Pagar/Receber)
CREATE TABLE IF NOT EXISTS public.contas (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    titulo TEXT NOT NULL,
    descricao TEXT,
    valor DECIMAL(10,2) NOT NULL,
    tipo_conta TEXT NOT NULL CHECK (tipo_conta IN ('pagar', 'receber')),
    status_pagamento TEXT NOT NULL DEFAULT 'pendente' CHECK (status_pagamento IN ('pendente', 'pago', 'atrasado')),
    categoria TEXT, -- Ex: Aluguel, Produtos, Marketing, Salﾃ｡rio
    forma_pagamento TEXT, -- NOVO
    cliente_id UUID REFERENCES public.perfis(id), -- NOVO
    profissional_id UUID REFERENCES public.perfis(id), -- NOVO
    data_vencimento DATE NOT NULL,
    data_pagamento TIMESTAMP WITH TIME ZONE,
    caixa_id UUID REFERENCES public.caixas(id),
    criado_por UUID REFERENCES public.perfis(id) ON DELETE SET NULL,
    criado_em TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- Tabela de Produtos
CREATE TABLE IF NOT EXISTS public.produtos (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    nome TEXT NOT NULL,
    descricao TEXT,
    preco_custo DECIMAL(10,2),
    preco_venda DECIMAL(10,2) NOT NULL,
    comissao_percentual DECIMAL(5,2) DEFAULT 0,
    estoque_atual INT DEFAULT 0,
    estoque_minimo INT DEFAULT 0,
    data_vencimento DATE,
    imagem_url TEXT,
    categoria TEXT,
    ativo BOOLEAN NOT NULL DEFAULT true,
    criado_em TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);


-- Tabela de Vendas de Produtos
CREATE TABLE IF NOT EXISTS public.vendas_produtos (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    produto_id UUID NOT NULL REFERENCES public.produtos(id) ON DELETE CASCADE,
    caixa_id UUID NOT NULL REFERENCES public.caixas(id),
    cliente_id UUID REFERENCES public.perfis(id) ON DELETE SET NULL,
    profissional_id UUID REFERENCES public.perfis(id) ON DELETE SET NULL,
    usuario_id UUID REFERENCES public.perfis(id), -- Para compatibilidade com versﾃｵes anteriores se necessﾃ｡rio
    quantidade INT NOT NULL DEFAULT 1,
    valor_unitario DECIMAL(10,2) NOT NULL,
    valor_total DECIMAL(10,2) NOT NULL,
    forma_pagamento TEXT DEFAULT 'dinheiro',
    comissao_aplicada DECIMAL(5,2) DEFAULT 0,
    valor_comissao_bruta DECIMAL(10,2) DEFAULT 0,
    valor_comissao_liquida DECIMAL(10,2) DEFAULT 0,
    criado_em TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- Tabela de Atividades do Dashboard
CREATE TABLE IF NOT EXISTS public.dashboard_atividades (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tipo TEXT NOT NULL, -- 'agendamento', 'cliente', 'financeiro', 'configuracao', 'personalizado'
    titulo TEXT NOT NULL,
    descricao TEXT,
    metadata JSONB DEFAULT '{}'::jsonb,
    is_lida BOOLEAN DEFAULT FALSE,
    user_id UUID REFERENCES public.perfis(id) ON DELETE SET NULL, -- Usuﾃ｡rio que realizou a aﾃｧﾃ｣o
    criado_em TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- ﾃ肱dices para novas tabelas
CREATE INDEX IF NOT EXISTS idx_pacote_servicos_pacote_id ON public.pacote_servicos(pacote_id);
CREATE INDEX IF NOT EXISTS idx_pacote_servicos_servico_id ON public.pacote_servicos(servico_id);
CREATE INDEX IF NOT EXISTS idx_pacotes_contratados_cliente_id ON public.pacotes_contratados(cliente_id);
CREATE INDEX IF NOT EXISTS idx_vendas_produtos_produto_id ON public.vendas_produtos(produto_id);
CREATE INDEX IF NOT EXISTS idx_vendas_produtos_cliente_id ON public.vendas_produtos(cliente_id);
CREATE INDEX IF NOT EXISTS idx_dashboard_atividades_criado_em ON public.dashboard_atividades(criado_em);

-- --------------------------------------------------------
-- 3. SEGURANﾃ② (RLS)
-- --------------------------------------------------------

/*
CREATE OR REPLACE FUNCTION public.registrar_usuario_admin(
... (função desativada por restrições de permissão no auth.users)
*/

-- Habilitar RLS
ALTER TABLE public.perfis ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.servicos ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.categorias ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.agendamentos ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.avaliacoes ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.bloqueios_agenda ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.notificacoes ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.configuracoes_clinica ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.logs_admin ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.contas ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.disponibilidade_profissional ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.profissional_servicos ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.profissional_pacotes ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.horarios_almoco_profissional ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.promocoes ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.pacotes_templates ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.pacote_servicos ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.pacotes_contratados ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.produtos ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.vendas_produtos ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.dashboard_atividades ENABLE ROW LEVEL SECURITY;


-- ############################################################################
-- FUNﾃ�髭S AUXILIARES E LIMPEZA
-- ############################################################################

-- Limpeza de funﾃｧﾃｵes antigas para evitar erros de ambiguidade
DROP FUNCTION IF EXISTS public.registrar_atividade_dashboard(text, text, text, jsonb, uuid);
DROP FUNCTION IF EXISTS public.registrar_atividade_dashboard(text, text, text, jsonb);
DROP FUNCTION IF EXISTS public.registrar_atividade_dashboard(text, text, text);
DROP FUNCTION IF EXISTS public.is_admin();
DROP FUNCTION IF EXISTS public.is_profissional();

-- Funﾃｧﾃ｣o auxiliar para verificar se o usuﾃ｡rio ﾃｩ admin sem causar recursﾃ｣o
-- Usa SECURITY DEFINER e SET search_path para garantir isolamento e permissﾃ｣o
CREATE OR REPLACE FUNCTION public.is_admin()
RETURNS boolean AS $$
BEGIN
  RETURN EXISTS (
    SELECT 1 FROM public.perfis
    WHERE id = auth.uid() AND tipo = 'admin'
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

-- Funﾃｧﾃ｣o auxiliar para verificar se o usuﾃ｡rio ﾃｩ profissional
CREATE OR REPLACE FUNCTION public.is_profissional()
RETURNS boolean AS $$
BEGIN
  RETURN EXISTS (
    SELECT 1 FROM public.perfis
    WHERE id = auth.uid() AND tipo = 'profissional'
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;


DROP POLICY IF EXISTS "Usuﾃ｡rios podem visualizar perfis" ON public.perfis;
CREATE POLICY "Usuﾃ｡rios podem visualizar perfis" ON public.perfis 
    FOR SELECT 
    TO authenticated 
    USING (tipo IN ('profissional', 'admin', 'administrador') OR auth.uid() = id);

DROP POLICY IF EXISTS "Usuﾃ｡rios editam prﾃｳprio perfil" ON public.perfis;
CREATE POLICY "Usuﾃ｡rios editam prﾃｳprio perfil" ON public.perfis 
    FOR UPDATE 
    USING (auth.uid() = id);

DROP POLICY IF EXISTS "Admins podem atualizar perfis" ON public.perfis;
CREATE POLICY "Admins podem atualizar perfis" ON public.perfis
    FOR ALL
    TO authenticated
    USING (is_admin())
    WITH CHECK (is_admin());

DROP POLICY IF EXISTS "Inserﾃｧﾃ｣o de perfis" ON public.perfis;
CREATE POLICY "Inserﾃｧﾃ｣o de perfis" ON public.perfis 
    FOR INSERT 
    WITH CHECK (auth.uid() = id OR is_admin());

-- Polﾃｭticas de SERVIﾃ⑯S/CATEGORIAS
DROP POLICY IF EXISTS "Serviﾃｧos visﾃｭveis para todos" ON public.servicos;
CREATE POLICY "Serviﾃｧos visﾃｭveis para todos" ON public.servicos FOR SELECT USING (true);

DROP POLICY IF EXISTS "Categorias visﾃｭveis para todos" ON public.categorias;
CREATE POLICY "Categorias visﾃｭveis para todos" ON public.categorias FOR SELECT USING (true);

DROP POLICY IF EXISTS "Admins cadastram serviﾃｧos" ON public.servicos;
CREATE POLICY "Admins cadastram serviﾃｧos" ON public.servicos FOR ALL TO authenticated 
USING (is_admin());

DROP POLICY IF EXISTS "Admins cadastram categorias" ON public.categorias;
CREATE POLICY "Admins cadastram categorias" ON public.categorias FOR ALL TO authenticated 
USING (is_admin());

-- Polﾃｭticas de DISPONIBILIDADE E Vﾃ康CULOS DE SERVIﾃ⑯
DROP POLICY IF EXISTS "Disponibilidade visﾃｭvel para todos" ON public.disponibilidade_profissional;
CREATE POLICY "Disponibilidade visﾃｭvel para todos" ON public.disponibilidade_profissional FOR SELECT USING (true);

DROP POLICY IF EXISTS "Profissional serviﾃｧos visﾃｭveis para todos" ON public.profissional_servicos;
CREATE POLICY "Profissional serviﾃｧos visﾃｭveis para todos" ON public.profissional_servicos FOR SELECT USING (true);

DROP POLICY IF EXISTS "Admins configuram disponibilidade" ON public.disponibilidade_profissional;
CREATE POLICY "Admins configuram disponibilidade" ON public.disponibilidade_profissional FOR ALL TO authenticated USING (is_admin());

DROP POLICY IF EXISTS "Admins configuram prof servicos" ON public.profissional_servicos;
CREATE POLICY "Admins configuram prof servicos" ON public.profissional_servicos FOR ALL TO authenticated USING (is_admin());

-- Polﾃｭticas de Vﾃ康CULOS DE PACOTE
DROP POLICY IF EXISTS "Profissional pacotes visﾃｭveis para todos" ON public.profissional_pacotes;
CREATE POLICY "Profissional pacotes visﾃｭveis para todos" ON public.profissional_pacotes FOR SELECT USING (true);

DROP POLICY IF EXISTS "Admins configuram prof pacotes" ON public.profissional_pacotes;
CREATE POLICY "Admins configuram prof pacotes" ON public.profissional_pacotes FOR ALL TO authenticated USING (is_admin());

-- Polﾃｭticas de HORﾃヽIOS DE ALMOﾃ⑯
DROP POLICY IF EXISTS "Almoﾃｧo visﾃｭvel para todos" ON public.horarios_almoco_profissional;
CREATE POLICY "Almoﾃｧo visﾃｭvel para todos" ON public.horarios_almoco_profissional FOR SELECT USING (true);

DROP POLICY IF EXISTS "Admins/Profissionais gerenciam almoﾃｧo" ON public.horarios_almoco_profissional;
CREATE POLICY "Admins/Profissionais gerenciam almoﾃｧo" ON public.horarios_almoco_profissional FOR ALL TO authenticated 
USING (auth.uid() = profissional_id OR is_admin());

-- Polﾃｭticas de PROMOﾃ�髭S
DROP POLICY IF EXISTS "Promoﾃｧﾃｵes visﾃｭveis por todos" ON public.promocoes;
CREATE POLICY "Promoﾃｧﾃｵes visﾃｭveis por todos" ON public.promocoes FOR SELECT USING (ativo = true);

DROP POLICY IF EXISTS "Admins podem tudo em promoﾃｧﾃｵes" ON public.promocoes;
CREATE POLICY "Admins podem tudo em promoﾃｧﾃｵes" ON public.promocoes FOR ALL USING (is_admin());

-- Polﾃｭticas de AGENDAMENTOS
DROP POLICY IF EXISTS "Agendamentos visﾃｭveis para dono" ON public.agendamentos;
CREATE POLICY "Agendamentos visﾃｭveis para dono" ON public.agendamentos FOR SELECT USING (auth.uid() = cliente_id OR auth.uid() = profissional_id OR is_admin());

DROP POLICY IF EXISTS "Clientes inserem agendamentos" ON public.agendamentos;
CREATE POLICY "Clientes inserem agendamentos" ON public.agendamentos FOR INSERT WITH CHECK (auth.uid() = cliente_id);

DROP POLICY IF EXISTS "Dono atualiza agendamento" ON public.agendamentos;

-- Polﾃｭticas de PACOTES
DROP POLICY IF EXISTS "Pacotes visﾃｭveis por todos" ON public.pacotes_templates;
CREATE POLICY "Pacotes visﾃｭveis por todos" ON public.pacotes_templates FOR SELECT USING (true);

DROP POLICY IF EXISTS "Admins gerenciam templates de pacotes" ON public.pacotes_templates;
CREATE POLICY "Admins gerenciam templates de pacotes" ON public.pacotes_templates FOR ALL TO authenticated USING (is_admin());

DROP POLICY IF EXISTS "Pacote serviﾃｧos visﾃｭveis por todos" ON public.pacote_servicos;
CREATE POLICY "Pacote serviﾃｧos visﾃｭveis por todos" ON public.pacote_servicos FOR SELECT USING (true);

DROP POLICY IF EXISTS "Admins gerenciam pacote servicos" ON public.pacote_servicos;
CREATE POLICY "Admins gerenciam pacote servicos" ON public.pacote_servicos FOR ALL TO authenticated USING (is_admin());

DROP POLICY IF EXISTS "Pacotes contratados visﾃｭveis para dono/admin" ON public.pacotes_contratados;
CREATE POLICY "Pacotes contratados visﾃｭveis para dono/admin" ON public.pacotes_contratados FOR SELECT USING (auth.uid() = cliente_id OR is_admin());

DROP POLICY IF EXISTS "Clientes podem contratar pacotes" ON public.pacotes_contratados;
CREATE POLICY "Clientes podem contratar pacotes" ON public.pacotes_contratados FOR INSERT WITH CHECK (auth.uid() = cliente_id);

DROP POLICY IF EXISTS "Dono/Admin podem atualizar pacotes contratados" ON public.pacotes_contratados;
CREATE POLICY "Dono/Admin podem atualizar pacotes contratados" ON public.pacotes_contratados FOR UPDATE USING (auth.uid() = cliente_id OR is_admin());

CREATE POLICY "Dono atualiza agendamento" ON public.agendamentos FOR UPDATE USING (auth.uid() = cliente_id OR auth.uid() = profissional_id OR is_admin());

-- Polﾃｭticas de NOTIFICAﾃ�髭S
DROP POLICY IF EXISTS "Ver prﾃｳprias notificaﾃｧﾃｵes" ON public.notificacoes;
CREATE POLICY "Ver prﾃｳprias notificaﾃｧﾃｵes" ON public.notificacoes FOR SELECT USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "Atualizar prﾃｳprias notificaﾃｧﾃｵes" ON public.notificacoes;
CREATE POLICY "Atualizar prﾃｳprias notificaﾃｧﾃｵes" ON public.notificacoes FOR UPDATE USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "Sistema insere notificaﾃｧﾃｵes" ON public.notificacoes;
CREATE POLICY "Sistema insere notificaﾃｧﾃｵes" ON public.notificacoes FOR INSERT WITH CHECK (true);

-- Polﾃｭticas de AVALIAﾃ�髭S
DROP POLICY IF EXISTS "Avaliaﾃｧﾃｵes visﾃｭveis para todos" ON public.avaliacoes;
CREATE POLICY "Avaliaﾃｧﾃｵes visﾃｭveis para todos" ON public.avaliacoes FOR SELECT USING (true);

DROP POLICY IF EXISTS "Clientes inserem prﾃｳprias avaliaﾃｧﾃｵes" ON public.avaliacoes;
CREATE POLICY "Clientes inserem prﾃｳprias avaliaﾃｧﾃｵes" ON public.avaliacoes FOR INSERT WITH CHECK (auth.uid() = cliente_id);

DROP POLICY IF EXISTS "Clientes atualizam prﾃｳprias avaliaﾃｧﾃｵes" ON public.avaliacoes;
CREATE POLICY "Clientes atualizam prﾃｳprias avaliaﾃｧﾃｵes" ON public.avaliacoes FOR UPDATE USING (auth.uid() = cliente_id);

-- Polﾃｭticas de BLOQUEIOS DE AGENDA
DROP POLICY IF EXISTS "Bloqueios visﾃｭveis para todos" ON public.bloqueios_agenda;
CREATE POLICY "Bloqueios visﾃｭveis para todos" ON public.bloqueios_agenda FOR SELECT USING (true);

DROP POLICY IF EXISTS "Admins gerenciam bloqueios" ON public.bloqueios_agenda;
CREATE POLICY "Admins gerenciam bloqueios" ON public.bloqueios_agenda FOR ALL TO authenticated USING (public.is_admin());

DROP POLICY IF EXISTS "Profissional gerencia prﾃｳprios bloqueios" ON public.bloqueios_agenda;
CREATE POLICY "Profissional gerencia prﾃｳprios bloqueios" ON public.bloqueios_agenda
    FOR ALL TO authenticated
    USING (auth.uid() = profissional_id)
    WITH CHECK (auth.uid() = profissional_id);

-- Polﾃｭticas de CONFIGURAﾃ�髭S DA CLﾃ康ICA
DROP POLICY IF EXISTS "Configuraﾃｧﾃｵes visﾃｭveis para todos" ON public.configuracoes_clinica;
CREATE POLICY "Configuraﾃｧﾃｵes visﾃｭveis para todos" ON public.configuracoes_clinica FOR SELECT USING (true);

DROP POLICY IF EXISTS "Admins gerenciam configuraﾃｧﾃｵes" ON public.configuracoes_clinica;
CREATE POLICY "Admins gerenciam configuraﾃｧﾃｵes" ON public.configuracoes_clinica FOR ALL TO authenticated USING (public.is_admin());

-- Polﾃｭticas de LOGS_ADMIN
DROP POLICY IF EXISTS "Logs visﾃｭveis apenas para admins" ON public.logs_admin;
CREATE POLICY "Logs visﾃｭveis apenas para admins" ON public.logs_admin FOR SELECT TO authenticated USING (public.is_admin());

DROP POLICY IF EXISTS "Admins inserem logs" ON public.logs_admin;
CREATE POLICY "Admins inserem logs" ON public.logs_admin FOR INSERT TO authenticated WITH CHECK (public.is_admin());

-- Polﾃｭticas de CAIXAS
DROP POLICY IF EXISTS "Admins podem gerenciar caixas" ON public.caixas;
CREATE POLICY "Admins podem gerenciar caixas" ON public.caixas 
    FOR ALL TO authenticated USING (public.is_admin());

DROP POLICY IF EXISTS "Vendedores podem ver caixas abertos" ON public.caixas;
CREATE POLICY "Vendedores podem ver caixas abertos" ON public.caixas 
    FOR SELECT TO authenticated USING (status = 'aberto');

-- Polﾃｭticas de CONTAS (Refinado)
DROP POLICY IF EXISTS "Admins gerenciam contas" ON public.contas; -- Cleanup duplicate

-- Polﾃｭticas de PRODUTOS
DROP POLICY IF EXISTS "Produtos visﾃｭveis para todos" ON public.produtos;
CREATE POLICY "Produtos visﾃｭveis para todos" ON public.produtos FOR SELECT USING (true);

DROP POLICY IF EXISTS "Admins gerenciam produtos" ON public.produtos;
CREATE POLICY "Admins gerenciam produtos" ON public.produtos FOR ALL TO authenticated USING (is_admin());

-- Polﾃｭticas de ESTOQUE

-- Polﾃｭticas de VENDAS_PRODUTOS
DROP POLICY IF EXISTS "Admins veem vendas" ON public.vendas_produtos;
CREATE POLICY "Admins veem vendas" ON public.vendas_produtos FOR SELECT TO authenticated USING (is_admin());

DROP POLICY IF EXISTS "Admins gerenciam vendas" ON public.vendas_produtos;
CREATE POLICY "Admins gerenciam vendas" ON public.vendas_produtos FOR ALL TO authenticated USING (is_admin());

-- Polﾃｭticas de DASHBOARD
DROP POLICY IF EXISTS "Admins veem atividades" ON public.dashboard_atividades;
CREATE POLICY "Admins veem atividades" ON public.dashboard_atividades FOR SELECT TO authenticated USING (is_admin());

DROP POLICY IF EXISTS "Admins gerenciam atividades" ON public.dashboard_atividades;
CREATE POLICY "Admins gerenciam atividades" ON public.dashboard_atividades FOR ALL TO authenticated USING (is_admin());

-- --------------------------------------------------------
-- 4. AUTOMAﾃ�グ (TRIGGERS)
-- --------------------------------------------------------

-- A. DISPONIBILIDADE PADRÃO (Seg-Sex 08-20h, Sábado 08-13h)
CREATE OR REPLACE FUNCTION public.fn_inserir_disponibilidade_padrao()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.tipo = 'profissional' THEN
        -- Segunda a Sexta (1-5)
        INSERT INTO public.disponibilidade_profissional (profissional_id, dia_semana, horario_inicio, horario_fim)
        SELECT NEW.id, d, '08:00', '20:00' FROM generate_series(1,5) d;
        -- Sábado (6)
        INSERT INTO public.disponibilidade_profissional (profissional_id, dia_semana, horario_inicio, horario_fim)
        VALUES (NEW.id, 6, '08:00', '13:00');
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trg_disponibilidade_padrao ON public.perfis;
CREATE TRIGGER trg_disponibilidade_padrao AFTER INSERT ON public.perfis FOR EACH ROW EXECUTE FUNCTION public.fn_inserir_disponibilidade_padrao();

-- B. NOTIFICAÇÕES DE AGENDAMENTO
CREATE OR REPLACE FUNCTION public.fn_gerar_notificacao_agendamento()
RETURNS TRIGGER AS $$
DECLARE
    v_serv_nome TEXT;
    v_data_f TEXT;
BEGIN
    SELECT nome INTO v_serv_nome FROM public.servicos WHERE id = NEW.servico_id;
    v_data_f := to_char(NEW.data_hora AT TIME ZONE 'America/Sao_Paulo', 'DD/MM "às" HH24:mi');

    IF (TG_OP = 'INSERT') THEN
        INSERT INTO public.notificacoes (user_id, titulo, mensagem, tipo)
        VALUES (NEW.cliente_id, 'Novo Agendamento', 'Seu agendamento de ' || COALESCE(v_serv_nome, 'Serviço') || ' para ' || v_data_f || ' foi realizado.', 'agendamento');
    ELSIF (TG_OP = 'UPDATE') THEN
        IF (OLD.data_hora IS DISTINCT FROM NEW.data_hora) THEN
            INSERT INTO public.notificacoes (user_id, titulo, mensagem, tipo)
            VALUES (NEW.cliente_id, 'Horário Alterado', 'Seu agendamento de ' || COALESCE(v_serv_nome, 'Serviço') || ' foi movido para ' || v_data_f || '.', 'reagendamento');
        END IF;

        IF (OLD.status IS DISTINCT FROM NEW.status) THEN
            IF (NEW.status = 'cancelado') THEN
                INSERT INTO public.notificacoes (user_id, titulo, mensagem, tipo)
                VALUES (NEW.cliente_id, 'Agendamento Cancelado', 'Seu agendamento de ' || COALESCE(v_serv_nome, 'Serviço') || ' foi cancelado.', 'cancelamento');
                
                INSERT INTO public.notificacoes (user_id, titulo, mensagem, tipo)
                SELECT id, 'Cancelamento', 'O agendamento de ' || COALESCE(v_serv_nome, 'Serviço') || ' foi cancelado.', 'admin_alerta'
                FROM public.perfis WHERE (tipo = 'admin' OR id = NEW.profissional_id);
            ELSIF (NEW.status = 'no_show') THEN
                INSERT INTO public.notificacoes (user_id, titulo, mensagem, tipo)
                VALUES (NEW.cliente_id, 'Não Comparecimento', 'Seu agendamento de ' || COALESCE(v_serv_nome, 'Serviço') || ' foi registrado como não comparecido.', 'no_show');
                
                INSERT INTO public.notificacoes (user_id, titulo, mensagem, tipo)
                SELECT id, 'Alerta: No-show', 'O cliente não compareceu ao agendamento de ' || COALESCE(v_serv_nome, 'Serviço') || '.', 'admin_alerta'
                FROM public.perfis WHERE (tipo = 'admin' OR id = NEW.profissional_id);
            END IF;
        END IF;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trg_notificacao_agendamento_insert ON public.agendamentos;
CREATE TRIGGER trg_notificacao_agendamento_insert AFTER INSERT ON public.agendamentos FOR EACH ROW EXECUTE FUNCTION public.fn_gerar_notificacao_agendamento();
DROP TRIGGER IF EXISTS trg_notificacao_agendamento_update ON public.agendamentos;
CREATE TRIGGER trg_notificacao_agendamento_update AFTER UPDATE ON public.agendamentos FOR EACH ROW EXECUTE FUNCTION public.fn_gerar_notificacao_agendamento();

CREATE OR REPLACE FUNCTION public.fn_notificar_mudanca_agenda_prof()
RETURNS TRIGGER AS $$
DECLARE
    v_prof_nome TEXT;
    v_autor_nome TEXT;
    v_titulo TEXT;
    v_mensagem TEXT;
    v_atv_tipo TEXT := 'configuracao';
BEGIN
    SELECT nome_completo INTO v_autor_nome FROM public.perfis WHERE id = auth.uid();
    IF v_autor_nome IS NULL THEN v_autor_nome := 'Sistema'; END IF;

    IF TG_TABLE_NAME = 'bloqueios_agenda' THEN
        IF NEW.profissional_id IS NOT NULL THEN
            SELECT nome_completo INTO v_prof_nome FROM public.perfis WHERE id = NEW.profissional_id;
            v_titulo := 'Bloqueio de Agenda';
            v_mensagem := v_autor_nome || ' bloqueou a agenda do profissional ' || COALESCE(v_prof_nome, 'identificado') || ' para o dia ' || to_char(NEW.data, 'DD/MM/YYYY') || '.';
        ELSE
            v_titulo := 'Bloqueio Global';
            v_mensagem := v_autor_nome || ' adicionou um novo bloqueio global para o dia ' || to_char(NEW.data, 'DD/MM/YYYY') || '.';
        END IF;
    ELSIF TG_TABLE_NAME = 'horarios_trabalho_profissional' THEN
        SELECT nome_completo INTO v_prof_nome FROM public.perfis WHERE id = NEW.profissional_id;
        v_titulo := 'Alteraﾃｧﾃ｣o de Horﾃ｡rio Semanal';
        v_mensagem := v_autor_nome || ' alterou o horﾃ｡rio de trabalho de ' || COALESCE(v_prof_nome, 'um profissional') || ' (Dia ' || NEW.dia_semana || ').';
        IF NEW.fechado THEN v_mensagem := v_mensagem || ' (Marcado como FECHADO)'; END IF;
    ELSIF TG_TABLE_NAME = 'horarios_almoco_profissional' THEN
        SELECT nome_completo INTO v_prof_nome FROM public.perfis WHERE id = NEW.profissional_id;
        v_titulo := 'Alteraﾃｧﾃ｣o de Horﾃ｡rio de Almoﾃｧo';
        v_mensagem := v_autor_nome || ' alterou o horﾃ｡rio de almoﾃｧo de ' || COALESCE(v_prof_nome, 'um profissional') || ' (Dia ' || NEW.dia_semana || ').';
    END IF;

    -- Registrar Atividade
    PERFORM public.registrar_atividade_dashboard(v_atv_tipo, v_titulo, v_mensagem, jsonb_build_object('tabela', TG_TABLE_NAME, 'item_id', NEW.id), auth.uid());

    -- Notificar Admins
    INSERT INTO public.notificacoes (user_id, titulo, mensagem, tipo)
    SELECT id, v_titulo, v_mensagem, 'admin_alerta'
    FROM public.perfis WHERE tipo = 'admin';

    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;


-- Garantir que os triggers nﾃ｣o existam antes de criar
DROP TRIGGER IF EXISTS trg_notificar_mudanca_agenda_work ON public.horarios_trabalho_profissional;
CREATE TRIGGER trg_notificar_mudanca_agenda_work AFTER INSERT OR UPDATE ON public.horarios_trabalho_profissional FOR EACH ROW EXECUTE FUNCTION public.fn_notificar_mudanca_agenda_prof();

DROP TRIGGER IF EXISTS trg_notificar_mudanca_agenda_lunch ON public.horarios_almoco_profissional;
CREATE TRIGGER trg_notificar_mudanca_agenda_lunch AFTER INSERT OR UPDATE ON public.horarios_almoco_profissional FOR EACH ROW EXECUTE FUNCTION public.fn_notificar_mudanca_agenda_prof();

DROP TRIGGER IF EXISTS trg_notificar_mudanca_agenda_block ON public.bloqueios_agenda;
CREATE TRIGGER trg_notificar_mudanca_agenda_block AFTER INSERT OR UPDATE ON public.bloqueios_agenda FOR EACH ROW EXECUTE FUNCTION public.fn_notificar_mudanca_agenda_prof();

-- --------------------------------------------------------
-- 5. DADOS INICIAIS (SEED)
-- --------------------------------------------------------

-- Categorias
INSERT INTO categorias (id, nome, icone_url, ordem) VALUES
('550e8400-e29b-41d4-a716-446655440001', 'Facial', 'face', 1),
('550e8400-e29b-41d4-a716-446655440002', 'Corporal', 'accessibility', 2),
('550e8400-e29b-41d4-a716-446655440003', 'Relax', 'spa', 3),
('550e8400-e29b-41d4-a716-446655440004', 'Laser', 'content_cut', 4)
ON CONFLICT (id) DO NOTHING;

-- Profissionais
-- INSERT INTO perfis (id, nome_completo, email, telefone, tipo, avatar_url, cargo) VALUES
-- ('a1a1a1a1-a1a1-a1a1-a1a1-a1a1a1a1a1a1', 'Dra. Gabriela Oliveira', 'gabriela@clinica.com', '11999999991', 'profissional', 'https://images.unsplash.com/photo-1594824476967-48c8b964273f?auto=format&fit=crop&q=80&w=400', 'Esteticista Facial'),
-- ('b2b2b2b2-b2b2-b2b2-b2b2-b2b2b2b2b2b2', 'Dra. Beatriz Costa', 'beatriz@clinica.com', '11999999992', 'profissional', 'https://images.unsplash.com/photo-1559839734-2b71ef15996d?auto=format&fit=crop&q=80&w=400', 'Fisioterapeuta Dermato-Funcional'),
-- ('c3c3c3c3-c3c3-c3c3-c3c3-c3c3c3c3c3c3', 'Dra. Julianna Silva', 'julianna@clinica.com', '11999999993', 'profissional', 'https://images.unsplash.com/photo-1622253692010-333f2da6031d?auto=format&fit=crop&q=80&w=400', 'Massoterapeuta')
-- ON CONFLICT (id) DO NOTHING;

-- Serviﾃｧos
INSERT INTO servicos (id, nome, descricao, preco, duracao_minutos, categoria_id, ativo, imagem_url) VALUES
('660e8400-e29b-41d4-a716-446655440002', 'Drenagem Linfﾃ｡tica', 'Elimina inchaﾃｧo e toxinas.', 120.00, 60, '550e8400-e29b-41d4-a716-446655440002', true, 'https://images.unsplash.com/photo-1544161515-4ab6ce6db874?auto=format&fit=crop&q=80&w=800'),
('660e8400-e29b-41d4-a716-446655440004', 'Depilaﾃｧﾃ｣o a Laser', 'Reduﾃｧﾃ｣o permanente de pelos.', 80.00, 20, '550e8400-e29b-41d4-a716-446655440004', true, 'https://images.unsplash.com/photo-1552693673-1bf958298935?auto=format&fit=crop&q=80&w=800')
ON CONFLICT (id) DO NOTHING;

-- Configuraﾃｧﾃ｣o Fixa da Clﾃｭnica
INSERT INTO public.configuracoes_clinica (nome_comercial, endereco, telefone_fixo, whatsapp, logo_url, mapa_iframe, descricao, taxa_debito, taxa_credito, taxa_credito_parcelado, taxa_pix) VALUES (
  'Clﾃｭnica Estﾃｩtica Lumiere Premium', 'Av. Paulista, 1000 - CJ 12 - SP', '+55 11 3322-4455', '+55 11 99999-8888', 
  'https://lh3.googleusercontent.com/aida-public/AB6AXuAG6eToNB53GWJOF5DexUJMipxbI4hfAlT5u6s3x4STGZ5qk4T9-1itCJK2VmxQJSBl_Mt87gwqua4rsaIr3j8FhwznYpH3vh-WJ6nPHo9N1zXHQc6U8VyzZtc0b-O7hbsNnkyRnHU2mJB1xOI1E8Zj_ScCgOAPbQ7QXyAGom8g_IX1TR2JRWM6n7_ip7_E5ReUNq40p-robjC7WMTzB1MFdjUqhzflr4sZ9bRRmUu7txtLcS74UOgfnQ2UBuyYeaW5rRpx1hvVgOTv',
  '<iframe src="https://www.google.com/maps/embed?pb=!1m14!1m8!1m3!1d1833.6469150917408!2d-45.8912008!3d-23.1959601!3m2!1i1024!2i768!4f13.1!3m3!1m2!1s0x94cc4bc573d3cedb%3A0x1a06d2ea7c223489!2sEmporium%20da%20Arte!5e0!3m2!1spt-BR!2sbr!4v1775104677491!5m2!1spt-BR!2sbr" width="600" height="450" style="border:0;" allowfullscreen="" loading="lazy" referrerpolicy="no-referrer-when-downgrade"></iframe>',
  'A Clﾃｭnica Lumiere Premium ﾃｩ referﾃｪncia em tratamentos estﾃｩticos de alta performance na regiﾃ｣o da Paulista. Com uma equipe multidisciplinar e tecnologia de ponta, oferecemos protocolos personalizados para realﾃｧar sua beleza natural e promover bem-estar completo, desde limpezas de pele profundas atﾃｩ procedimentos avanﾃｧados de rejuvenescimento e harmonizaﾃｧﾃ｣o.',
  2.50, 3.80, 5.20, 0.00
) ON CONFLICT DO NOTHING;

-- Seed Promoﾃｧﾃｵes
INSERT INTO public.promocoes (id, titulo, subtitulo, imagem_url, ordem) VALUES 
('f00e8400-e29b-41d4-a716-446655440001', 'Limpeza de Pele Profunda', '30% de desconto hoje', 'https://images.unsplash.com/photo-1570172619644-dfd03ed5d881?w=800', 0),
('f00e8400-e29b-41d4-a716-446655440002', 'Massagem Relaxante', 'Ganhe uma esfoliaﾃｧﾃ｣o', 'https://images.unsplash.com/photo-1570172619644-dfd03ed5d881?w=800', 1),
('f00e8400-e29b-41d4-a716-446655440003', 'Botox Facial', 'Consulte condiﾃｧﾃｵes especiais', 'https://images.unsplash.com/photo-1616394584738-fc6e612e71b9?w=800', 2)
ON CONFLICT (id) DO NOTHING;
-- --------------------------------------------------------
-- 6. FIX PARA PROFISSIONAIS Jﾃ� EXISTENTES
-- --------------------------------------------------------

-- Remover disponibilidades antigas para evitar duplicidade
DELETE FROM public.disponibilidade_profissional;

-- Inserir nova disponibilidade padrﾃ｣o para TODOS os profissionais cadastrados
INSERT INTO public.disponibilidade_profissional (profissional_id, dia_semana, hora_inicio, hora_fim)
SELECT p.id, d, '08:00:00', '20:00:00'
FROM perfis p, generate_series(1, 5) d
WHERE p.tipo = 'profissional';


-- --------------------------------------------------------
-- 7. PROMOﾃ�グ DE ADMINISTRADOR
-- --------------------------------------------------------

-- Comando para garantir que o email 'admin@admin.com' tenha nﾃｭvel de acesso admin
-- Se o usuﾃ｡rio jﾃ｡ cadastrou no app, este comando darﾃ｡ as permissﾃｵes necessﾃ｡rias
UPDATE public.perfis 
SET tipo = 'admin' 
WHERE email = 'admin@admin.com';

-- Caso queira criar um perfil fictﾃｭcio direto para testes (sem auth real)
-- INSERT INTO public.perfis (id, nome_completo, email, tipo)
-- VALUES (gen_random_uuid(), 'Administrador do Sistema', 'admin@admin.com', 'admin')
-- ON CONFLICT (email) DO UPDATE SET tipo = 'admin';

-- ========================================================
-- FUNﾃ�グ ADMINISTRATIVA PARA CRIAﾃ�グ DE PROFISSIONAIS
-- Permite criar usuﾃ｡rios no Auth e Perfis sem deslogar o admin
-- ========================================================

-- 1. Habilitar a extensﾃ｣o pgcrypto (para a funﾃｧﾃ｣o crypt)
CREATE EXTENSION IF NOT EXISTS pgcrypto;

-- 2. Criar a funﾃｧﾃ｣o principal
/*
CREATE OR REPLACE FUNCTION public.registrar_profissional_v2(
... (função omitida por segurança)
*/

-- Comentﾃ｡rio: Esta funﾃｧﾃ｣o deve ser executada como 'postgres' no SQL Editor

-- Garante que o perfil exista e seja ADMIN
DO $$
BEGIN
    INSERT INTO public.perfis (id, nome_completo, email, tipo)
    SELECT id, 'Administrador', email, 'admin'
    FROM auth.users
    WHERE email = 'admin@admin.com'
    ON CONFLICT (email) DO UPDATE SET tipo = 'admin';
EXCEPTION WHEN OTHERS THEN
    RAISE NOTICE 'Aviso: Não foi possível sincronizar perfil admin a partir de auth.users. Isso é esperado se você ainda não criou o usuário no dashboard auth.';
END $$;

-- Garante que todos os profissionais (inclusive os recém-criados) tenham a agenda preenchida
DO $$
DECLARE
    prof RECORD;
BEGIN
    FOR prof IN SELECT id FROM public.perfis WHERE tipo = 'profissional' LOOP
        -- Segunda a Sexta (1-5)
        INSERT INTO public.disponibilidade_profissional (profissional_id, dia_semana, hora_inicio, hora_fim)
        SELECT prof.id, d, '08:00:00', '20:00:00'
        FROM generate_series(1, 5) d
        ON CONFLICT (profissional_id, dia_semana, hora_inicio) DO NOTHING;
        
        -- Sﾃ｡bado (6)
        INSERT INTO public.disponibilidade_profissional (profissional_id, dia_semana, hora_inicio, hora_fim)
        VALUES (prof.id, 6, '08:00:00', '13:00:00')
        ON CONFLICT (profissional_id, dia_semana, hora_inicio) DO NOTHING;
    END LOOP;
END $$;

-- Criaﾃｧﾃ｣o Automﾃ｡tica de Agenda (Para novos profissionais ou atualizados)
CREATE OR REPLACE FUNCTION public.trg_criar_disponibilidade_padrao()
RETURNS TRIGGER AS $$
BEGIN
    -- Se estiver criando ou atualizando para "profissional", injeta a grade de horﾃ｡rios
    IF (NEW.tipo = 'profissional') THEN
        -- Segunda a Sexta (1-5)
        INSERT INTO public.disponibilidade_profissional (profissional_id, dia_semana, hora_inicio, hora_fim)
        SELECT NEW.id, d, '08:00:00', '20:00:00'
        FROM generate_series(1, 5) d
        ON CONFLICT (profissional_id, dia_semana, hora_inicio) DO NOTHING;
        
        -- Sﾃ｡bado (6)
        INSERT INTO public.disponibilidade_profissional (profissional_id, dia_semana, hora_inicio, hora_fim)
        VALUES (NEW.id, 6, '08:00:00', '13:00:00')
        ON CONFLICT (profissional_id, dia_semana, hora_inicio) DO NOTHING;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trg_disponibilidade_padrao ON public.perfis;
CREATE TRIGGER trg_disponibilidade_padrao
AFTER INSERT OR UPDATE ON public.perfis
FOR EACH ROW EXECUTE FUNCTION public.trg_criar_disponibilidade_padrao();

-- --------------------------------------------------------
-- FUNﾃ�髭S DE INATIVAﾃ�グ E LOGIN
-- --------------------------------------------------------

-- Funﾃｧﾃ｣o para atualizar o ﾃｺltimo login (deve ser chamada pelo App no login)
CREATE OR REPLACE FUNCTION public.atualizar_ultimo_login(p_user_id UUID)
RETURNS void AS $$
BEGIN
    UPDATE public.perfis 
    SET ultimo_login = timezone('utc'::text, now()),
        ativo = true 
    WHERE id = p_user_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Funﾃｧﾃ｣o para inativar usuﾃ｡rios (clientes) sem login por 30 dias
CREATE OR REPLACE FUNCTION public.limpar_usuarios_inativos_30_dias()
RETURNS void AS $$
BEGIN
    UPDATE public.perfis
    SET ativo = false
    WHERE tipo = 'cliente'
      AND ativo = true
      AND ultimo_login < (now() - INTERVAL '30 days');
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ========================================================
-- SISTEMA DE LOGS E ATIVIDADES DO DASHBOARD
-- ========================================================

-- (A tabela dashboard_atividades foi consolidada acima)

-- Ativar RLS
ALTER TABLE public.dashboard_atividades ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Permitir leitura para admins" ON public.dashboard_atividades FOR SELECT TO authenticated USING (
    is_admin()
);
CREATE POLICY "Permitir insert para admins" ON public.dashboard_atividades FOR INSERT TO authenticated WITH CHECK (
    is_admin()
);
CREATE POLICY "Permitir update para admins" ON public.dashboard_atividades FOR UPDATE TO authenticated USING (
    is_admin()
) WITH CHECK (
    is_admin()
);

-- Funﾃｧﾃ｣o auxiliar para registrar atividades no Dashboard (Padrﾃ｣o)
CREATE OR REPLACE FUNCTION public.registrar_atividade_dashboard(
    p_tipo TEXT,
    p_titulo TEXT,
    p_descricao TEXT,
    p_metadata JSONB DEFAULT NULL,
    p_user_id UUID DEFAULT NULL
) RETURNS void AS $$
BEGIN
    INSERT INTO public.dashboard_atividades (
        tipo, 
        titulo, 
        descricao, 
        metadata, 
        user_id
    ) VALUES (
        p_tipo, 
        p_titulo, 
        p_descricao, 
        p_metadata, 
        COALESCE(p_user_id, auth.uid())
    );
EXCEPTION WHEN OTHERS THEN
    RAISE WARNING 'Erro ao registrar atividade: %', SQLERRM;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;


-- Funﾃｧﾃ｣o auxiliar para notificar todos os administradores
CREATE OR REPLACE FUNCTION public.notificar_admins(
    p_titulo TEXT,
    p_mensagem TEXT,
    p_tipo TEXT DEFAULT 'sistema',
    p_metadata JSONB DEFAULT '{}'::jsonb
) RETURNS void AS $$
DECLARE
    v_admin_id UUID;
BEGIN
    FOR v_admin_id IN SELECT id FROM public.perfis WHERE tipo = 'admin' LOOP
        INSERT INTO public.notificacoes (user_id, titulo, mensagem, tipo, metadata)
        VALUES (v_admin_id, p_titulo, p_mensagem, p_tipo, p_metadata);
    END LOOP;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ========================================================
-- SISTEMA DE PREVENﾃ�グ DE CONFLITOS DE AGENDAMENTO
-- Verifica a duraﾃｧﾃ｣o do serviﾃｧo para evitar horﾃ｡rios sobrepostos
-- ========================================================

-- Remover o ﾃｭndice antigo se ele ainda existir, pois a trigger farﾃ｡ um trabalho mais completo
DROP INDEX IF EXISTS public.idx_agendamentos_profissional_horario;

CREATE OR REPLACE FUNCTION public.verificar_disponibilidade_agendamento()
RETURNS TRIGGER AS $$
DECLARE
    v_nova_duracao INT;
    v_novo_fim TIMESTAMP WITH TIME ZONE;
    v_conflito INT;
BEGIN
    -- Se o agendamento foi cancelado ou ausente, nﾃ｣o bloqueia o horﾃ｡rio
    IF (NEW.status IN ('cancelado', 'ausente')) THEN
        RETURN NEW;
    END IF;

    -- Obtﾃｩm a duraﾃｧﾃ｣o do serviﾃｧo que estﾃ｡ sendo agendado
    SELECT duracao_minutos INTO v_nova_duracao 
    FROM public.servicos 
    WHERE id = NEW.servico_id;
    
    -- Se nﾃ｣o encontrar duraﾃｧﾃ｣o, presume 60 minutos como padrﾃ｣o de seguranﾃｧa
    IF v_nova_duracao IS NULL THEN
        v_nova_duracao := 60;
    END IF;

    -- Calcula a hora final do novo agendamento
    v_novo_fim := NEW.data_hora + (v_nova_duracao || ' minutes')::interval;

    -- Verifica se existe algum agendamento conflitante para o mesmo profissional
    -- Lﾃｳgica de Intersecﾃｧﾃ｣o de Perﾃｭodos: (InicioA < FimB) AND (FimA > InicioB)
    SELECT COUNT(*) INTO v_conflito
    FROM public.agendamentos a
    JOIN public.servicos s ON a.servico_id = s.id
    WHERE a.profissional_id = NEW.profissional_id
      AND a.id != COALESCE(NEW.id, '00000000-0000-0000-0000-000000000000'::uuid)
      AND a.status NOT IN ('cancelado', 'ausente')
      AND a.data_hora < v_novo_fim
      AND (a.data_hora + (COALESCE(s.duracao_minutos, 60) || ' minutes')::interval) > NEW.data_hora;

    IF v_conflito > 0 THEN
        RAISE EXCEPTION 'Horﾃ｡rio indisponﾃｭvel. O perﾃｭodo selecionado (considerando a duraﾃｧﾃ｣o do serviﾃｧo) entra em conflito com outro agendamento existente deste profissional.';
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trg_check_disponibilidade ON public.agendamentos;
CREATE TRIGGER trg_check_disponibilidade
BEFORE INSERT OR UPDATE ON public.agendamentos
FOR EACH ROW EXECUTE FUNCTION public.verificar_disponibilidade_agendamento();


-- ========================================================
-- RPC PARA BUSCAR OCUPAﾃ�グ DA CLﾃ康ICA (BYPASS RLS)
-- Esta funﾃｧﾃ｣o permite que o app verifique quais horﾃ｡rios estﾃ｣o ocupados
-- sem expor detalhes sensﾃｭveis dos agendamentos de outros usuﾃ｡rios.
-- ========================================================

CREATE OR REPLACE FUNCTION public.get_clinic_occupied_slots(p_start_time TIMESTAMP WITH TIME ZONE, p_end_time TIMESTAMP WITH TIME ZONE)
RETURNS TABLE (data_hora TIMESTAMP WITH TIME ZONE, duracao_minutos INT) 
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  RETURN QUERY
  SELECT a.data_hora, s.duracao_minutos
  FROM public.agendamentos a
  JOIN public.servicos s ON a.servico_id = s.id
  WHERE a.data_hora >= p_start_time 
    AND a.data_hora <= p_end_time
    AND a.status NOT IN ('cancelado', 'ausente');
END;
$$ LANGUAGE plpgsql;

-- Garante que usuﾃ｡rios autenticados possam executar a funﾃｧﾃ｣o
GRANT EXECUTE ON FUNCTION public.get_clinic_occupied_slots(TIMESTAMP WITH TIME ZONE, TIMESTAMP WITH TIME ZONE) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_clinic_occupied_slots(TIMESTAMP WITH TIME ZONE, TIMESTAMP WITH TIME ZONE) TO anon;


-- ========================================================
-- ATUALIZAﾃ�グ DO SISTEMA DE NOTIFICAﾃ�髭S (DASHBOARD)
-- Execute este script no SQL Editor do Supabase
-- ========================================================

-- 1. Adiciona a coluna is_lida caso ela nﾃ｣o exista
ALTER TABLE public.dashboard_atividades 
ADD COLUMN IF NOT EXISTS is_lida BOOLEAN DEFAULT FALSE;

-- 2. Correﾃｧﾃ｣o de Seguranﾃｧa (RLS): Permite que o app atualize a coluna is_lida
DROP POLICY IF EXISTS "Permitir update para admins" ON public.dashboard_atividades;
CREATE POLICY "Permitir update para admins" 
ON public.dashboard_atividades 
FOR UPDATE TO authenticated 
USING (is_admin())
WITH CHECK (is_admin());

-- 2.1 Adiﾃｧﾃ｣o de Coluna Retroativa (Caso o banco jﾃ｡ exista)
ALTER TABLE public.dashboard_atividades ADD COLUMN IF NOT EXISTS user_id UUID REFERENCES public.perfis(id) ON DELETE SET NULL;

-- 3. Correﾃｧﾃ｣o de Seguranﾃｧa (RLS): Permite inserﾃｧﾃ｣o de novos logs pelo Dart
DROP POLICY IF EXISTS "Permitir insert para admins" ON public.dashboard_atividades;
CREATE POLICY "Permitir insert para admins" 
ON public.dashboard_atividades 
FOR INSERT TO authenticated 
WITH CHECK (is_admin());

-- ========================================================
-- ATUALIZAﾃ�グ REVOLUCIONARIA DE NOTIFICAﾃ�髭S GERAIS (DASHBOARD)
-- Atualizado para exibir O NOME DE QUEM FEZ A Aﾃ�グ (Autor)
-- Execute este script no SQL Editor do Supabase
-- ========================================================

-- 1. TRG: Agendamentos
CREATE OR REPLACE FUNCTION public.trg_log_agendamento()
RETURNS TRIGGER AS $$
DECLARE
    v_cliente_nome TEXT;
    v_prof_nome TEXT;
    v_autor_nome TEXT;
    v_prefixo TEXT;
BEGIN
    SELECT nome_completo INTO v_cliente_nome FROM public.perfis WHERE id = NEW.cliente_id;
    SELECT nome_completo INTO v_prof_nome FROM public.perfis WHERE id = NEW.profissional_id;

    -- Obtﾃｩm o nome do usuﾃ｡rio que disparou a query (Admin, Cliente ou Prof)
    SELECT nome_completo INTO v_autor_nome FROM public.perfis WHERE id = auth.uid();
    
    -- Fallback de seguranﾃｧa se falhar na obtenﾃｧﾃ｣o
    IF v_autor_nome IS NULL THEN
        v_autor_nome := 'Sistema';
    END IF;

    IF (TG_OP = 'INSERT') THEN
        IF v_autor_nome = v_cliente_nome THEN
            v_prefixo := v_cliente_nome || ' agendou com ' || v_prof_nome;
        ELSE
            v_prefixo := v_autor_nome || ' agendou para o cliente ' || v_cliente_nome || ' com ' || v_prof_nome;
        END IF;

        PERFORM public.registrar_atividade_dashboard(
            'agendamento',
            'Novo Agendamento',
            v_prefixo || ' para o dia ' || to_char(NEW.data_hora AT TIME ZONE 'America/Sao_Paulo', 'DD/MM/YYYY') || ' ﾃ�s ' || to_char(NEW.data_hora AT TIME ZONE 'America/Sao_Paulo', 'HH24:MI'),
            jsonb_build_object('appointment_id', NEW.id, 'data', NEW.data_hora, 'Usuﾃ｡rio Criaﾃｧﾃ｣o', v_autor_nome)
        );
    ELSIF (TG_OP = 'UPDATE') THEN
        IF (NEW.status = 'cancelado' AND OLD.status != 'cancelado') THEN
             PERFORM public.registrar_atividade_dashboard(
                'agendamento',
                'Agendamento Cancelado',
                v_autor_nome || ' cancelou o agendamento de ' || v_cliente_nome || ' com ' || v_prof_nome || ' para o dia ' || to_char(NEW.data_hora AT TIME ZONE 'America/Sao_Paulo', 'DD/MM/YYYY') || ' ﾃ�s ' || to_char(NEW.data_hora AT TIME ZONE 'America/Sao_Paulo', 'HH24:MI'),
                jsonb_build_object('appointment_id', NEW.id, 'Usuﾃ｡rio Alteraﾃｧﾃ｣o', v_autor_nome)
            );
        END IF;
        
        IF (NEW.status = 'concluido' AND OLD.status != 'concluido') THEN
             PERFORM public.registrar_atividade_dashboard(
                'agendamento',
                'Atendimento Concluﾃｭdo',
                v_autor_nome || ' concluiu o atendimento de ' || v_cliente_nome || ' com ' || v_prof_nome || ' no dia ' || to_char(NEW.data_hora AT TIME ZONE 'America/Sao_Paulo', 'DD/MM/YYYY') || ' ﾃ�s ' || to_char(NEW.data_hora AT TIME ZONE 'America/Sao_Paulo', 'HH24:MI'),
                jsonb_build_object('appointment_id', NEW.id, 'Usuﾃ｡rio Alteraﾃｧﾃ｣o', v_autor_nome)
            );
        END IF;

        IF (NEW.status = 'confirmado' AND OLD.status != 'confirmado') THEN
            PERFORM public.registrar_atividade_dashboard(
                'agendamento',
                'Agendamento Confirmado',
                v_autor_nome || ' confirmou o agendamento de ' || v_cliente_nome || ' com ' || v_prof_nome || ' para o dia ' || to_char(NEW.data_hora AT TIME ZONE 'America/Sao_Paulo', 'DD/MM/YYYY') || ' ﾃ�s ' || to_char(NEW.data_hora AT TIME ZONE 'America/Sao_Paulo', 'HH24:MI'),
                jsonb_build_object('appointment_id', NEW.id, 'Usuﾃ｡rio Alteraﾃｧﾃ｣o', v_autor_nome)
            );
        END IF;

        IF (NEW.status = 'ausente' AND OLD.status != 'ausente') THEN
            PERFORM public.registrar_atividade_dashboard(
                'agendamento',
                'Falta no Agendamento',
                v_autor_nome || ' marcou falta para ' || v_cliente_nome || ' no atendimento com ' || v_prof_nome || ' no dia ' || to_char(NEW.data_hora AT TIME ZONE 'America/Sao_Paulo', 'DD/MM/YYYY') || ' ﾃ�s ' || to_char(NEW.data_hora AT TIME ZONE 'America/Sao_Paulo', 'HH24:MI'),
                jsonb_build_object('appointment_id', NEW.id, 'Usuﾃ｡rio Alteraﾃｧﾃ｣o', v_autor_nome)
            );
        END IF;

        -- Pagamento (novo tracker)
        IF (NEW.pago = true AND OLD.pago = false) THEN
            PERFORM public.registrar_atividade_dashboard(
                'financeiro',
                'Pagamento de Agendamento Confirmado',
                v_autor_nome || ' confirmou o recebimento referente ao agendamento de ' || v_cliente_nome || ' (R$ ' || COALESCE(NEW.valor_total, 0) || ')',
                jsonb_build_object('appointment_id', NEW.id, 'valor', NEW.valor_total, 'Usuﾃ｡rio Alteraﾃｧﾃ｣o', v_autor_nome)
            );
        END IF;

        -- Reagendamento (se a data mudou)
        IF (NEW.data_hora != OLD.data_hora) THEN
            PERFORM public.registrar_atividade_dashboard(
                'agendamento',
                'Agendamento Reagendado',
                v_autor_nome || ' reagendou o atendimento de ' || v_cliente_nome || ' com ' || v_prof_nome || ' para o dia ' || to_char(NEW.data_hora AT TIME ZONE 'America/Sao_Paulo', 'DD/MM/YYYY') || ' ﾃ�s ' || to_char(NEW.data_hora AT TIME ZONE 'America/Sao_Paulo', 'HH24:MI'),
                jsonb_build_object('appointment_id', NEW.id, 'old_time', OLD.data_hora, 'new_time', NEW.data_hora, 'Usuﾃ｡rio Alteraﾃｧﾃ｣o', v_autor_nome)
            );
        END IF;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;


DROP TRIGGER IF EXISTS trg_atividade_agendamento ON public.agendamentos;
CREATE TRIGGER trg_atividade_agendamento
AFTER INSERT OR UPDATE ON public.agendamentos
FOR EACH ROW EXECUTE FUNCTION public.trg_log_agendamento();


-- 2. TRG: Perfis (Profissionais e Clientes)
CREATE OR REPLACE FUNCTION public.trg_log_perfil()
RETURNS TRIGGER AS $$
DECLARE
    v_autor_nome TEXT;
BEGIN
    SELECT nome_completo INTO v_autor_nome FROM public.perfis WHERE id = auth.uid();
    IF v_autor_nome IS NULL THEN
        v_autor_nome := 'Sistema';
    END IF;

    IF (TG_OP = 'INSERT') THEN
        IF (NEW.tipo = 'cliente') THEN
            PERFORM public.registrar_atividade_dashboard(
                'cliente',
                'Novo Cliente',
                NEW.nome_completo || ' se registrou no sistema',
                jsonb_build_object('perfil_id', NEW.id, 'Usuﾃ｡rio Criaﾃｧﾃ｣o', v_autor_nome)
            );
        ELSIF (NEW.tipo = 'profissional') THEN
            PERFORM public.registrar_atividade_dashboard(
                'configuracao',
                'Novo Profissional',
                v_autor_nome || ' registrou o profissional ' || NEW.nome_completo || ' no sistema',
                jsonb_build_object('perfil_id', NEW.id, 'Usuﾃ｡rio Criaﾃｧﾃ｣o', v_autor_nome)
            );
            
            -- Sistema de Notificaﾃｧﾃ｣o
            PERFORM public.notificar_admins(
                'Novo profissional cadastrado',
                v_autor_nome || ' registrou ' || NEW.nome_completo || ' no sistema',
                'sistema',
                jsonb_build_object('perfil_id', NEW.id)
            );
        END IF;
    ELSIF (TG_OP = 'UPDATE') THEN
        IF (OLD.ativo = true AND NEW.ativo = false) THEN
            PERFORM public.registrar_atividade_dashboard(
                'configuracao',
                'Perfil Inativado',
                v_autor_nome || ' desativou o perfil de ' || NEW.nome_completo,
                jsonb_build_object('perfil_id', NEW.id, 'Usuﾃ｡rio Alteraﾃｧﾃ｣o', v_autor_nome)
            );
        END IF;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;


DROP TRIGGER IF EXISTS trg_atividade_perfil ON public.perfis;
CREATE TRIGGER trg_atividade_perfil
AFTER INSERT OR UPDATE ON public.perfis
FOR EACH ROW EXECUTE FUNCTION public.trg_log_perfil();


-- 3. TRG: Procedimentos (Serviﾃｧos) 
CREATE OR REPLACE FUNCTION public.trg_log_servico()
RETURNS TRIGGER AS $$
DECLARE
    v_autor_nome TEXT;
BEGIN
    SELECT nome_completo INTO v_autor_nome FROM public.perfis WHERE id = auth.uid();
    IF v_autor_nome IS NULL THEN
        v_autor_nome := 'Sistema';
    END IF;

    IF (TG_OP = 'INSERT') THEN
        PERFORM public.registrar_atividade_dashboard(
            'configuracao',
            'Novo Procedimento',
            v_autor_nome || ' cadastrou o procedimento "' || NEW.nome || '"',
            jsonb_build_object('servico_id', NEW.id, 'preco', NEW.preco, 'Usuﾃ｡rio Criaﾃｧﾃ｣o', v_autor_nome)
        );
    ELSIF (TG_OP = 'DELETE') THEN
        PERFORM public.registrar_atividade_dashboard(
            'configuracao',
            'Procedimento Removido',
            v_autor_nome || ' removeu o procedimento "' || OLD.nome || '"',
            jsonb_build_object('servico_id', OLD.id, 'Usuﾃ｡rio Deleﾃｧﾃ｣o', v_autor_nome)
        );

        -- Notificaﾃｧﾃ｣o direta Admin
        PERFORM public.notificar_admins(
            'Procedimento Removido',
            v_autor_nome || ' deletou o serviﾃｧo: ' || OLD.nome,
            'sistema'
        );
    END IF;

    -- Notificaﾃｧﾃｵes de criaﾃｧﾃ｣o e preﾃｧo para Admin
    IF (TG_OP = 'INSERT') THEN
         PERFORM public.notificar_admins(
            'Novo Procedimento Cadastrado',
            v_autor_nome || ' cadastrou o serviﾃｧo: ' || NEW.nome || ' (R$ ' || NEW.preco || ')',
            'sistema'
        );
    ELSIF (TG_OP = 'UPDATE' AND NEW.nome = OLD.nome AND NEW.preco != OLD.preco) THEN
         PERFORM public.notificar_admins(
            'Alteraﾃｧﾃ｣o de Preﾃｧo',
            v_autor_nome || ' alterou o valor de "' || NEW.nome || '" para R$ ' || NEW.preco,
            'sistema'
        );
    END IF;

    RETURN COALESCE(NEW, OLD);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;


DROP TRIGGER IF EXISTS trg_atividade_servico ON public.servicos;
CREATE TRIGGER trg_atividade_servico
AFTER INSERT OR UPDATE OR DELETE ON public.servicos
FOR EACH ROW EXECUTE FUNCTION public.trg_log_servico();


-- 4. TRG: Financeiro CAIXA
CREATE OR REPLACE FUNCTION public.trg_log_caixa()
RETURNS TRIGGER AS $$
DECLARE
    v_perf_nome TEXT;
    v_autor_nome TEXT;
BEGIN
    SELECT nome_completo INTO v_perf_nome FROM public.perfis WHERE id = NEW.usuario_id;
    SELECT nome_completo INTO v_autor_nome FROM public.perfis WHERE id = auth.uid();
    IF v_autor_nome IS NULL THEN
        v_autor_nome := v_perf_nome;
    END IF;
    
    IF (TG_OP = 'INSERT') THEN
        PERFORM public.registrar_atividade_dashboard(
            'financeiro',
            'Caixa Aberto',
            v_autor_nome || ' abriu o caixa (Saldo Inicial: R$ ' || NEW.saldo_inicial || ')',
            jsonb_build_object('caixa_id', NEW.id, 'usuario_id', NEW.usuario_id, 'Usuﾃ｡rio Criaﾃｧﾃ｣o', v_autor_nome)
        );
    ELSIF (TG_OP = 'UPDATE') THEN
        IF (NEW.status = 'fechado' AND OLD.status != 'fechado') THEN
            PERFORM public.registrar_atividade_dashboard(
                'financeiro',
                'Caixa Fechado',
                v_autor_nome || ' fechou o caixa (Saldo Final: R$ ' || COALESCE(NEW.saldo_final_real, 0) || ')',
                jsonb_build_object('caixa_id', NEW.id, 'usuario_id', NEW.usuario_id, 'Usuﾃ｡rio Alteraﾃｧﾃ｣o', v_autor_nome)
            );
        END IF;
    END IF;

    -- Notificaﾃｧﾃ｣o Admin on Open/Close
    IF (TG_OP = 'INSERT') THEN
        PERFORM public.notificar_admins(
            'Caixa Aberto',
            v_autor_nome || ' abriu o caixa com saldo inicial de R$ ' || NEW.saldo_inicial,
            'financeiro'
        );
    ELSIF (TG_OP = 'UPDATE' AND NEW.status = 'fechado' AND OLD.status != 'fechado') THEN
        PERFORM public.notificar_admins(
            'Caixa Fechado',
            v_autor_nome || ' fechou o caixa com saldo final de R$ ' || COALESCE(NEW.saldo_final_real, 0),
            'financeiro'
        );
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;


DROP TRIGGER IF EXISTS trg_atividade_caixa ON public.caixas;
CREATE TRIGGER trg_atividade_caixa
AFTER INSERT OR UPDATE ON public.caixas
FOR EACH ROW EXECUTE FUNCTION public.trg_log_caixa();


-- 5. TRG: Financeiro CONTAS e PAGAMENTOS
CREATE OR REPLACE FUNCTION public.trg_log_conta()
RETURNS TRIGGER AS $$
DECLARE
    v_autor_nome TEXT;
BEGIN
    SELECT nome_completo INTO v_autor_nome FROM public.perfis WHERE id = auth.uid();
    IF v_autor_nome IS NULL THEN
        v_autor_nome := 'Sistema';
    END IF;

    IF (TG_OP = 'INSERT') THEN
        -- Ignora se for categoria PRODUTOS para evitar duplicidade no Dashboard
        -- Pois a funﾃｧﾃ｣o fn_processar_venda_produto jﾃ｡ registra a atividade especﾃｭfica
        IF (NEW.categoria = 'Produtos') THEN
            RETURN NEW;
        END IF;

        IF (NEW.tipo_conta = 'pagar') THEN
            PERFORM public.registrar_atividade_dashboard(
                'financeiro',
                'Conta a Pagar Lanﾃｧada',
                v_autor_nome || ' lanﾃｧou nova despesa: ' || NEW.titulo || ' (R$ ' || NEW.valor || ')',
                jsonb_build_object('conta_id', NEW.id, 'tipo', 'pagar', 'Usuﾃ｡rio Criaﾃｧﾃ｣o', v_autor_nome)
            );
        ELSE
            PERFORM public.registrar_atividade_dashboard(
                'financeiro',
                'Conta a Receber Lanﾃｧada',
                v_autor_nome || ' lanﾃｧou nova receita: ' || NEW.titulo || ' (R$ ' || NEW.valor || ')',
                jsonb_build_object('conta_id', NEW.id, 'tipo', 'receber', 'Usuﾃ｡rio Criaﾃｧﾃ｣o', v_autor_nome)
            );
        END IF;
    END IF;

    -- Notificaﾃｧﾃ｣o de despesa para Admin
    IF (TG_OP = 'INSERT' AND NEW.tipo_conta = 'pagar' AND NEW.categoria != 'Produtos') THEN
        PERFORM public.notificar_admins(
            'Nova Despesa Lanﾃｧada',
            v_autor_nome || ' lanﾃｧou a conta: ' || NEW.titulo || ' (R$ ' || NEW.valor || ')',
            'financeiro'
        );
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;


DROP TRIGGER IF EXISTS trg_atividade_conta ON public.contas;
CREATE TRIGGER trg_atividade_conta
AFTER INSERT OR UPDATE ON public.contas
FOR EACH ROW EXECUTE FUNCTION public.trg_log_conta();

-- 6. TRG: Categorias (Procedimentos)
CREATE OR REPLACE FUNCTION public.trg_log_categoria()
RETURNS TRIGGER AS $$
DECLARE
    v_autor_nome TEXT;
BEGIN
    SELECT nome_completo INTO v_autor_nome FROM public.perfis WHERE id = auth.uid();
    IF v_autor_nome IS NULL THEN
        v_autor_nome := 'Sistema';
    END IF;

    IF (TG_OP = 'DELETE') THEN
        PERFORM public.registrar_atividade_dashboard(
            'configuracao',
            'Categoria Removida',
            v_autor_nome || ' removeu a categoria "' || OLD.nome || '"',
            jsonb_build_object('categoria_id', OLD.id, 'Usuﾃ｡rio Deleﾃｧﾃ｣o', v_autor_nome)
        );
        -- Notificaﾃｧﾃ｣o Admin
        PERFORM public.notificar_admins('Categoria Removida', v_autor_nome || ' deletou a categoria: ' || OLD.nome, 'sistema');
    END IF;

    IF (TG_OP = 'INSERT') THEN
        PERFORM public.notificar_admins('Nova Categoria Cadastrada', v_autor_nome || ' criou a categoria: ' || NEW.nome, 'sistema');
    END IF;

    RETURN COALESCE(NEW, OLD);
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_atividade_categoria ON public.categorias;
CREATE TRIGGER trg_atividade_categoria
AFTER INSERT OR DELETE ON public.categorias
FOR EACH ROW EXECUTE FUNCTION public.trg_log_categoria();

-- FIM DA ESTRUTURA DE TRIGGERS

-- 7. TRG: Configuraﾃｧﾃｵes da Clﾃｭnica
CREATE OR REPLACE FUNCTION public.fn_notificar_operacao_clinica()
RETURNS TRIGGER AS $$
DECLARE
    v_autor_nome TEXT;
    v_detalhes TEXT := '';
BEGIN
    SELECT nome_completo INTO v_autor_nome FROM public.perfis WHERE id = auth.uid();
    IF v_autor_nome IS NULL THEN v_autor_nome := 'Sistema'; END IF;

    IF (TG_TABLE_NAME = 'configuracoes_clinica') THEN
        -- Verificar taxas de cartﾃ｣o
        IF (NEW.taxa_debito != OLD.taxa_debito) THEN v_detalhes := v_detalhes || ' Taxa Dﾃｩbito: ' || OLD.taxa_debito || '% -> ' || NEW.taxa_debito || '%.'; END IF;
        IF (NEW.taxa_credito != OLD.taxa_credito) THEN v_detalhes := v_detalhes || ' Taxa Crﾃｩdito: ' || OLD.taxa_credito || '% -> ' || NEW.taxa_credito || '%.'; END IF;
        IF (NEW.taxa_credito_parcelado != OLD.taxa_credito_parcelado) THEN v_detalhes := v_detalhes || ' Taxa Crﾃｩdito Parcelado: ' || OLD.taxa_credito_parcelado || '% -> ' || NEW.taxa_credito_parcelado || '%.'; END IF;
        IF (NEW.taxa_pix != OLD.taxa_pix) THEN v_detalhes := v_detalhes || ' Taxa PIX: ' || OLD.taxa_pix || '% -> ' || NEW.taxa_pix || '%.'; END IF;

        IF v_detalhes != '' THEN
            PERFORM public.registrar_atividade_dashboard('configuracao', 'Alteraﾃｧﾃ｣o de Taxas', v_autor_nome || ' alterou as taxas: ' || v_detalhes, jsonb_build_object('old', OLD, 'new', NEW), auth.uid());
            PERFORM public.notificar_admins('Alteraﾃｧﾃ｣o de Taxas', v_autor_nome || ' alterou as taxas de cartﾃ｣o/pix.' || v_detalhes, 'configuracao');
        ELSE
            PERFORM public.registrar_atividade_dashboard('configuracao', 'Configuraﾃｧﾃｵes Alteradas', v_autor_nome || ' atualizou as configuraﾃｧﾃｵes da clﾃｭnica.', jsonb_build_object('old', OLD, 'new', NEW), auth.uid());
            PERFORM public.notificar_admins('Alteraﾃｧﾃ｣o em Informaﾃｧﾃｵes da Clﾃｭnica', v_autor_nome || ' atualizou as configuraﾃｧﾃｵes bﾃ｡sicas da clﾃｭnica.', 'sistema');
        END IF;
    ELSIF (TG_TABLE_NAME = 'horarios_clinica') THEN
        PERFORM public.registrar_atividade_dashboard('configuracao', 'Horﾃ｡rio de Funcionamento', v_autor_nome || ' alterou o horﾃ｡rio de funcionamento da clﾃｭnica.', jsonb_build_object('dia', NEW.dia_semana, 'fechado', NEW.fechado), auth.uid());
        PERFORM public.notificar_admins('Alteraﾃｧﾃ｣o em Horﾃ｡rio de Funcionamento', v_autor_nome || ' alterou o horﾃ｡rio de funcionamento da clﾃｭnica.', 'sistema');
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_log_config_clinica ON public.configuracoes_clinica;
CREATE TRIGGER trg_log_config_clinica
AFTER UPDATE ON public.configuracoes_clinica
FOR EACH ROW EXECUTE FUNCTION public.fn_notificar_operacao_clinica();

DROP TRIGGER IF EXISTS trg_log_horarios_clinica ON public.horarios_clinica;
CREATE TRIGGER trg_log_horarios_clinica
AFTER UPDATE ON public.horarios_clinica
FOR EACH ROW EXECUTE FUNCTION public.fn_notificar_operacao_clinica();


-- 8. TRG: Pacotes Templates
CREATE OR REPLACE FUNCTION public.fn_log_promocao()
RETURNS TRIGGER AS $$
DECLARE
    v_autor_nome TEXT;
    v_item_nome TEXT;
    v_msg TEXT;
BEGIN
    SELECT nome_completo INTO v_autor_nome FROM public.perfis WHERE id = auth.uid();
    IF v_autor_nome IS NULL THEN v_autor_nome := 'Sistema'; END IF;

    IF (TG_OP = 'DELETE') THEN
        v_item_nome := OLD.titulo;
        v_msg := v_autor_nome || ' excluiu a promoﾃｧﾃ｣o: "' || v_item_nome || '".';
        PERFORM public.registrar_atividade_dashboard('configuracao', 'Promoﾃｧﾃ｣o Excluﾃｭda', v_msg, jsonb_build_object('id', OLD.id), auth.uid());
        PERFORM public.notificar_admins('Promoﾃｧﾃ｣o Removida', v_msg, 'sistema');
        RETURN OLD;
    END IF;

    v_item_nome := NEW.titulo;
    IF (TG_OP = 'INSERT') THEN
        v_msg := v_autor_nome || ' criou a promoﾃｧﾃ｣o: "' || v_item_nome || '".';
        PERFORM public.registrar_atividade_dashboard('configuracao', 'Nova Promoﾃｧﾃ｣o', v_msg, jsonb_build_object('id', NEW.id), auth.uid());
        PERFORM public.notificar_admins('Nova Promoﾃｧﾃ｣o', v_msg, 'sistema');
    ELSIF (TG_OP = 'UPDATE') THEN
        v_msg := v_autor_nome || ' editou a promoﾃｧﾃ｣o: "' || v_item_nome || '".';
        PERFORM public.registrar_atividade_dashboard('configuracao', 'Promoﾃｧﾃ｣o Editada', v_msg, jsonb_build_object('id', NEW.id), auth.uid());
        PERFORM public.notificar_admins('Promoﾃｧﾃ｣o Alterada', v_msg, 'sistema');
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_atividade_promocao ON public.promocoes;
CREATE TRIGGER trg_atividade_promocao
AFTER INSERT OR UPDATE OR DELETE ON public.promocoes
FOR EACH ROW EXECUTE FUNCTION public.fn_log_promocao();

-- 9. TRG: Pacotes Templates
CREATE OR REPLACE FUNCTION public.fn_log_pacote_template()
RETURNS TRIGGER AS $$
DECLARE
    v_autor_nome TEXT;
BEGIN
    SELECT nome_completo INTO v_autor_nome FROM public.perfis WHERE id = auth.uid();
    IF v_autor_nome IS NULL THEN v_autor_nome := 'Sistema'; END IF;

    IF (TG_OP = 'INSERT') THEN
        PERFORM public.notificar_admins(
            'Novo Pacote Criado',
            v_autor_nome || ' criou o pacote: "' || NEW.titulo || '" (R$ ' || NEW.valor_total || ')',
            'sistema'
        );
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_atividade_pacote ON public.pacotes_templates;
CREATE TRIGGER trg_atividade_pacote
AFTER INSERT ON public.pacotes_templates
FOR EACH ROW EXECUTE FUNCTION public.fn_log_pacote_template();


-- ADICIONADO PRODUTOS

-- Tabela de Produtos
CREATE TABLE IF NOT EXISTS public.produtos (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    nome TEXT NOT NULL,
    descricao TEXT,
    preco_custo DECIMAL(10,2),
    preco_venda DECIMAL(10,2) NOT NULL,
    comissao_percentual DECIMAL(5,2) DEFAULT 0,
    estoque_atual INT DEFAULT 0,
    estoque_minimo INT DEFAULT 0,
    data_vencimento DATE,
    imagem_url TEXT,
    ativo BOOLEAN DEFAULT true,
    criado_em TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- Garantir que a coluna data_vencimento existe (caso a tabela jﾃ｡ tenha sido criada anteriormente)
ALTER TABLE public.produtos ADD COLUMN IF NOT EXISTS data_vencimento DATE;
ALTER TABLE public.produtos ADD COLUMN IF NOT EXISTS comissao_percentual DECIMAL(5,2) DEFAULT 0;

-- Tabela de Vendas de Produtos (Itens do Pedido)
CREATE TABLE IF NOT EXISTS public.vendas_produtos (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    produto_id UUID NOT NULL REFERENCES public.produtos(id) ON DELETE CASCADE,
    caixa_id UUID NOT NULL REFERENCES public.caixas(id),
    cliente_id UUID REFERENCES public.perfis(id),
    profissional_id UUID REFERENCES public.perfis(id),
    quantidade INT NOT NULL,
    valor_unitario DECIMAL(10,2) NOT NULL,
    valor_total DECIMAL(10,2) NOT NULL,
    forma_pagamento TEXT DEFAULT 'dinheiro',
    parcelas INT DEFAULT 1,
    comissao_aplicada DECIMAL(5,2),
    valor_comissao_bruta DECIMAL(10,2),
    valor_comissao_liquida DECIMAL(10,2),
    criado_em TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- Habilitar RLS
ALTER TABLE public.produtos ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.vendas_produtos ENABLE ROW LEVEL SECURITY;

-- Polﾃｭticas para PRODUTOS
DROP POLICY IF EXISTS "Admins gerenciam produtos" ON public.produtos;
CREATE POLICY "Admins gerenciam produtos" ON public.produtos FOR ALL TO authenticated USING (
    is_admin()
);

DROP POLICY IF EXISTS "Todos veem produtos ativos" ON public.produtos;
CREATE POLICY "Todos veem produtos ativos" ON public.produtos FOR SELECT USING (ativo = true);

-- Polﾃｭticas para VENDAS_PRODUTOS
DROP POLICY IF EXISTS "Admins veem todas as vendas" ON public.vendas_produtos;
CREATE POLICY "Admins veem todas as vendas" ON public.vendas_produtos FOR SELECT TO authenticated USING (
    is_admin()
);

DROP POLICY IF EXISTS "Permitir inserﾃｧﾃ｣o de vendas" ON public.vendas_produtos;
CREATE POLICY "Permitir inserﾃｧﾃ｣o de vendas" ON public.vendas_produtos FOR INSERT TO authenticated WITH CHECK (true);

-- ========================================================
-- PROCESSAMENTO DE VENDAS DE PRODUTOS
-- ========================================================

-- 1. TABELA DE HISTÓRICO DE ESTOQUE
CREATE TABLE IF NOT EXISTS public.historico_estoque (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    produto_id UUID NOT NULL REFERENCES public.produtos(id) ON DELETE CASCADE,
    tipo_movimentacao TEXT NOT NULL CHECK (tipo_movimentacao IN ('entrada', 'saida', 'ajuste')),
    quantidade INT NOT NULL,
    motivo TEXT,
    criado_por UUID REFERENCES public.perfis(id),
    criado_em TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

ALTER TABLE public.historico_estoque ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Admins veem historico completo" ON public.historico_estoque;
CREATE POLICY "Admins veem historico completo" ON public.historico_estoque FOR SELECT TO authenticated USING (public.is_admin());

-- 2. FUNÇÃO CONSOLIDADA DE PROCESSAMENTO
-- Esta função gerencia: estoque, financeiro (contas), comissões, taxas e notificações.
CREATE OR REPLACE FUNCTION public.handle_venda_produto_processamento()
RETURNS TRIGGER AS $$
DECLARE
    v_produto_nome TEXT;
    v_estoque_atual INT;
    v_estoque_minimo INT;
    v_comissao_percentual DECIMAL(5,2) := 0;
    v_taxa_pagamento DECIMAL(5,2) := 0;
    v_valor_liquido DECIMAL(10,2);
    v_valor_comissao_bruta DECIMAL(10,2);
    v_valor_comissao_liquida DECIMAL(10,2);
    v_autor_nome TEXT;
    v_cliente_nome TEXT;
BEGIN
    -- 1. Obter dados do produto
    SELECT nome, estoque_atual, estoque_minimo INTO v_produto_nome, v_estoque_atual, v_estoque_minimo
    FROM public.produtos WHERE id = NEW.produto_id FOR UPDATE;

    -- 2. Obter comissão do profissional (Se houver profissional vinculado)
    IF NEW.profissional_id IS NOT NULL THEN
        SELECT COALESCE(comissao_produtos_percentual, 0) INTO v_comissao_percentual
        FROM public.perfis WHERE id = NEW.profissional_id;
    END IF;

    -- 3. Obter taxas de pagamento da clínica para cálculo líquido
    SELECT 
        CASE 
            WHEN NEW.forma_pagamento = 'pix' THEN taxa_pix
            WHEN NEW.forma_pagamento = 'cartao_debito' THEN taxa_debito
            WHEN NEW.forma_pagamento = 'cartao_credito' THEN taxa_credito
            ELSE 0
        END INTO v_taxa_pagamento
    FROM public.configuracoes_clinica
    LIMIT 1;

    -- 4. Cálculo de Comissões e Valores Líquidos
    v_taxa_pagamento := COALESCE(v_taxa_pagamento, 0);
    v_valor_comissao_bruta := NEW.valor_total * (v_comissao_percentual / 100);
    v_valor_liquido := NEW.valor_total * (1 - (v_taxa_pagamento / 100));
    v_valor_comissao_liquida := v_valor_liquido * (v_comissao_percentual / 100);

    -- 5. Atualizar a própria linha da venda com os cálculos (Persistência)
    UPDATE public.vendas_produtos 
    SET 
        comissao_aplicada = v_comissao_percentual,
        valor_comissao_bruta = v_valor_comissao_bruta,
        valor_comissao_liquida = v_valor_comissao_liquida
    WHERE id = NEW.id;

    -- 6. Decrementar estoque
    UPDATE public.produtos 
    SET estoque_atual = estoque_atual - NEW.quantidade,
        atualizado_em = now()
    WHERE id = NEW.produto_id;

    -- 7. Registrar no HISTÓRICO DE ESTOQUE
    INSERT INTO public.historico_estoque (
        produto_id,
        tipo_movimentacao,
        quantidade,
        motivo,
        criado_por
    ) VALUES (
        NEW.produto_id,
        'saida',
        NEW.quantidade,
        'Venda direta (Ref: ' || NEW.id || ')',
        NEW.profissional_id
    );

    -- 8. Inserir no FINANCEIRO (Tabela 'contas')
    -- Fundamental: categoria='venda_produto' e status='pago' para o dashboard.
    INSERT INTO public.contas (
        titulo,
        valor,
        tipo_conta,
        status_pagamento,
        categoria,
        forma_pagamento,
        cliente_id,
        profissional_id,
        caixa_id,
        data_vencimento,
        data_pagamento,
        descricao,
        criado_por
    ) VALUES (
        'Venda de Produto: ' || v_produto_nome,
        NEW.valor_total,
        'receber',
        'pago',
        'Produtos',
        NEW.forma_pagamento,
        NEW.cliente_id,
        NEW.profissional_id,
        NEW.caixa_id,
        CURRENT_DATE,
        timezone('utc'::text, now()),
        'Venda do produto ' || v_produto_nome || ' (Ref: ' || NEW.id || ')',
        auth.uid()
    );

    -- 5. Registrar no Dashboard
    SELECT nome_completo INTO v_cliente_nome FROM public.perfis WHERE id = NEW.cliente_id;
    
    -- Obter nome do autor (quem estﾃ｡ realizando a aﾃｧﾃ｣o)
    SELECT COALESCE(nome_completo, 'Sistema') INTO v_autor_nome 
    FROM public.perfis 
    WHERE id = auth.uid();
    IF v_autor_nome IS NULL THEN v_autor_nome := 'Sistema'; END IF;

    -- 6. Log no Dashboard
    PERFORM public.registrar_atividade_dashboard(
        'venda',
        'Venda',
        'Produto ' || v_produto_nome || ' vendido para ' || COALESCE(v_cliente_nome, 'Cliente') || ' por R$ ' || NEW.valor_total,
        jsonb_build_object('venda_id', NEW.id, 'produto', v_produto_nome, 'cliente', v_cliente_nome)
    );

    -- 7. Alerta de Estoque Baixo (se aplicﾃ｡vel)
    IF (v_estoque_atual - NEW.quantidade <= v_estoque_minimo) THEN
        PERFORM public.notificar_admins(
            'Estoque Baixo!',
            'O produto ' || v_produto_nome || ' atingiu o estoque crﾃｭtico (' || (v_estoque_atual - NEW.quantidade) || ' unidades).',
            'estoque',
            jsonb_build_object('produto_id', NEW.produto_id, 'estoque', v_estoque_atual - NEW.quantidade)
        );
    END IF;

    -- 8. Notificar Venda para Admins
    PERFORM public.notificar_admins(
        'Nova Venda de Produto',
        'Produto: ' || v_produto_nome || E'\nQuantidade: ' || NEW.quantidade || E'\nTotal: R$ ' || NEW.valor_total || E'\nCliente: ' || COALESCE(v_cliente_nome, 'N/A') || E'\nVendedor: ' || v_autor_nome,
        'financeiro',
        jsonb_build_object('venda_id', NEW.id)
    );

    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Gatilho para processar venda de produto automaticamente
DROP TRIGGER IF EXISTS trg_venda_produto_processamento ON public.vendas_produtos;
CREATE TRIGGER trg_venda_produto_processamento
AFTER INSERT ON public.vendas_produtos
FOR EACH ROW
EXECUTE FUNCTION public.handle_venda_produto_processamento();

-- 4. TRIGGER PARA CAPTURAR AJUSTES MANUAIS DE ESTOQUE
CREATE OR REPLACE FUNCTION public.fn_log_ajuste_estoque()
RETURNS TRIGGER AS $$
BEGIN
    -- Se for um novo produto e tiver estoque inicial > 0
    IF (TG_OP = 'INSERT' AND NEW.estoque_atual > 0) THEN
        INSERT INTO public.historico_estoque (
            produto_id,
            tipo_movimentacao,
            quantidade,
            motivo,
            criado_por
        ) VALUES (
            NEW.id,
            'entrada',
            NEW.estoque_atual,
            'Estoque inicial no cadastro',
            auth.uid()
        );
    -- Se for uma atualizaﾃｧﾃ｣o e o estoque aumentou
    ELSIF (TG_OP = 'UPDATE' AND NEW.estoque_atual > OLD.estoque_atual) THEN
        INSERT INTO public.historico_estoque (
            produto_id,
            tipo_movimentacao,
            quantidade,
            motivo,
            criado_por
        ) VALUES (
            NEW.id,
            'entrada',
            NEW.estoque_atual - OLD.estoque_atual,
            'Entrada de Estoque / Ajuste Manual',
            auth.uid()
        );
    END IF;

    -- Notificaﾃｧﾃｵes de Produto
    DECLARE
        v_autor_nome TEXT;
    BEGIN
        SELECT nome_completo INTO v_autor_nome FROM public.perfis WHERE id = auth.uid();
        IF v_autor_nome IS NULL THEN v_autor_nome := 'Sistema'; END IF;

        IF (TG_OP = 'INSERT') THEN
            PERFORM public.notificar_admins(
                'Novo Produto Cadastrado',
                v_autor_nome || ' cadastrou o produto "' || NEW.nome || '" (Estoque: ' || NEW.estoque_atual || ')',
                'estoque'
            );
        END IF;

        -- Alerta de Vencimento Prﾃｳximo (menos de 30 dias)
        IF (NEW.data_vencimento IS NOT NULL AND NEW.data_vencimento <= (CURRENT_DATE + interval '30 days')) THEN
            PERFORM public.notificar_admins(
                'Alerta de Vencimento',
                'O produto "' || NEW.nome || '" vence em ' || TO_CHAR(NEW.data_vencimento, 'DD/MM/YYYY') || '.',
                'estoque'
            );
        END IF;
    END;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Atualizar a trigger para disparar no INSERT tambﾃｩm
DROP TRIGGER IF EXISTS trg_log_estoque_ajuste ON public.produtos;
CREATE TRIGGER trg_log_estoque_ajuste
AFTER INSERT OR UPDATE OF estoque_atual ON public.produtos
FOR EACH ROW 
EXECUTE FUNCTION public.fn_log_ajuste_estoque();

-- 1. CRIAﾃ�グ DO BUCKET DE PRODUTOS (CASO Nﾃグ EXISTA)
-- 1. CRIAÇÃO DO BUCKET DE PRODUTOS (CASO NÃO EXISTA)
-- Obs: O bucket costuma ser criado via Dashboard, mas garantimos as políticas aqui.
CREATE OR REPLACE FUNCTION public.fn_notificar_admin_no_show()
RETURNS TRIGGER AS $$
DECLARE
    v_admin_id UUID;
    v_cli_n TEXT;
    v_serv_n TEXT;
    v_prof_n TEXT;
BEGIN
    IF (NEW.status = 'no_show' AND (OLD.status IS NULL OR OLD.status <> 'no_show')) THEN
        -- Buscar nomes para a mensagem
        SELECT nome_completo INTO v_cli_n FROM public.perfis WHERE id = NEW.cliente_id;
        SELECT nome INTO v_serv_n FROM public.servicos WHERE id = NEW.servico_id;
        SELECT nome_completo INTO v_prof_n FROM public.perfis WHERE id = NEW.profissional_id;

        -- Notificar todos os admins
        FOR v_admin_id IN SELECT id FROM public.perfis WHERE tipo = 'admin' LOOP
            INSERT INTO public.notificacoes (user_id, titulo, mensagem, tipo, metadata)
            VALUES (
                v_admin_id,
                'Cliente não compareceu (No-Show)',
                'O cliente ' || COALESCE(v_cli_n, 'Desconhecido') || ' não compareceu ao agendamento de ' || COALESCE(v_serv_n, 'Serviço') || ' com ' || COALESCE(v_prof_n, 'Profissional') || ' em ' || TO_CHAR(NEW.data_hora, 'DD/MM/YYYY') || ' às ' || TO_CHAR(NEW.data_hora, 'HH24:MI') || '.',
                'agendamento',
                jsonb_build_object('agendamento_id', NEW.id, 'status', 'no_show')
            );
        END LOOP;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION public.fn_notificar_mudanca_agenda()
RETURNS TRIGGER AS $$
DECLARE
    v_prof_nome TEXT;
    v_autor_nome TEXT;
    v_periodo TEXT;
    v_detalhes_admin TEXT;
BEGIN
    -- Obter nome do profissional alvo (ou clﾃｭnica)
    IF NEW.profissional_id IS NOT NULL THEN
        SELECT nome_completo INTO v_prof_nome FROM public.perfis WHERE id = NEW.profissional_id;
    ELSE
        v_prof_nome := 'BLOQUEIO GLOBAL (CLﾃ康ICA)';
    END IF;

    -- Tentar obter nome do autor (quem realizou o bloqueio)
    IF (TG_TABLE_NAME = 'bloqueios_agenda') AND (NEW.usuario_id IS NOT NULL) THEN
        SELECT nome_completo INTO v_autor_nome FROM public.perfis WHERE id = NEW.usuario_id;
    END IF;

    -- Fallback para auth.uid()
    IF v_autor_nome IS NULL THEN
        SELECT nome_completo INTO v_autor_nome FROM public.perfis WHERE id = auth.uid();
    END IF;

    IF v_autor_nome IS NULL THEN v_autor_nome := 'Sistema'; END IF;

    -- Formatar perﾃｭodo (usando CONCAT para seguranﾃｧa contra NULLs)
    IF COALESCE(NEW.dia_todo, true) THEN
        v_periodo := 'Dia Todo';
    ELSE
        v_periodo := CONCAT(TO_CHAR(NEW.hora_inicio, 'HH24:MI'), ' ﾃ�s ', TO_CHAR(NEW.hora_fim, 'HH24:MI'));
    END IF;

    IF (TG_TABLE_NAME = 'bloqueios_agenda') THEN
        -- 1. NOTIFICAﾃ�グ PARA ADMINS
        v_detalhes_admin := CONCAT(
            'DETALHES DO BLOQUEIO',
            E'\nProfissional (que realizou o bloqueio): ', v_autor_nome,
            E'\nData: ', TO_CHAR(NEW.data, 'DD/MM/YYYY'),
            E'\nHora: ', v_periodo,
            E'\nMotivo: ', COALESCE(NEW.motivo, 'Nﾃ｣o informado')
        );

        PERFORM public.notificar_admins(
            'Novo Bloqueio na Agenda',
            v_detalhes_admin,
            'agenda',
            jsonb_build_object(
                'autor', v_autor_nome,
                'data', NEW.data,
                'hora', v_periodo,
                'motivo', NEW.motivo,
                'profissional_alvo', v_prof_nome
            )
        );

        -- 2. NOTIFICAﾃ�グ PARA O PROFISSIONAL (Apenas se for um profissional especﾃｭfico)
        IF NEW.profissional_id IS NOT NULL THEN
            INSERT INTO public.notificacoes (user_id, titulo, mensagem, tipo)
            VALUES (
                NEW.profissional_id,
                'Agenda Bloqueada',
                CONCAT('Sua agenda foi bloqueada para o dia ', TO_CHAR(NEW.data, 'DD/MM/YYYY'), ' (', v_periodo, ').'),
                'agenda'
            );
        END IF;

        -- 3. LOG NO DASHBOARD
        PERFORM public.registrar_atividade_dashboard(
            'agendamento',
            'Bloqueio de Agenda',
            CONCAT(v_autor_nome, ' bloqueou a agenda de ', COALESCE(v_prof_nome, 'Todos'), ' - ', TO_CHAR(NEW.data, 'DD/MM/YYYY'), ' (', v_periodo, ')'),
            jsonb_build_object('profissional', v_prof_nome, 'motivo', NEW.motivo)
        );

    ELSIF (TG_TABLE_NAME = 'horarios_almoco_profissional') THEN
        v_detalhes_admin := COALESCE(v_prof_nome, 'Profissional') || ' alterou o almoﾃｧo (' || 
                            CASE NEW.dia_semana 
                            WHEN 0 THEN 'Dom' WHEN 1 THEN 'Seg' WHEN 2 THEN 'Ter' 
                            WHEN 3 THEN 'Qua' WHEN 4 THEN 'Qui' WHEN 5 THEN 'Sex' WHEN 6 THEN 'Sﾃ｡b' END ||
                            ') para ' || TO_CHAR(NEW.hora_inicio, 'HH24:MI') || ' - ' || TO_CHAR(NEW.hora_fim, 'HH24:MI');

        PERFORM public.notificar_admins('Alteraﾃｧﾃ｣o de Intervalo - ' || COALESCE(v_prof_nome, 'Agenda'), v_detalhes_admin, 'agenda');
        
        -- Notificar profissional
        IF NEW.profissional_id IS NOT NULL THEN
            INSERT INTO public.notificacoes (user_id, titulo, mensagem, tipo)
            VALUES (
                NEW.profissional_id,
                'Intervalo Alterado',
                'Seu horﾃ｡rio de almoﾃｧo foi alterado para ' || TO_CHAR(NEW.hora_inicio, 'HH24:MI') || ' ﾃ�s ' || TO_CHAR(NEW.hora_fim, 'HH24:MI') || '.',
                'agenda'
            );
        END IF;
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Triggers para Bloqueios e Almoﾃｧo
DROP TRIGGER IF EXISTS trg_notificar_bloqueio ON public.bloqueios_agenda;
CREATE TRIGGER trg_notificar_bloqueio
AFTER INSERT ON public.bloqueios_agenda
FOR EACH ROW EXECUTE FUNCTION public.fn_notificar_mudanca_agenda();

DROP TRIGGER IF EXISTS trg_notificar_almoco ON public.horarios_almoco_profissional;
CREATE TRIGGER trg_notificar_almoco
AFTER UPDATE ON public.horarios_almoco_profissional
FOR EACH ROW EXECUTE FUNCTION public.fn_notificar_mudanca_agenda();

-- Funﾃｧﾃ｣o para atualizar sessoes de pacotes contratados quando um agendamento ﾃｩ concluﾃｭdo
CREATE OR REPLACE FUNCTION public.fn_atualizar_sessao_pacote()
RETURNS TRIGGER AS $$
BEGIN
    -- Se o agendamento foi marcado como concluﾃｭdo e possui um pacote contratado
    IF (OLD.status != 'concluido' AND NEW.status = 'concluido' AND NEW.pacote_contratado_id IS NOT NULL) THEN
        -- Tentar debitar uma sessﾃ｣o do pacote (incrementar as realizadas)
        UPDATE public.pacotes_contratados
        SET sessoes_realizadas = sessoes_realizadas + 1
        WHERE id = NEW.pacote_contratado_id
          AND sessoes_realizadas < sessoes_totais;
          
        -- Marcar como finalizado se atingir o total
        UPDATE public.pacotes_contratados
        SET status = 'finalizado'
        WHERE id = NEW.pacote_contratado_id
          AND sessoes_realizadas = sessoes_totais;
    END IF;
    
    -- Se o agendamento for cancelado/voltar de concluﾃｭdo, talvez estornar a sessﾃ｣o?
    -- No momento apenas decrementamos na conclusﾃ｣o.
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trg_atualizar_pacote ON public.agendamentos;
CREATE TRIGGER trg_atualizar_pacote
AFTER UPDATE ON public.agendamentos
FOR EACH ROW EXECUTE FUNCTION public.fn_atualizar_sessao_pacote();

-- Funﾃｧﾃ｣o RPC para incrementar sessﾃｵes de pacotes (usada pelo app)
CREATE OR REPLACE FUNCTION public.increment_pacote_sessoes(contract_id UUID)
RETURNS VOID AS $$
BEGIN
  UPDATE public.pacotes_contratados
  SET sessoes_realizadas = sessoes_realizadas + 1,
      status = CASE 
                 WHEN sessoes_realizadas + 1 >= sessoes_totais THEN 'finalizado'
                 ELSE status 
               END
  WHERE id = contract_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;


-- --------------------------------------------------------
-- TRIGGER: Automaﾃｧﾃ｣o de Perfis ao Criar Usuﾃ｡rio no Auth
-- --------------------------------------------------------

CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  -- Limpeza de registros ﾃｳrfﾃ｣os para evitar o erro 500 por conflito de Unique Email
  DELETE FROM public.perfis WHERE email = NEW.email AND id <> NEW.id;

  INSERT INTO public.perfis (id, nome_completo, email, tipo, avatar_url, telefone, cargo, ativo)
  VALUES (
    NEW.id,
    NULLIF(BTRIM(COALESCE(NEW.raw_user_meta_data->>'full_name', NEW.raw_user_meta_data->>'nome_completo', 'Usuﾃ｡rio Novo')), ''),
    NEW.email,
    NULLIF(BTRIM(COALESCE(NEW.raw_user_meta_data->>'user_type', NEW.raw_user_meta_data->>'tipo', 'cliente')), ''),
    NULLIF(BTRIM(COALESCE(NEW.raw_user_meta_data->>'avatar_url', 'https://cdn-icons-png.flaticon.com/512/149/149071.png')), ''),
    NULLIF(BTRIM(COALESCE(NEW.raw_user_meta_data->>'telefone', NEW.raw_user_meta_data->>'phone', NEW.phone, '')), ''),
    NULLIF(BTRIM(COALESCE(NEW.raw_user_meta_data->>'cargo', NEW.raw_user_meta_data->>'job_title', '')), ''),
    true
  )
  ON CONFLICT (id) DO UPDATE SET
    email = EXCLUDED.email,
    nome_completo = COALESCE(EXCLUDED.nome_completo, public.perfis.nome_completo),
    telefone = COALESCE(EXCLUDED.telefone, public.perfis.telefone),
    avatar_url = COALESCE(EXCLUDED.avatar_url, public.perfis.avatar_url),
    cargo = COALESCE(EXCLUDED.cargo, public.perfis.cargo);
  
  RETURN NEW;
EXCEPTION WHEN OTHERS THEN
  -- Log de erro se falhar a criaﾃｧﾃ｣o do perfil, mas permite criaﾃｧﾃ｣o no Auth
  RAISE WARNING 'Erro no trigger handle_new_user: %', SQLERRM;
  RETURN NEW;
END;
$$;


-- Configuração segura do trigger no auth.users
-- Tenta criar o trigger usando SQL dinâmico para evitar falhas de permissão no parse
DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'auth' AND table_name = 'users') THEN
        BEGIN
            EXECUTE 'DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users';
            EXECUTE 'CREATE TRIGGER on_auth_user_created
                AFTER INSERT ON auth.users
                FOR EACH ROW EXECUTE FUNCTION public.handle_new_user()';
        EXCEPTION WHEN OTHERS THEN
            RAISE NOTICE 'Aviso: Não foi possível gerenciar o trigger em auth.users. Detalhe: %', SQLERRM;
        END;
    END IF;
END $$;

-- Garantir permissﾃｵes bﾃ｡sicas para o funcionamento do Auth e Perfis
GRANT USAGE ON SCHEMA public TO anon, authenticated;
GRANT ALL ON public.perfis TO service_role;
GRANT SELECT ON public.perfis TO anon, authenticated;
GRANT UPDATE, INSERT ON public.perfis TO authenticated;

-- Configuraﾃｧﾃ｣o de RLS para Perfis
ALTER TABLE public.perfis ENABLE ROW LEVEL SECURITY;

-- 1. Qualquer usuﾃ｡rio autenticado vﾃｪ seu prﾃｳprio perfil
DROP POLICY IF EXISTS "Usuﾃ｡rios veem seu prﾃｳprio perfil" ON public.perfis;
CREATE POLICY "Usuﾃ｡rios veem seu prﾃｳprio perfil" ON public.perfis
    FOR SELECT TO authenticated USING (auth.uid() = id);

-- 2. Qualquer usuﾃ｡rio autenticado atualiza seu prﾃｳprio perfil
DROP POLICY IF EXISTS "Usuﾃ｡rios atualizam seu prﾃｳprio perfil" ON public.perfis;
CREATE POLICY "Usuﾃ｡rios atualizam seu prﾃｳprio perfil" ON public.perfis
    FOR UPDATE TO authenticated USING (auth.uid() = id) WITH CHECK (auth.uid() = id);

-- 3. Admins veem e gerenciam todos os perfis (Usa funﾃｧﾃ｣o para evitar recursﾃ｣o)
DROP POLICY IF EXISTS "Admins veem todos os perfis" ON public.perfis;
CREATE POLICY "Admins veem todos os perfis" ON public.perfis
    FOR SELECT TO authenticated USING (public.is_admin());

DROP POLICY IF EXISTS "Admins gerenciam todos os perfis" ON public.perfis;
CREATE POLICY "Admins gerenciam todos os perfis" ON public.perfis
    FOR ALL TO authenticated USING (public.is_admin());

-- 4. Permitir que novos usuﾃ｡rios sejam inseridos (pelo trigger handle_new_user)
-- Nota: O trigger usa SECURITY DEFINER, entﾃ｣o tecnicamente ignora RLS,
-- mas ﾃｩ bom ter polﾃｭtica de INSERT se o app tentar inserir diretamente.
DROP POLICY IF EXISTS "Inserﾃｧﾃ｣o de perfil por sistema" ON public.perfis;
CREATE POLICY "Inserﾃｧﾃ｣o de perfil por sistema" ON public.perfis
    FOR INSERT TO service_role WITH CHECK (true);


-- ############################################################################
-- CONFIGURAﾃ�グ DE STORAGE (BUCKETS E POLﾃ控ICAS)
-- ############################################################################

-- Criar buckets se nﾃ｣o existirem
INSERT INTO storage.buckets (id, name, public)
VALUES 
  ('perfis', 'perfis', true),
  ('servicos', 'servicos', true),
  ('produtos', 'produtos', true),
  ('promocoes', 'promocoes', true),
  ('avaliacoes', 'avaliacoes', true)
ON CONFLICT (id) DO NOTHING;

-- Liberar acesso pﾃｺblico para leitura
DROP POLICY IF EXISTS "Acesso Pﾃｺblico Leitura" ON storage.objects;
CREATE POLICY "Acesso Pﾃｺblico Leitura" ON storage.objects FOR SELECT USING (bucket_id IN ('perfis', 'servicos', 'produtos', 'promocoes', 'avaliacoes'));

-- Liberar upload para usuﾃ｡rios autenticados
DROP POLICY IF EXISTS "Upload Autenticado" ON storage.objects;
CREATE POLICY "Upload Autenticado" ON storage.objects FOR INSERT WITH CHECK (auth.role() = 'authenticated');

-- Liberar deleﾃｧﾃ｣o para usuﾃ｡rios autenticados
DROP POLICY IF EXISTS "Deleﾃｧﾃ｣o Autenticada" ON storage.objects;
CREATE POLICY "Deleﾃｧﾃ｣o Autenticada" ON storage.objects FOR DELETE USING (auth.role() = 'authenticated');


-- ============================================================================
-- CORREﾃ�髭S DE SEGURANﾃ② (RLS) - ADMINISTRAﾃ�グ
-- Permite que administradores realizem aﾃｧﾃｵes em nome dos clientes
-- ============================================================================

-- 1. AGENDAMENTOS: Permite que Admins insiram agendamentos para qualquer cliente
DROP POLICY IF EXISTS "Admins inserem agendamentos" ON public.agendamentos;
CREATE POLICY "Admins inserem agendamentos" ON public.agendamentos
    FOR INSERT 
    WITH CHECK (public.is_admin());

-- 2. PACOTES CONTRATADOS: Permite que Admins contratem pacotes para clientes
DROP POLICY IF EXISTS "Admins contratam pacotes" ON public.pacotes_contratados;
CREATE POLICY "Admins contratam pacotes" ON public.pacotes_contratados
    FOR INSERT 
    WITH CHECK (public.is_admin());

-- 3. Garantir polﾃｭticas de SELECT consistentes
DROP POLICY IF EXISTS "Agendamentos visﾃｭveis para dono/admin" ON public.agendamentos;
CREATE POLICY "Agendamentos visﾃｭveis para dono/admin" ON public.agendamentos 
    FOR SELECT 
    USING (auth.uid() = cliente_id OR auth.uid() = profissional_id OR public.is_admin());

DROP POLICY IF EXISTS "Pacotes contratados visﾃｭveis para dono/admin" ON public.pacotes_contratados;
CREATE POLICY "Pacotes contratados visﾃｭveis para dono/admin" ON public.pacotes_contratados 
    FOR SELECT 
    USING (auth.uid() = cliente_id OR public.is_admin());

