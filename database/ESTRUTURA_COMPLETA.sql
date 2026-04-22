-- ========================================================
-- SCRIPT DE ESTRUTURA COMPLETA E DADOS FICTÍCIOS - CLÍNICA ESTÉTICA
-- Limpa tudo e recria o banco de dados do zero corretamente (V5)
-- ========================================================

-- Garante que a extensão pgcrypto existe (para o crypt se necessário)
CREATE EXTENSION IF NOT EXISTS pgcrypto;

-- --------------------------------------------------------
-- 0. LIMPEZA E CONFIGURAÇÕES INICIAIS
-- --------------------------------------------------------

-- Limpeza total de tabelas para recriação limpa
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
    id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
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

-- Tabela de Serviços (Procedimentos)
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

-- Tabela de Junção Pacote - Serviços
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
    caixa_id UUID, -- Referência manual para evitar circularidade pesada se necessário
    comissao_percentual DOUBLE PRECISION DEFAULT 0,
    criado_em TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL,

    -- Restrições de Chave Estrangeira Nomeadas (Melhora compatibilidade PostgREST)
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
    sessao_numero INT, -- NOVO: Número da sessão neste pacote
    criado_em TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL,
    CONSTRAINT chk_data_hora_futura CHECK (data_hora >= criado_em - interval '1 minute')
);

-- Tabela de Avaliações
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
-- 2. TABELAS DE APOIO E CONFIGURAÇÃO
-- --------------------------------------------------------

CREATE TABLE IF NOT EXISTS public.profissional_servicos (
    profissional_id UUID REFERENCES public.perfis(id) ON DELETE CASCADE,
    servico_id UUID REFERENCES public.servicos(id) ON DELETE CASCADE,
    PRIMARY KEY (profissional_id, servico_id)
);

-- Vínculo Profissional - Pacote
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

-- Horários de Almoço por Profissional (Específico por dia)
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

-- NOVO: Horários de Trabalho por Profissional (Granular)
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

-- Horários de Funcionamento da Clínica
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

COMMENT ON COLUMN public.bloqueios_agenda.hora_inicio IS 'Hora de início para bloqueio parcial. Se NULL, o dia todo é bloqueado.';
COMMENT ON COLUMN public.bloqueios_agenda.hora_fim IS 'Hora de fim para bloqueio parcial. Se NULL, o dia todo é bloqueado.';
COMMENT ON COLUMN public.bloqueios_agenda.profissional_id IS 'Se definido, o bloqueio aplica-se apenas a este profissional. Se NULL, aplica-se a toda a clínica.';


-- Notificações do Sistema
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


-- Configurações da Clínica
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

-- Tabela de Logs de Administração (Auditoria)
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

-- Tabela de Promoções (Banner Inicial)
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
    categoria TEXT, -- Ex: Aluguel, Produtos, Marketing, Salário
    forma_pagamento TEXT, -- NOVO
    cliente_id UUID REFERENCES public.perfis(id), -- NOVO
    profissional_id UUID REFERENCES public.perfis(id), -- NOVO
    data_vencimento DATE NOT NULL,
    data_pagamento TIMESTAMP WITH TIME ZONE,
    caixa_id UUID REFERENCES public.caixas(id),
    metadata JSONB DEFAULT '{}'::jsonb,
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
    usuario_id UUID REFERENCES public.perfis(id), -- Para compatibilidade com versões anteriores se necessário
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
    user_id UUID REFERENCES public.perfis(id) ON DELETE SET NULL, -- Usuário que realizou a ação
    criado_em TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- Índices para novas tabelas
CREATE INDEX IF NOT EXISTS idx_pacote_servicos_pacote_id ON public.pacote_servicos(pacote_id);
CREATE INDEX IF NOT EXISTS idx_pacote_servicos_servico_id ON public.pacote_servicos(servico_id);
CREATE INDEX IF NOT EXISTS idx_pacotes_contratados_cliente_id ON public.pacotes_contratados(cliente_id);
CREATE INDEX IF NOT EXISTS idx_vendas_produtos_produto_id ON public.vendas_produtos(produto_id);
CREATE INDEX IF NOT EXISTS idx_vendas_produtos_cliente_id ON public.vendas_produtos(cliente_id);
CREATE INDEX IF NOT EXISTS idx_dashboard_atividades_criado_em ON public.dashboard_atividades(criado_em);

-- --------------------------------------------------------
-- 3. SEGURANÇA (RLS)
-- --------------------------------------------------------

-- Função para registrar usuário (profissional ou administrador) via RPC, agindo como administrador
-- Isso insere diretamente na tabela auth.users e auth.identities para garantir que o acesso funcione imediatamente
-- Requer SECURITY DEFINER para ter permissões de bypass RLS em tabelas do sistema auth.

CREATE OR REPLACE FUNCTION public.registrar_usuario_admin(
    p_email TEXT,
    p_password TEXT,
    p_nome TEXT,
    p_tipo TEXT DEFAULT 'profissional',
    p_cargo TEXT DEFAULT '',
    p_telefone TEXT DEFAULT NULL,
    p_avatar_url TEXT DEFAULT NULL,
    p_comissao_produtos DECIMAL DEFAULT 0,
    p_comissao_agendamentos DECIMAL DEFAULT 0,
    p_ativo BOOLEAN DEFAULT true
) RETURNS UUID AS $$
DECLARE
    v_user_id UUID;
    v_instance_id UUID := '00000000-0000-0000-0000-000000000000'; -- ID padrão do Supabase
BEGIN
    -- 1. Verificar se o e-mail já existe
    IF EXISTS (SELECT 1 FROM auth.users WHERE email = p_email) THEN
        RAISE EXCEPTION 'E-mail % já está cadastrado no sistema de autenticação.', p_email;
    END IF;

    -- 2. Inserir na tabela auth.users
    INSERT INTO auth.users (
        instance_id,
        id,
        aud,
        role,
        email,
        encrypted_password,
        email_confirmed_at,
        last_sign_in_at,
        raw_app_meta_data,
        raw_user_meta_data,
        is_super_admin,
        created_at,
        updated_at,
        confirmation_token,
        recovery_token,
        email_change_token_new,
        email_change
    )
    VALUES (
        v_instance_id,
        gen_random_uuid(),
        'authenticated',
        'authenticated',
        p_email,
        crypt(p_password, gen_salt('bf')),
        now(),
        now(),
        jsonb_build_object('provider', 'email', 'providers', array['email']),
        jsonb_build_object('full_name', p_nome, 'avatar_url', p_avatar_url, 'tipo', p_tipo),
        false,
        now(),
        now(),
        '',
        '',
        '',
        ''
    )
    RETURNING id INTO v_user_id;

    -- 3. Inserir na tabela auth.identities (ESSENCIAL para o Supabase reconhecer o login via e-mail)
    INSERT INTO auth.identities (
        id,
        user_id,
        identity_data,
        provider,
        last_sign_in_at,
        created_at,
        updated_at,
        provider_id
    )
    VALUES (
        gen_random_uuid(),
        v_user_id,
        format('{"sub": "%s", "email": "%s"}', v_user_id::text, p_email)::jsonb,
        'email',
        now(),
        now(),
        now(),
        p_email
    );

    -- 4. Inserir ou atualizar perfil na tabela public.perfis
    -- Usamos ON CONFLICT para evitar erro caso um trigger automático já tenha criado o perfil
    INSERT INTO public.perfis (
        id,
        nome_completo,
        email,
        tipo,
        cargo,
        telefone,
        comissao_produtos_percentual,
        comissao_agendamentos_percentual,
        avatar_url,
        ativo,
        criado_em,
        ultimo_login
    )
    VALUES (
        v_user_id,
        p_nome,
        p_email,
        p_tipo,
        NULLIF(BTRIM(p_cargo), ''),
        NULLIF(BTRIM(p_telefone), ''),
        p_comissao_produtos,
        p_comissao_agendamentos,
        NULLIF(BTRIM(p_avatar_url), ''),
        p_ativo,
        now(),
        now()
    )
    ON CONFLICT (id) DO UPDATE SET
        nome_completo = COALESCE(EXCLUDED.nome_completo, public.perfis.nome_completo),
        tipo = COALESCE(EXCLUDED.tipo, public.perfis.tipo),
        cargo = COALESCE(EXCLUDED.cargo, public.perfis.cargo),
        telefone = COALESCE(EXCLUDED.telefone, public.perfis.telefone),
        comissao_produtos_percentual = COALESCE(EXCLUDED.comissao_produtos_percentual, public.perfis.comissao_produtos_percentual),
        comissao_agendamentos_percentual = COALESCE(EXCLUDED.comissao_agendamentos_percentual, public.perfis.comissao_agendamentos_percentual),
        avatar_url = COALESCE(EXCLUDED.avatar_url, public.perfis.avatar_url),
        ativo = COALESCE(EXCLUDED.ativo, public.perfis.ativo),
        ultimo_login = COALESCE(EXCLUDED.ultimo_login, public.perfis.ultimo_login);

    RETURN v_user_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

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
ALTER TABLE public.caixas ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.horarios_clinica ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.horarios_trabalho_profissional ENABLE ROW LEVEL SECURITY;


-- ############################################################################
-- FUNÇÕES AUXILIARES E LIMPEZA
-- ############################################################################

-- Limpeza de funções antigas para evitar erros de ambiguidade
DROP FUNCTION IF EXISTS public.registrar_atividade_dashboard(text, text, text, jsonb, uuid);
DROP FUNCTION IF EXISTS public.registrar_atividade_dashboard(text, text, text, jsonb);
DROP FUNCTION IF EXISTS public.registrar_atividade_dashboard(text, text, text);
DROP FUNCTION IF EXISTS public.is_admin();
DROP FUNCTION IF EXISTS public.is_profissional();

-- Função auxiliar para verificar se o usuário é admin sem causar recursão
-- Usa SECURITY DEFINER e SET search_path para garantir isolamento e permissão
CREATE OR REPLACE FUNCTION public.is_admin()
RETURNS boolean AS $$
BEGIN
  RETURN EXISTS (
    SELECT 1 FROM public.perfis
    WHERE id = auth.uid() AND tipo = 'admin'
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

-- Função auxiliar para verificar se o usuário é profissional
CREATE OR REPLACE FUNCTION public.is_profissional()
RETURNS boolean AS $$
BEGIN
  RETURN EXISTS (
    SELECT 1 FROM public.perfis
    WHERE id = auth.uid() AND tipo = 'profissional'
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;


DROP POLICY IF EXISTS "Usuários podem visualizar perfis" ON public.perfis;
CREATE POLICY "Usuários podem visualizar perfis" ON public.perfis 
    FOR SELECT 
    TO authenticated 
    USING (tipo IN ('profissional', 'admin', 'administrador') OR auth.uid() = id);

DROP POLICY IF EXISTS "Usuários editam próprio perfil" ON public.perfis;
CREATE POLICY "Usuários editam próprio perfil" ON public.perfis 
    FOR UPDATE 
    USING (auth.uid() = id);

DROP POLICY IF EXISTS "Admins podem atualizar perfis" ON public.perfis;
CREATE POLICY "Admins podem atualizar perfis" ON public.perfis
    FOR ALL
    TO authenticated
    USING (is_admin())
    WITH CHECK (is_admin());

DROP POLICY IF EXISTS "Inserção de perfis" ON public.perfis;
CREATE POLICY "Inserção de perfis" ON public.perfis 
    FOR INSERT 
    WITH CHECK (auth.uid() = id OR is_admin());

-- Políticas de SERVIÇOS/CATEGORIAS
DROP POLICY IF EXISTS "Serviços visíveis para todos" ON public.servicos;
CREATE POLICY "Serviços visíveis para todos" ON public.servicos FOR SELECT USING (true);

DROP POLICY IF EXISTS "Categorias visíveis para todos" ON public.categorias;
CREATE POLICY "Categorias visíveis para todos" ON public.categorias FOR SELECT USING (true);

DROP POLICY IF EXISTS "Admins cadastram serviços" ON public.servicos;
CREATE POLICY "Admins cadastram serviços" ON public.servicos FOR ALL TO authenticated 
USING (is_admin());

DROP POLICY IF EXISTS "Admins cadastram categorias" ON public.categorias;
CREATE POLICY "Admins cadastram categorias" ON public.categorias FOR ALL TO authenticated 
USING (is_admin());

-- Políticas de DISPONIBILIDADE E VÍNCULOS DE SERVIÇO
DROP POLICY IF EXISTS "Disponibilidade visível para todos" ON public.disponibilidade_profissional;
CREATE POLICY "Disponibilidade visível para todos" ON public.disponibilidade_profissional FOR SELECT USING (true);

DROP POLICY IF EXISTS "Profissional serviços visíveis para todos" ON public.profissional_servicos;
CREATE POLICY "Profissional serviços visíveis para todos" ON public.profissional_servicos FOR SELECT USING (true);

DROP POLICY IF EXISTS "Admins configuram disponibilidade" ON public.disponibilidade_profissional;
CREATE POLICY "Admins configuram disponibilidade" ON public.disponibilidade_profissional FOR ALL TO authenticated USING (is_admin());

DROP POLICY IF EXISTS "Admins configuram prof servicos" ON public.profissional_servicos;
CREATE POLICY "Admins configuram prof servicos" ON public.profissional_servicos FOR ALL TO authenticated USING (is_admin());

-- Políticas de VÍNCULOS DE PACOTE
DROP POLICY IF EXISTS "Profissional pacotes visíveis para todos" ON public.profissional_pacotes;
CREATE POLICY "Profissional pacotes visíveis para todos" ON public.profissional_pacotes FOR SELECT USING (true);

DROP POLICY IF EXISTS "Admins configuram prof pacotes" ON public.profissional_pacotes;
CREATE POLICY "Admins configuram prof pacotes" ON public.profissional_pacotes FOR ALL TO authenticated USING (is_admin());

-- Políticas de HORÁRIOS DE ALMOÇO
DROP POLICY IF EXISTS "Almoço visível para todos" ON public.horarios_almoco_profissional;
CREATE POLICY "Almoço visível para todos" ON public.horarios_almoco_profissional FOR SELECT USING (true);

DROP POLICY IF EXISTS "Admins/Profissionais gerenciam almoço" ON public.horarios_almoco_profissional;
CREATE POLICY "Admins/Profissionais gerenciam almoço" ON public.horarios_almoco_profissional FOR ALL TO authenticated 
USING (auth.uid() = profissional_id OR is_admin());

-- Políticas de PROMOÇÕES
DROP POLICY IF EXISTS "Promoções visíveis por todos" ON public.promocoes;
CREATE POLICY "Promoções visíveis por todos" ON public.promocoes FOR SELECT USING (ativo = true);

DROP POLICY IF EXISTS "Admins podem tudo em promoções" ON public.promocoes;
CREATE POLICY "Admins podem tudo em promoções" ON public.promocoes FOR ALL USING (is_admin());

-- Políticas de AGENDAMENTOS
DROP POLICY IF EXISTS "Agendamentos visíveis para dono" ON public.agendamentos;
CREATE POLICY "Agendamentos visíveis para dono" ON public.agendamentos FOR SELECT USING (auth.uid() = cliente_id OR auth.uid() = profissional_id OR is_admin());

DROP POLICY IF EXISTS "Clientes inserem agendamentos" ON public.agendamentos;
CREATE POLICY "Clientes inserem agendamentos" ON public.agendamentos FOR INSERT WITH CHECK (auth.uid() = cliente_id);

DROP POLICY IF EXISTS "Dono atualiza agendamento" ON public.agendamentos;

-- Políticas de PACOTES
DROP POLICY IF EXISTS "Pacotes visíveis por todos" ON public.pacotes_templates;
CREATE POLICY "Pacotes visíveis por todos" ON public.pacotes_templates FOR SELECT USING (true);

DROP POLICY IF EXISTS "Admins gerenciam templates de pacotes" ON public.pacotes_templates;
CREATE POLICY "Admins gerenciam templates de pacotes" ON public.pacotes_templates FOR ALL TO authenticated USING (is_admin());

DROP POLICY IF EXISTS "Pacote serviços visíveis por todos" ON public.pacote_servicos;
CREATE POLICY "Pacote serviços visíveis por todos" ON public.pacote_servicos FOR SELECT USING (true);

DROP POLICY IF EXISTS "Admins gerenciam pacote servicos" ON public.pacote_servicos;
CREATE POLICY "Admins gerenciam pacote servicos" ON public.pacote_servicos FOR ALL TO authenticated USING (is_admin());

DROP POLICY IF EXISTS "Pacotes contratados visíveis para dono/admin" ON public.pacotes_contratados;
CREATE POLICY "Pacotes contratados visíveis para dono/admin" ON public.pacotes_contratados FOR SELECT USING (auth.uid() = cliente_id OR is_admin());

DROP POLICY IF EXISTS "Clientes podem contratar pacotes" ON public.pacotes_contratados;
CREATE POLICY "Clientes podem contratar pacotes" ON public.pacotes_contratados FOR INSERT WITH CHECK (auth.uid() = cliente_id);

DROP POLICY IF EXISTS "Dono/Admin podem atualizar pacotes contratados" ON public.pacotes_contratados;
CREATE POLICY "Dono/Admin podem atualizar pacotes contratados" ON public.pacotes_contratados FOR UPDATE USING (auth.uid() = cliente_id OR is_admin());

CREATE POLICY "Dono atualiza agendamento" ON public.agendamentos FOR UPDATE USING (auth.uid() = cliente_id OR auth.uid() = profissional_id OR is_admin());

-- Políticas de NOTIFICAÇÕES
DROP POLICY IF EXISTS "Ver próprias notificações" ON public.notificacoes;
CREATE POLICY "Ver próprias notificações" ON public.notificacoes FOR SELECT USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "Atualizar próprias notificações" ON public.notificacoes;
CREATE POLICY "Atualizar próprias notificações" ON public.notificacoes FOR UPDATE USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "Sistema insere notificações" ON public.notificacoes;
CREATE POLICY "Sistema insere notificações" ON public.notificacoes FOR INSERT WITH CHECK (true);

-- Políticas de AVALIAÇÕES
DROP POLICY IF EXISTS "Avaliações visíveis para todos" ON public.avaliacoes;
CREATE POLICY "Avaliações visíveis para todos" ON public.avaliacoes FOR SELECT USING (true);

DROP POLICY IF EXISTS "Clientes inserem próprias avaliações" ON public.avaliacoes;
CREATE POLICY "Clientes inserem próprias avaliações" ON public.avaliacoes FOR INSERT WITH CHECK (auth.uid() = cliente_id);

DROP POLICY IF EXISTS "Clientes atualizam próprias avaliações" ON public.avaliacoes;
CREATE POLICY "Clientes atualizam próprias avaliações" ON public.avaliacoes FOR UPDATE USING (auth.uid() = cliente_id);

-- Políticas de BLOQUEIOS DE AGENDA
DROP POLICY IF EXISTS "Bloqueios visíveis para todos" ON public.bloqueios_agenda;
CREATE POLICY "Bloqueios visíveis para todos" ON public.bloqueios_agenda FOR SELECT USING (true);

DROP POLICY IF EXISTS "Admins gerenciam bloqueios" ON public.bloqueios_agenda;
CREATE POLICY "Admins gerenciam bloqueios" ON public.bloqueios_agenda FOR ALL TO authenticated USING (public.is_admin());

DROP POLICY IF EXISTS "Profissional gerencia próprios bloqueios" ON public.bloqueios_agenda;
CREATE POLICY "Profissional gerencia próprios bloqueios" ON public.bloqueios_agenda
    FOR ALL TO authenticated
    USING (auth.uid() = profissional_id)
    WITH CHECK (auth.uid() = profissional_id);

-- Políticas de CONFIGURAÇÕES DA CLÍNICA
DROP POLICY IF EXISTS "Configurações visíveis para todos" ON public.configuracoes_clinica;
CREATE POLICY "Configurações visíveis para todos" ON public.configuracoes_clinica FOR SELECT USING (true);

DROP POLICY IF EXISTS "Admins gerenciam configurações" ON public.configuracoes_clinica;
CREATE POLICY "Admins gerenciam configurações" ON public.configuracoes_clinica FOR ALL TO authenticated USING (public.is_admin());

-- Políticas de LOGS_ADMIN
DROP POLICY IF EXISTS "Logs visíveis apenas para admins" ON public.logs_admin;
CREATE POLICY "Logs visíveis apenas para admins" ON public.logs_admin FOR SELECT TO authenticated USING (public.is_admin());

DROP POLICY IF EXISTS "Admins inserem logs" ON public.logs_admin;
CREATE POLICY "Admins inserem logs" ON public.logs_admin FOR INSERT TO authenticated WITH CHECK (public.is_admin());

-- Políticas de CAIXAS
DROP POLICY IF EXISTS "Admins podem gerenciar caixas" ON public.caixas;
CREATE POLICY "Admins podem gerenciar caixas" ON public.caixas 
    FOR ALL TO authenticated USING (public.is_admin());

DROP POLICY IF EXISTS "Vendedores podem ver caixas abertos" ON public.caixas;
CREATE POLICY "Vendedores podem ver caixas abertos" ON public.caixas 
    FOR SELECT TO authenticated USING (status = 'aberto');

-- Políticas de CONTAS
ALTER TABLE public.contas ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Usuários autenticados veem contas" ON public.contas;
CREATE POLICY "Usuários autenticados veem contas" ON public.contas FOR SELECT TO authenticated USING (true);
DROP POLICY IF EXISTS "Usuários autenticados inserem contas" ON public.contas;
CREATE POLICY "Usuários autenticados inserem contas" ON public.contas FOR INSERT TO authenticated WITH CHECK (true);
DROP POLICY IF EXISTS "Admins gerenciam contas" ON public.contas;
CREATE POLICY "Admins gerenciam contas" ON public.contas FOR ALL TO authenticated USING (public.is_admin());

-- Políticas de DASHBOARD_ATIVIDADES (Permitir logs automáticos)
ALTER TABLE public.dashboard_atividades ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Autenticados veem atividades" ON public.dashboard_atividades;
CREATE POLICY "Autenticados veem atividades" ON public.dashboard_atividades FOR SELECT TO authenticated USING (true);
DROP POLICY IF EXISTS "Autenticados inserem atividades" ON public.dashboard_atividades;
CREATE POLICY "Autenticados inserem atividades" ON public.dashboard_atividades FOR INSERT TO authenticated WITH CHECK (true);

-- Políticas de PRODUTOS
DROP POLICY IF EXISTS "Produtos visíveis para todos" ON public.produtos;
CREATE POLICY "Produtos visíveis para todos" ON public.produtos FOR SELECT USING (true);

DROP POLICY IF EXISTS "Admins gerenciam produtos" ON public.produtos;
CREATE POLICY "Admins gerenciam produtos" ON public.produtos FOR ALL TO authenticated USING (is_admin());

-- Políticas de ESTOQUE

-- Políticas de VENDAS_PRODUTOS
DROP POLICY IF EXISTS "Admins veem vendas" ON public.vendas_produtos;
DROP POLICY IF EXISTS "Admins gerenciam vendas" ON public.vendas_produtos;
DROP POLICY IF EXISTS "Clientes podem ver suas próprias compras" ON public.vendas_produtos;

CREATE POLICY "Clientes podem ver suas próprias compras"
ON public.vendas_produtos
FOR SELECT
TO authenticated
USING (
    (auth.uid() = cliente_id) OR 
    (is_admin() OR is_profissional())
);

CREATE POLICY "Admins gerenciam vendas" ON public.vendas_produtos FOR ALL TO authenticated USING (is_admin());

-- Políticas de DASHBOARD
DROP POLICY IF EXISTS "Admins veem atividades" ON public.dashboard_atividades;
CREATE POLICY "Admins veem atividades" ON public.dashboard_atividades FOR SELECT TO authenticated USING (is_admin());

DROP POLICY IF EXISTS "Admins gerenciam atividades" ON public.dashboard_atividades;
CREATE POLICY "Admins gerenciam atividades" ON public.dashboard_atividades FOR ALL TO authenticated USING (is_admin());

-- Políticas para CAIXAS
DROP POLICY IF EXISTS "Admins gerenciam caixas" ON public.caixas;
CREATE POLICY "Admins gerenciam caixas" ON public.caixas FOR ALL TO authenticated USING (is_admin());

DROP POLICY IF EXISTS "Profissionais veem caixas abertos" ON public.caixas;
CREATE POLICY "Profissionais veem caixas abertos" ON public.caixas FOR SELECT TO authenticated USING (status = 'aberto');

-- Políticas para HORARIOS_CLINICA
DROP POLICY IF EXISTS "Todos veem horarios da clinica" ON public.horarios_clinica;
CREATE POLICY "Todos veem horarios da clinica" ON public.horarios_clinica FOR SELECT USING (true);

DROP POLICY IF EXISTS "Admins gerenciam horarios da clinica" ON public.horarios_clinica;
CREATE POLICY "Admins gerenciam horarios da clinica" ON public.horarios_clinica FOR ALL TO authenticated USING (is_admin());

-- Políticas para HORARIOS_TRABALHO_PROFISSIONAL
DROP POLICY IF EXISTS "Todos veem horarios de trabalho" ON public.horarios_trabalho_profissional;
CREATE POLICY "Todos veem horarios de trabalho" ON public.horarios_trabalho_profissional FOR SELECT USING (true);

DROP POLICY IF EXISTS "Profissionais/Admins gerenciam horarios de trabalho" ON public.horarios_trabalho_profissional;
CREATE POLICY "Profissionais/Admins gerenciam horarios de trabalho" ON public.horarios_trabalho_profissional FOR ALL TO authenticated 
USING (auth.uid() = profissional_id OR is_admin());

-- --------------------------------------------------------
-- 4. AUTOMAÇÃO (TRIGGERS)
-- --------------------------------------------------------

-- A. DISPONIBILIDADE PADRÃO (Seg-Sex 08-20h, Sáb 08-13h)
CREATE OR REPLACE FUNCTION public.fn_inserir_disponibilidade_padrao()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.tipo = 'profissional' THEN
        -- Segunda a Sexta (1-5)
        INSERT INTO public.disponibilidade_profissional (profissional_id, dia_semana, hora_inicio, hora_fim)
        SELECT NEW.id, d, '08:00:00', '20:00:00'
        FROM generate_series(1, 5) d
        ON CONFLICT (profissional_id, dia_semana, hora_inicio) DO NOTHING;
        
        -- Sábado (6)
        INSERT INTO public.disponibilidade_profissional (profissional_id, dia_semana, hora_inicio, hora_fim)
        VALUES (NEW.id, 6, '08:00:00', '13:00:00')
        ON CONFLICT (profissional_id, dia_semana, hora_inicio) DO NOTHING;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_disponibilidade_padrao ON public.perfis;
CREATE TRIGGER trg_disponibilidade_padrao 
AFTER INSERT OR UPDATE ON public.perfis 
FOR EACH ROW EXECUTE FUNCTION public.fn_inserir_disponibilidade_padrao();

-- B. NOTIFICAÇÕES DE AGENDAMENTO
CREATE OR REPLACE FUNCTION public.fn_gerar_notificacao_agendamento()
RETURNS TRIGGER AS $$
DECLARE
    v_servico_nome TEXT;
    v_data_formatada TEXT;
BEGIN
    SELECT nome INTO v_servico_nome FROM public.servicos WHERE id = NEW.servico_id;
    v_data_formatada := to_char(NEW.data_hora AT TIME ZONE 'America/Sao_Paulo', 'DD/MM "às" HH24:mi');

    IF (TG_OP = 'INSERT') THEN
        INSERT INTO public.notificacoes (user_id, titulo, mensagem, tipo)
        VALUES (NEW.cliente_id, 'Novo Agendamento', 'Seu agendamento de ' || v_servico_nome || ' para ' || v_data_formatada || ' foi realizado.', 'agendamento');
    ELSIF (TG_OP = 'UPDATE') THEN
        IF (OLD.data_hora IS DISTINCT FROM NEW.data_hora) THEN
            INSERT INTO public.notificacoes (user_id, titulo, mensagem, tipo)
            VALUES (NEW.cliente_id, 'Horário Alterado', 'Seu agendamento de ' || v_servico_nome || ' foi movido para ' || v_data_formatada || '.', 'reagendamento');
        END IF;

        IF (OLD.status IS DISTINCT FROM NEW.status) THEN
            -- Alunos e Professional notificações para Cancelamento e No-Show
            IF (NEW.status = 'cancelado') THEN
                INSERT INTO public.notificacoes (user_id, titulo, mensagem, tipo)
                VALUES (NEW.cliente_id, 'Agendamento Cancelado', 'Seu agendamento de ' || v_servico_nome || ' foi cancelado.', 'cancelamento');
                
                -- Notifica Admin e Profissional
                INSERT INTO public.notificacoes (user_id, titulo, mensagem, tipo)
                SELECT id, 'Cancelamento', 'O agendamento de ' || v_servico_nome || ' foi cancelado.', 'admin_alerta'
                FROM public.perfis WHERE (tipo = 'admin' OR id = NEW.profissional_id);
            ELSIF (NEW.status = 'no_show') THEN
                INSERT INTO public.notificacoes (user_id, titulo, mensagem, tipo)
                VALUES (NEW.cliente_id, 'Não Comparecimento', 'Seu agendamento de ' || v_servico_nome || ' foi registrado como não comparecido.', 'no_show');
                
                -- Notifica Admin e Profissional
                INSERT INTO public.notificacoes (user_id, titulo, mensagem, tipo)
                SELECT id, 'Alerta: No-show', 'O cliente não compareceu ao agendamento de ' || v_servico_nome || '.', 'admin_alerta'
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

-- Trigger para Notificar Mudança de Agenda do Profissional
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
        v_titulo := 'Alteração de Horário Semanal';
        v_mensagem := v_autor_nome || ' alterou o horário de trabalho de ' || COALESCE(v_prof_nome, 'um profissional') || ' (Dia ' || NEW.dia_semana || ').';
        IF NEW.fechado THEN v_mensagem := v_mensagem || ' (Marcado como FECHADO)'; END IF;
    ELSIF TG_TABLE_NAME = 'horarios_almoco_profissional' THEN
        SELECT nome_completo INTO v_prof_nome FROM public.perfis WHERE id = NEW.profissional_id;
        v_titulo := 'Alteração de Horário de Almoço';
        v_mensagem := v_autor_nome || ' alterou o horário de almoço de ' || COALESCE(v_prof_nome, 'um profissional') || ' (Dia ' || NEW.dia_semana || ').';
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


-- Garantir que os triggers não existam antes de criar
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

-- Serviços
INSERT INTO servicos (id, nome, descricao, preco, duracao_minutos, categoria_id, ativo, imagem_url) VALUES
('660e8400-e29b-41d4-a716-446655440002', 'Drenagem Linfática', 'Elimina inchaço e toxinas.', 120.00, 60, '550e8400-e29b-41d4-a716-446655440002', true, 'https://images.unsplash.com/photo-1544161515-4ab6ce6db874?auto=format&fit=crop&q=80&w=800'),
('660e8400-e29b-41d4-a716-446655440004', 'Depilação a Laser', 'Redução permanente de pelos.', 80.00, 20, '550e8400-e29b-41d4-a716-446655440004', true, 'https://images.unsplash.com/photo-1552693673-1bf958298935?auto=format&fit=crop&q=80&w=800')
ON CONFLICT (id) DO NOTHING;

-- Configuração Fixa da Clínica
INSERT INTO public.configuracoes_clinica (nome_comercial, endereco, telefone_fixo, whatsapp, logo_url, mapa_iframe, descricao, taxa_debito, taxa_credito, taxa_credito_parcelado, taxa_pix) VALUES (
  'Clínica Estética Lumiere Premium', 'Av. Paulista, 1000 - CJ 12 - SP', '+55 11 3322-4455', '+55 11 99999-8888', 
  'https://lh3.googleusercontent.com/aida-public/AB6AXuAG6eToNB53GWJOF5DexUJMipxbI4hfAlT5u6s3x4STGZ5qk4T9-1itCJK2VmxQJSBl_Mt87gwqua4rsaIr3j8FhwznYpH3vh-WJ6nPHo9N1zXHQc6U8VyzZtc0b-O7hbsNnkyRnHU2mJB1xOI1E8Zj_ScCgOAPbQ7QXyAGom8g_IX1TR2JRWM6n7_ip7_E5ReUNq40p-robjC7WMTzB1MFdjUqhzflr4sZ9bRRmUu7txtLcS74UOgfnQ2UBuyYeaW5rRpx1hvVgOTv',
  '<iframe src="https://www.google.com/maps/embed?pb=!1m14!1m8!1m3!1d1833.6469150917408!2d-45.8912008!3d-23.1959601!3m2!1i1024!2i768!4f13.1!3m3!1m2!1s0x94cc4bc573d3cedb%3A0x1a06d2ea7c223489!2sEmporium%20da%20Arte!5e0!3m2!1spt-BR!2sbr!4v1775104677491!5m2!1spt-BR!2sbr" width="600" height="450" style="border:0;" allowfullscreen="" loading="lazy" referrerpolicy="no-referrer-when-downgrade"></iframe>',
  'A Clínica Lumiere Premium é referência em tratamentos estéticos de alta performance na região da Paulista. Com uma equipe multidisciplinar e tecnologia de ponta, oferecemos protocolos personalizados para realçar sua beleza natural e promover bem-estar completo, desde limpezas de pele profundas até procedimentos avançados de rejuvenescimento e harmonização.',
  2.50, 3.80, 5.20, 0.00
) ON CONFLICT DO NOTHING;

-- Seed Promoções
INSERT INTO public.promocoes (id, titulo, subtitulo, imagem_url, ordem) VALUES 
('f00e8400-e29b-41d4-a716-446655440001', 'Limpeza de Pele Profunda', '30% de desconto hoje', 'https://images.unsplash.com/photo-1570172619644-dfd03ed5d881?w=800', 0),
('f00e8400-e29b-41d4-a716-446655440002', 'Massagem Relaxante', 'Ganhe uma esfoliação', 'https://images.unsplash.com/photo-1570172619644-dfd03ed5d881?w=800', 1),
('f00e8400-e29b-41d4-a716-446655440003', 'Botox Facial', 'Consulte condições especiais', 'https://images.unsplash.com/photo-1616394584738-fc6e612e71b9?w=800', 2)
ON CONFLICT (id) DO NOTHING;
-- --------------------------------------------------------
-- 6. FIX PARA PROFISSIONAIS JÁ EXISTENTES
-- --------------------------------------------------------

-- Remover disponibilidades antigas para evitar duplicidade
DELETE FROM public.disponibilidade_profissional;

-- Inserir nova disponibilidade padrão para TODOS os profissionais cadastrados
INSERT INTO public.disponibilidade_profissional (profissional_id, dia_semana, hora_inicio, hora_fim)
SELECT p.id, d, '08:00:00', '20:00:00'
FROM perfis p, generate_series(1, 5) d
WHERE p.tipo = 'profissional';


-- --------------------------------------------------------
-- 7. PROMOÇÃO DE ADMINISTRADOR
-- --------------------------------------------------------

-- Comando para garantir que o email 'admin@admin.com' tenha nível de acesso admin
-- Se o usuário já cadastrou no app, este comando dará as permissões necessárias
UPDATE public.perfis 
SET tipo = 'admin' 
WHERE email = 'admin@admin.com';

-- Caso queira criar um perfil fictício direto para testes (sem auth real)
-- INSERT INTO public.perfis (id, nome_completo, email, tipo)
-- VALUES (gen_random_uuid(), 'Administrador do Sistema', 'admin@admin.com', 'admin')
-- ON CONFLICT (email) DO UPDATE SET tipo = 'admin';

-- ========================================================
-- FUNÇÃO ADMINISTRATIVA PARA CRIAÇÃO DE PROFISSIONAIS
-- Permite criar usuários no Auth e Perfis sem deslogar o admin
-- ========================================================

-- 1. Habilitar a extensão pgcrypto (para a função crypt)
CREATE EXTENSION IF NOT EXISTS pgcrypto;

-- 2. Criar a função principal
CREATE OR REPLACE FUNCTION public.registrar_profissional_v2(
    p_email TEXT,
    p_password TEXT,
    p_nome TEXT,
    p_cargo TEXT,
    p_telefone TEXT DEFAULT NULL,
    p_tipo TEXT DEFAULT 'profissional',
    p_avatar_url TEXT DEFAULT NULL,
    p_observacoes TEXT DEFAULT NULL,
    p_ativo BOOLEAN DEFAULT true,
    p_comissao DECIMAL DEFAULT 0
) RETURNS UUID AS $$
DECLARE
    v_user_id UUID;
    v_encrypted_pw TEXT;
BEGIN
    -- Gerar o hash da senha usando o algoritmo do Supabase (bcrypt)
    v_encrypted_pw := crypt(p_password, gen_salt('bf'));

    -- Inserir o usuário na tabela auth.users (ID fixo instance_id para Supabase local/cloud padrão)
    INSERT INTO auth.users (
        instance_id,
        id,
        aud,
        role,
        email,
        encrypted_password,
        email_confirmed_at,
        raw_app_meta_data,
        raw_user_meta_data,
        created_at,
        updated_at,
        confirmation_token,
        email_change,
        email_change_token_new,
        recovery_token
    )
    VALUES (
        '00000000-0000-0000-0000-000000000000',
        gen_random_uuid(),
        'authenticated',
        'authenticated',
        p_email,
        v_encrypted_pw,
        now(),
        '{"provider":"email","providers":["email"]}',
        jsonb_build_object('full_name', p_nome, 'avatar_url', p_avatar_url, 'phone', p_telefone, 'tipo', p_tipo),
        now(),
        now(),
        '',
        '',
        '',
        ''
    ) RETURNING id INTO v_user_id;

    -- Inserir ou atualizar o perfil na tabela perfis (isso evita o erro de duplicidade se houver um trigger automático)
    INSERT INTO public.perfis (id, email, nome_completo, tipo, cargo, avatar_url, telefone, observacoes_internas, ativo, comissao_percentual)
    VALUES (v_user_id, p_email, p_nome, p_tipo, p_cargo, p_avatar_url, p_telefone, p_observacoes, p_ativo, p_comissao)
    ON CONFLICT (id) DO UPDATE SET
        email = EXCLUDED.email,
        nome_completo = EXCLUDED.nome_completo,
        tipo = EXCLUDED.tipo,
        cargo = EXCLUDED.cargo,
        avatar_url = EXCLUDED.avatar_url,
        telefone = EXCLUDED.telefone,
        observacoes_internas = EXCLUDED.observacoes_internas,
        ativo = EXCLUDED.ativo,
        comissao_percentual = EXCLUDED.comissao_percentual;

    RETURN v_user_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Comentário: Esta função deve ser executada como 'postgres' no SQL Editor

-- Garante que o perfil exista e seja ADMIN
INSERT INTO public.perfis (id, nome_completo, email, tipo)
SELECT id, 'Administrador', email, 'admin'
FROM auth.users
WHERE email = 'admin@admin.com'
ON CONFLICT (email) DO UPDATE SET tipo = 'admin';

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
        
        -- Sábado (6)
        INSERT INTO public.disponibilidade_profissional (profissional_id, dia_semana, hora_inicio, hora_fim)
        VALUES (prof.id, 6, '08:00:00', '13:00:00')
        ON CONFLICT (profissional_id, dia_semana, hora_inicio) DO NOTHING;
    END LOOP;
END $$;

-- --------------------------------------------------------
-- SEED: HORÁRIOS DA CLÍNICA E TRABALHO (NOVO SISTEMA)
-- --------------------------------------------------------

-- Seed Horários da Clínica (Padrão)
INSERT INTO public.horarios_clinica (dia_semana, hora_inicio, hora_fim, fechado)
SELECT d, '08:00:00', '19:00:00', false
FROM generate_series(1, 5) d -- Seg a Sex
ON CONFLICT (dia_semana) DO NOTHING;

INSERT INTO public.horarios_clinica (dia_semana, hora_inicio, hora_fim, fechado)
VALUES (6, '08:00:00', '13:00:00', false) -- Sábado
ON CONFLICT (dia_semana) DO NOTHING;

-- Seed Horários de Trabalho dos Profissionais
DO $$
DECLARE
    prof RECORD;
BEGIN
    FOR prof IN SELECT id FROM public.perfis WHERE tipo = 'profissional' LOOP
        -- Seg a Sex
        INSERT INTO public.horarios_trabalho_profissional (profissional_id, dia_semana, hora_inicio, hora_fim, fechado)
        SELECT prof.id, d, '08:00:00', '19:00:00', false
        FROM generate_series(1, 5) d
        ON CONFLICT (profissional_id, dia_semana) DO NOTHING;

        -- Sábado
        INSERT INTO public.horarios_trabalho_profissional (profissional_id, dia_semana, hora_inicio, hora_fim, fechado)
        VALUES (prof.id, 6, '08:00:00', '13:00:00', false)
        ON CONFLICT (profissional_id, dia_semana) DO NOTHING;
        
        -- Almoço Padrão (12:00 - 13:00)
        INSERT INTO public.horarios_almoco_profissional (profissional_id, dia_semana, hora_inicio, hora_fim, ativo)
        SELECT prof.id, d, '12:00:00', '13:00:00', true
        FROM generate_series(1, 6) d
        ON CONFLICT (profissional_id, dia_semana) DO NOTHING;
    END LOOP;
END $$;


-- Criação Automática de Agenda (Para novos profissionais ou atualizados)
CREATE OR REPLACE FUNCTION public.trg_criar_disponibilidade_padrao()
RETURNS TRIGGER AS $$
BEGIN
    -- Se estiver criando ou atualizando para "profissional", injeta a grade de horários
    IF (NEW.tipo = 'profissional') THEN
        -- Segunda a Sexta (1-5)
        INSERT INTO public.disponibilidade_profissional (profissional_id, dia_semana, hora_inicio, hora_fim)
        SELECT NEW.id, d, '08:00:00', '20:00:00'
        FROM generate_series(1, 5) d
        ON CONFLICT (profissional_id, dia_semana, hora_inicio) DO NOTHING;
        
        -- Sábado (6)
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
-- FUNÇÕES DE INATIVAÇÃO E LOGIN
-- --------------------------------------------------------

-- Função para atualizar o último login (deve ser chamada pelo App no login)
CREATE OR REPLACE FUNCTION public.atualizar_ultimo_login(p_user_id UUID)
RETURNS void AS $$
BEGIN
    UPDATE public.perfis 
    SET ultimo_login = timezone('utc'::text, now()),
        ativo = true 
    WHERE id = p_user_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Função para inativar usuários (clientes) sem login por 30 dias
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

-- Função auxiliar para registrar atividades no Dashboard (Padrão)
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


-- Função auxiliar para notificar todos os administradores
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
-- SISTEMA DE PREVENÇÃO DE CONFLITOS DE AGENDAMENTO
-- Verifica a duração do serviço para evitar horários sobrepostos
-- ========================================================

-- Remover o índice antigo se ele ainda existir, pois a trigger fará um trabalho mais completo
DROP INDEX IF EXISTS public.idx_agendamentos_profissional_horario;

CREATE OR REPLACE FUNCTION public.verificar_disponibilidade_agendamento()
RETURNS TRIGGER AS $$
DECLARE
    v_nova_duracao INT;
    v_novo_fim TIMESTAMP WITH TIME ZONE;
    v_conflito INT;
BEGIN
    -- Se o agendamento foi cancelado ou ausente, não bloqueia o horário
    IF (NEW.status IN ('cancelado', 'ausente')) THEN
        RETURN NEW;
    END IF;

    -- Obtém a duração do serviço que está sendo agendado
    SELECT duracao_minutos INTO v_nova_duracao 
    FROM public.servicos 
    WHERE id = NEW.servico_id;
    
    -- Se não encontrar duração, presume 60 minutos como padrão de segurança
    IF v_nova_duracao IS NULL THEN
        v_nova_duracao := 60;
    END IF;

    -- Calcula a hora final do novo agendamento
    v_novo_fim := NEW.data_hora + (v_nova_duracao || ' minutes')::interval;

    -- Verifica se existe algum agendamento conflitante para o mesmo profissional
    -- Lógica de Intersecção de Períodos: (InicioA < FimB) AND (FimA > InicioB)
    SELECT COUNT(*) INTO v_conflito
    FROM public.agendamentos a
    JOIN public.servicos s ON a.servico_id = s.id
    WHERE a.profissional_id = NEW.profissional_id
      AND a.id != COALESCE(NEW.id, '00000000-0000-0000-0000-000000000000'::uuid)
      AND a.status NOT IN ('cancelado', 'ausente')
      AND a.data_hora < v_novo_fim
      AND (a.data_hora + (COALESCE(s.duracao_minutos, 60) || ' minutes')::interval) > NEW.data_hora;

    IF v_conflito > 0 THEN
        RAISE EXCEPTION 'Horário indisponível. O período selecionado (considerando a duração do serviço) entra em conflito com outro agendamento existente deste profissional.';
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trg_check_disponibilidade ON public.agendamentos;
CREATE TRIGGER trg_check_disponibilidade
BEFORE INSERT OR UPDATE ON public.agendamentos
FOR EACH ROW EXECUTE FUNCTION public.verificar_disponibilidade_agendamento();


-- ========================================================
-- RPC PARA BUSCAR OCUPAÇÃO DA CLÍNICA (BYPASS RLS)
-- Esta função permite que o app verifique quais horários estão ocupados
-- sem expor detalhes sensíveis dos agendamentos de outros usuários.
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

-- Garante que usuários autenticados possam executar a função
GRANT EXECUTE ON FUNCTION public.get_clinic_occupied_slots(TIMESTAMP WITH TIME ZONE, TIMESTAMP WITH TIME ZONE) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_clinic_occupied_slots(TIMESTAMP WITH TIME ZONE, TIMESTAMP WITH TIME ZONE) TO anon;


-- ========================================================
-- ATUALIZAÇÃO DO SISTEMA DE NOTIFICAÇÕES (DASHBOARD)
-- Execute este script no SQL Editor do Supabase
-- ========================================================

-- 1. Adiciona a coluna is_lida caso ela não exista
ALTER TABLE public.dashboard_atividades 
ADD COLUMN IF NOT EXISTS is_lida BOOLEAN DEFAULT FALSE;

-- 2. Correção de Segurança (RLS): Permite que o app atualize a coluna is_lida
DROP POLICY IF EXISTS "Permitir update para admins" ON public.dashboard_atividades;
CREATE POLICY "Permitir update para admins" 
ON public.dashboard_atividades 
FOR UPDATE TO authenticated 
USING (is_admin())
WITH CHECK (is_admin());

-- 2.1 Adição de Coluna Retroativa (Caso o banco já exista)
ALTER TABLE public.dashboard_atividades ADD COLUMN IF NOT EXISTS user_id UUID REFERENCES public.perfis(id) ON DELETE SET NULL;

-- 3. Correção de Segurança (RLS): Permite inserção de novos logs pelo Dart
DROP POLICY IF EXISTS "Permitir insert para admins" ON public.dashboard_atividades;
CREATE POLICY "Permitir insert para admins" 
ON public.dashboard_atividades 
FOR INSERT TO authenticated 
WITH CHECK (is_admin());

-- ========================================================
-- ATUALIZAÇÃO REVOLUCIONARIA DE NOTIFICAÇÕES GERAIS (DASHBOARD)
-- Atualizado para exibir O NOME DE QUEM FEZ A AÇÃO (Autor)
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

    -- Obtém o nome do usuário que disparou a query (Admin, Cliente ou Prof)
    SELECT nome_completo INTO v_autor_nome FROM public.perfis WHERE id = auth.uid();
    
    -- Fallback de segurança se falhar na obtenção
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
            v_prefixo || ' para o dia ' || to_char(NEW.data_hora AT TIME ZONE 'America/Sao_Paulo', 'DD/MM/YYYY') || ' às ' || to_char(NEW.data_hora AT TIME ZONE 'America/Sao_Paulo', 'HH24:MI'),
            jsonb_build_object('appointment_id', NEW.id, 'data', NEW.data_hora, 'Usuário Criação', v_autor_nome)
        );
    ELSIF (TG_OP = 'UPDATE') THEN
        IF (NEW.status = 'cancelado' AND OLD.status != 'cancelado') THEN
             PERFORM public.registrar_atividade_dashboard(
                'agendamento',
                'Agendamento Cancelado',
                v_autor_nome || ' cancelou o agendamento de ' || v_cliente_nome || ' com ' || v_prof_nome || ' para o dia ' || to_char(NEW.data_hora AT TIME ZONE 'America/Sao_Paulo', 'DD/MM/YYYY') || ' às ' || to_char(NEW.data_hora AT TIME ZONE 'America/Sao_Paulo', 'HH24:MI'),
                jsonb_build_object('appointment_id', NEW.id, 'Usuário Alteração', v_autor_nome)
            );
        END IF;
        
        IF (NEW.status = 'concluido' AND OLD.status != 'concluido') THEN
             PERFORM public.registrar_atividade_dashboard(
                'agendamento',
                'Atendimento Concluído',
                v_autor_nome || ' concluiu o atendimento de ' || v_cliente_nome || ' com ' || v_prof_nome || ' no dia ' || to_char(NEW.data_hora AT TIME ZONE 'America/Sao_Paulo', 'DD/MM/YYYY') || ' às ' || to_char(NEW.data_hora AT TIME ZONE 'America/Sao_Paulo', 'HH24:MI'),
                jsonb_build_object('appointment_id', NEW.id, 'Usuário Alteração', v_autor_nome)
            );
        END IF;

        IF (NEW.status = 'confirmado' AND OLD.status != 'confirmado') THEN
            PERFORM public.registrar_atividade_dashboard(
                'agendamento',
                'Agendamento Confirmado',
                v_autor_nome || ' confirmou o agendamento de ' || v_cliente_nome || ' com ' || v_prof_nome || ' para o dia ' || to_char(NEW.data_hora AT TIME ZONE 'America/Sao_Paulo', 'DD/MM/YYYY') || ' às ' || to_char(NEW.data_hora AT TIME ZONE 'America/Sao_Paulo', 'HH24:MI'),
                jsonb_build_object('appointment_id', NEW.id, 'Usuário Alteração', v_autor_nome)
            );
        END IF;

        IF (NEW.status = 'ausente' AND OLD.status != 'ausente') THEN
            PERFORM public.registrar_atividade_dashboard(
                'agendamento',
                'Falta no Agendamento',
                v_autor_nome || ' marcou falta para ' || v_cliente_nome || ' no atendimento com ' || v_prof_nome || ' no dia ' || to_char(NEW.data_hora AT TIME ZONE 'America/Sao_Paulo', 'DD/MM/YYYY') || ' às ' || to_char(NEW.data_hora AT TIME ZONE 'America/Sao_Paulo', 'HH24:MI'),
                jsonb_build_object('appointment_id', NEW.id, 'Usuário Alteração', v_autor_nome)
            );
        END IF;

        -- Pagamento (novo tracker)
        IF (NEW.pago = true AND OLD.pago = false) THEN
            PERFORM public.registrar_atividade_dashboard(
                'financeiro',
                'Pagamento de Agendamento Confirmado',
                v_autor_nome || ' confirmou o recebimento referente ao agendamento de ' || v_cliente_nome || ' (R$ ' || COALESCE(NEW.valor_total, 0) || ')',
                jsonb_build_object('appointment_id', NEW.id, 'valor', NEW.valor_total, 'Usuário Alteração', v_autor_nome)
            );
        END IF;

        -- Reagendamento (se a data mudou)
        IF (NEW.data_hora != OLD.data_hora) THEN
            PERFORM public.registrar_atividade_dashboard(
                'agendamento',
                'Agendamento Reagendado',
                v_autor_nome || ' reagendou o atendimento de ' || v_cliente_nome || ' com ' || v_prof_nome || ' para o dia ' || to_char(NEW.data_hora AT TIME ZONE 'America/Sao_Paulo', 'DD/MM/YYYY') || ' às ' || to_char(NEW.data_hora AT TIME ZONE 'America/Sao_Paulo', 'HH24:MI'),
                jsonb_build_object('appointment_id', NEW.id, 'old_time', OLD.data_hora, 'new_time', NEW.data_hora, 'Usuário Alteração', v_autor_nome)
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
                jsonb_build_object('perfil_id', NEW.id, 'Usuário Criação', v_autor_nome)
            );
        ELSIF (NEW.tipo = 'profissional') THEN
            PERFORM public.registrar_atividade_dashboard(
                'configuracao',
                'Novo Profissional',
                v_autor_nome || ' registrou o profissional ' || NEW.nome_completo || ' no sistema',
                jsonb_build_object('perfil_id', NEW.id, 'Usuário Criação', v_autor_nome)
            );
            
            -- Sistema de Notificação
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
                jsonb_build_object('perfil_id', NEW.id, 'Usuário Alteração', v_autor_nome)
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


-- 3. TRG: Procedimentos (Serviços) 
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
            jsonb_build_object('servico_id', NEW.id, 'preco', NEW.preco, 'Usuário Criação', v_autor_nome)
        );
    ELSIF (TG_OP = 'DELETE') THEN
        PERFORM public.registrar_atividade_dashboard(
            'configuracao',
            'Procedimento Removido',
            v_autor_nome || ' removeu o procedimento "' || OLD.nome || '"',
            jsonb_build_object('servico_id', OLD.id, 'Usuário Deleção', v_autor_nome)
        );

        -- Notificação direta Admin
        PERFORM public.notificar_admins(
            'Procedimento Removido',
            v_autor_nome || ' deletou o serviço: ' || OLD.nome,
            'sistema'
        );
    END IF;

    -- Notificações de criação e preço para Admin
    IF (TG_OP = 'INSERT') THEN
         PERFORM public.notificar_admins(
            'Novo Procedimento Cadastrado',
            v_autor_nome || ' cadastrou o serviço: ' || NEW.nome || ' (R$ ' || NEW.preco || ')',
            'sistema'
        );
    ELSIF (TG_OP = 'UPDATE' AND NEW.nome = OLD.nome AND NEW.preco != OLD.preco) THEN
         PERFORM public.notificar_admins(
            'Alteração de Preço',
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
            jsonb_build_object('caixa_id', NEW.id, 'usuario_id', NEW.usuario_id, 'Usuário Criação', v_autor_nome)
        );
    ELSIF (TG_OP = 'UPDATE') THEN
        IF (NEW.status = 'fechado' AND OLD.status != 'fechado') THEN
            PERFORM public.registrar_atividade_dashboard(
                'financeiro',
                'Caixa Fechado',
                v_autor_nome || ' fechou o caixa (Saldo Final: R$ ' || COALESCE(NEW.saldo_final_real, 0) || ')',
                jsonb_build_object('caixa_id', NEW.id, 'usuario_id', NEW.usuario_id, 'Usuário Alteração', v_autor_nome)
            );
        END IF;
    END IF;

    -- Notificação Admin on Open/Close
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
        -- Pois a função fn_processar_venda_produto já registra a atividade específica
        IF (NEW.categoria = 'Produtos') THEN
            RETURN NEW;
        END IF;

        IF (NEW.tipo_conta = 'pagar') THEN
            PERFORM public.registrar_atividade_dashboard(
                'financeiro',
                'Conta a Pagar Lançada',
                v_autor_nome || ' lançou nova despesa: ' || NEW.titulo || ' (R$ ' || NEW.valor || ')',
                jsonb_build_object('conta_id', NEW.id, 'tipo', 'pagar', 'Usuário Criação', v_autor_nome)
            );
        ELSE
            PERFORM public.registrar_atividade_dashboard(
                'financeiro',
                'Conta a Receber Lançada',
                v_autor_nome || ' lançou nova receita: ' || NEW.titulo || ' (R$ ' || NEW.valor || ')',
                jsonb_build_object('conta_id', NEW.id, 'tipo', 'receber', 'Usuário Criação', v_autor_nome)
            );
        END IF;
    END IF;

    -- Notificação de despesa para Admin
    IF (TG_OP = 'INSERT' AND NEW.tipo_conta = 'pagar' AND NEW.categoria != 'Produtos') THEN
        PERFORM public.notificar_admins(
            'Nova Despesa Lançada',
            v_autor_nome || ' lançou a conta: ' || NEW.titulo || ' (R$ ' || NEW.valor || ')',
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
            jsonb_build_object('categoria_id', OLD.id, 'Usuário Deleção', v_autor_nome)
        );
        -- Notificação Admin
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

-- 7. TRG: Configurações da Clínica
CREATE OR REPLACE FUNCTION public.fn_notificar_operacao_clinica()
RETURNS TRIGGER AS $$
DECLARE
    v_autor_nome TEXT;
    v_detalhes TEXT := '';
BEGIN
    SELECT nome_completo INTO v_autor_nome FROM public.perfis WHERE id = auth.uid();
    IF v_autor_nome IS NULL THEN v_autor_nome := 'Sistema'; END IF;

    IF (TG_TABLE_NAME = 'configuracoes_clinica') THEN
        -- Verificar taxas de cartão
        IF (NEW.taxa_debito != OLD.taxa_debito) THEN v_detalhes := v_detalhes || ' Taxa Débito: ' || OLD.taxa_debito || '% -> ' || NEW.taxa_debito || '%.'; END IF;
        IF (NEW.taxa_credito != OLD.taxa_credito) THEN v_detalhes := v_detalhes || ' Taxa Crédito: ' || OLD.taxa_credito || '% -> ' || NEW.taxa_credito || '%.'; END IF;
        IF (NEW.taxa_credito_parcelado != OLD.taxa_credito_parcelado) THEN v_detalhes := v_detalhes || ' Taxa Crédito Parcelado: ' || OLD.taxa_credito_parcelado || '% -> ' || NEW.taxa_credito_parcelado || '%.'; END IF;
        IF (NEW.taxa_pix != OLD.taxa_pix) THEN v_detalhes := v_detalhes || ' Taxa PIX: ' || OLD.taxa_pix || '% -> ' || NEW.taxa_pix || '%.'; END IF;

        IF v_detalhes != '' THEN
            PERFORM public.registrar_atividade_dashboard('configuracao', 'Alteração de Taxas', v_autor_nome || ' alterou as taxas: ' || v_detalhes, jsonb_build_object('old', OLD, 'new', NEW), auth.uid());
            PERFORM public.notificar_admins('Alteração de Taxas', v_autor_nome || ' alterou as taxas de cartão/pix.' || v_detalhes, 'configuracao');
        ELSE
            PERFORM public.registrar_atividade_dashboard('configuracao', 'Configurações Alteradas', v_autor_nome || ' atualizou as configurações da clínica.', jsonb_build_object('old', OLD, 'new', NEW), auth.uid());
            PERFORM public.notificar_admins('Alteração em Informações da Clínica', v_autor_nome || ' atualizou as configurações básicas da clínica.', 'sistema');
        END IF;
    ELSIF (TG_TABLE_NAME = 'horarios_clinica') THEN
        PERFORM public.registrar_atividade_dashboard('configuracao', 'Horário de Funcionamento', v_autor_nome || ' alterou o horário de funcionamento da clínica.', jsonb_build_object('dia', NEW.dia_semana, 'fechado', NEW.fechado), auth.uid());
        PERFORM public.notificar_admins('Alteração em Horário de Funcionamento', v_autor_nome || ' alterou o horário de funcionamento da clínica.', 'sistema');
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
        v_msg := v_autor_nome || ' excluiu a promoção: "' || v_item_nome || '".';
        PERFORM public.registrar_atividade_dashboard('configuracao', 'Promoção Excluída', v_msg, jsonb_build_object('id', OLD.id), auth.uid());
        PERFORM public.notificar_admins('Promoção Removida', v_msg, 'sistema');
        RETURN OLD;
    END IF;

    v_item_nome := NEW.titulo;
    IF (TG_OP = 'INSERT') THEN
        v_msg := v_autor_nome || ' criou a promoção: "' || v_item_nome || '".';
        PERFORM public.registrar_atividade_dashboard('configuracao', 'Nova Promoção', v_msg, jsonb_build_object('id', NEW.id), auth.uid());
        PERFORM public.notificar_admins('Nova Promoção', v_msg, 'sistema');
    ELSIF (TG_OP = 'UPDATE') THEN
        v_msg := v_autor_nome || ' editou a promoção: "' || v_item_nome || '".';
        PERFORM public.registrar_atividade_dashboard('configuracao', 'Promoção Editada', v_msg, jsonb_build_object('id', NEW.id), auth.uid());
        PERFORM public.notificar_admins('Promoção Alterada', v_msg, 'sistema');
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

-- Garantir que a coluna data_vencimento existe (caso a tabela já tenha sido criada anteriormente)
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
    valor_comissao_bruta DECIMAL(10,2),
    valor_comissao_liquida DECIMAL(10,2),
    criado_em TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- Habilitar RLS
ALTER TABLE public.produtos ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.vendas_produtos ENABLE ROW LEVEL SECURITY;

-- Políticas para PRODUTOS
DROP POLICY IF EXISTS "Admins gerenciam produtos" ON public.produtos;
CREATE POLICY "Admins gerenciam produtos" ON public.produtos FOR ALL TO authenticated USING (
    is_admin()
);

DROP POLICY IF EXISTS "Todos veem produtos ativos" ON public.produtos;
CREATE POLICY "Todos veem produtos ativos" ON public.produtos FOR SELECT USING (ativo = true);

-- Políticas para VENDAS_PRODUTOS
DROP POLICY IF EXISTS "Admins veem todas as vendas" ON public.vendas_produtos;
CREATE POLICY "Admins veem todas as vendas" ON public.vendas_produtos FOR SELECT TO authenticated USING (
    is_admin()
);

DROP POLICY IF EXISTS "Permitir inserção de vendas" ON public.vendas_produtos;
CREATE POLICY "Permitir inserção de vendas" ON public.vendas_produtos FOR INSERT TO authenticated WITH CHECK (true);

-- Gatilhos e Limpeza para Vendas de Produtos
DROP TRIGGER IF EXISTS trg_venda_produto_processamento ON public.vendas_produtos;
DROP TRIGGER IF EXISTS trg_vendas_estoque ON public.vendas_produtos;
DROP TRIGGER IF EXISTS trg_processar_venda_produto ON public.vendas_produtos;


-- ========================================================
-- MIGRATION: REFINAMENTO DE PRODUTOS (V2)
-- ========================================================

-- 1. TABELA DE HISTÓRICO DE ESTOQUE
CREATE TABLE IF NOT EXISTS public.historico_estoque (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    produto_id UUID NOT NULL REFERENCES public.produtos(id) ON DELETE CASCADE,
    tipo_movimentacao TEXT NOT NULL CHECK (tipo_movimentacao IN ('entrada', 'saida', 'ajuste')),
    quantidade INT NOT NULL,
    motivo TEXT, -- Ex: 'Venda #123', 'Ajuste Manual', 'Nova Remessa'
    criado_por UUID REFERENCES public.perfis(id),
    criado_em TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- 2. SEGURANÇA (RLS)
ALTER TABLE public.historico_estoque ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Admins veem historico completo" ON public.historico_estoque;
DROP POLICY IF EXISTS "Apenas admin e profissionais veem histórico" ON public.historico_estoque;

CREATE POLICY "Apenas admin e profissionais veem histórico"
ON public.historico_estoque
FOR SELECT
TO authenticated
USING (
    is_admin() OR is_profissional()
);

-- 3. ATUALIZAR FUNÇÃO DE VENDA PARA REGISTRAR NO HISTÓRICO
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

    -- 3. Atualizar a própria venda com a comissão calculada
    UPDATE public.vendas_produtos 
    SET valor_comissao_bruta = v_comissao_valor,
        valor_comissao_liquida = v_net_valor
    WHERE id = NEW.id;

    -- 4. DECREMENTAR ESTOQUE
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
        metadata,
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
        jsonb_build_object('venda_id', NEW.id, 'tipo', 'venda_produto', 'produto_id', NEW.produto_id),
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

    -- 8. Alerta de Estoque Baixo
    IF (v_estoque_atual - NEW.quantidade <= v_estoque_minimo) THEN
        BEGIN
            PERFORM public.notificar_admins(
                'Estoque Baixo!',
                'O produto ' || v_produto_nome || ' atingiu o estoque crítico (' || (v_estoque_atual - NEW.quantidade) || ' unidades).',
                'estoque_baixo'
            );
        EXCEPTION WHEN OTHERS THEN NULL;
        END;
    END IF;


    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Gatilho para processar venda de produto automaticamente
DROP TRIGGER IF EXISTS trg_venda_produto_processamento ON public.vendas_produtos;
CREATE TRIGGER trg_venda_produto_processamento
AFTER INSERT ON public.vendas_produtos
FOR EACH ROW
EXECUTE FUNCTION public.fn_processar_venda_produto();

-- Função para processar pagamento de agendamento no financeiro
CREATE OR REPLACE FUNCTION public.fn_processar_venda_agendamento()
RETURNS TRIGGER AS $$
DECLARE
    v_cliente_nome TEXT;
    v_servico_nome TEXT;
BEGIN
    -- Verificar se o agendamento foi pago ou concluído agora
    IF (NEW.pago = true AND (OLD.pago = false OR OLD.pago IS NULL)) OR 
       (NEW.status = 'concluido' AND (OLD.status != 'concluido' OR OLD.status IS NULL)) THEN
       
       -- EVITAR DUPLICIDADE: Verificar se já existe uma conta para este agendamento
       IF EXISTS (
           SELECT 1 FROM public.contas 
           WHERE categoria = 'procedimento' 
           AND (metadata->>'agendamento_id') = NEW.id::text
       ) THEN
           RETURN NEW;
       END IF;

        -- Buscar nomes para o título
        SELECT nome_completo INTO v_cliente_nome FROM public.perfis WHERE id = NEW.cliente_id;
        SELECT nome INTO v_servico_nome FROM public.servicos WHERE id = NEW.servico_id;

        -- Inserir na tabela de contas (o repositório do caixa lê desta tabela)
        INSERT INTO public.contas (
            caixa_id,
            titulo,
            descricao,
            valor,
            tipo_conta,
            categoria,
            forma_pagamento,
            status_pagamento,
            data_vencimento,
            data_pagamento,
            cliente_id,
            metadata
        ) VALUES (
            NEW.caixa_id,
            'Atendimento: ' || COALESCE(v_servico_nome, 'Serviço'),
            'Pagamento de agendamento - Cliente: ' || COALESCE(v_cliente_nome, 'N/A'),
            NEW.valor_total,
            'receber',
            'procedimento',
            COALESCE(NEW.forma_pagamento, 'outro'),
            'pago',
            COALESCE(NEW.data_pagamento, CURRENT_TIMESTAMP),
            COALESCE(NEW.data_pagamento, CURRENT_TIMESTAMP),
            NEW.cliente_id,
            jsonb_build_object('agendamento_id', NEW.id, 'origem', 'agendamento_trigger')
        );

        -- Registrar atividade no dashboard
        INSERT INTO public.dashboard_atividades (
            tipo,
            titulo,
            descricao,
            metadata,
            user_id
        ) VALUES (
            'pagamento',
            'Pagamento Recebido',
            'Recebido R$ ' || NEW.valor_total || ' de ' || COALESCE(v_cliente_nome, 'Cliente') || ' (' || COALESCE(v_servico_nome, 'Serviço') || ')',
            jsonb_build_object('agendamento_id', NEW.id, 'valor', NEW.valor_total, 'metodo', NEW.forma_pagamento),
            NEW.profissional_id
        );
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Gatilho para processar financeiro de agendamentos
DROP TRIGGER IF EXISTS trg_venda_agendamento_financeiro ON public.agendamentos;
CREATE TRIGGER trg_venda_agendamento_financeiro
AFTER UPDATE ON public.agendamentos
FOR EACH ROW
WHEN (NEW.pago = true AND (OLD.pago = false OR OLD.pago IS NULL))
EXECUTE FUNCTION public.fn_processar_venda_agendamento();

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
    -- Se for uma atualização e o estoque aumentou
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

    -- Notificações de Produto
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

        -- Alerta de Vencimento Próximo (menos de 30 dias)
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

-- Atualizar a trigger para disparar no INSERT também
DROP TRIGGER IF EXISTS trg_log_estoque_ajuste ON public.produtos;
CREATE TRIGGER trg_log_estoque_ajuste
AFTER INSERT OR UPDATE OF estoque_atual ON public.produtos
FOR EACH ROW 
EXECUTE FUNCTION public.fn_log_ajuste_estoque();

-- 1. CRIAÇÃO DO BUCKET DE PRODUTOS (CASO NÃO EXISTA)
-- Obs: O bucket precisa ser público para que getPublicUrl funcione sem assinatura.
INSERT INTO storage.buckets (id, name, public)
VALUES ('produtos', 'produtos', true)
ON CONFLICT (id) DO NOTHING;

-- 2. POLÍTICAS DE ACESSO AO STORAGE

-- Permite que qualquer pessoa (anon/autenticado) veja as imagens dos produtos
DROP POLICY IF EXISTS "Produtos: Imagens Públicas" ON storage.objects;
CREATE POLICY "Produtos: Imagens Públicas"
ON storage.objects FOR SELECT
USING (bucket_id = 'produtos');

-- Permite que administradores autenticados façam upload de imagens
DROP POLICY IF EXISTS "Produtos: Admin Upload" ON storage.objects;
CREATE POLICY "Produtos: Admin Upload"
ON storage.objects FOR INSERT
WITH CHECK (
  bucket_id = 'produtos' 
  AND auth.role() = 'authenticated'
);

-- Permite que administradores autenticados atualizem suas imagens
DROP POLICY IF EXISTS "Produtos: Admin Update" ON storage.objects;
CREATE POLICY "Produtos: Admin Update"
ON storage.objects FOR UPDATE
WITH CHECK (
  bucket_id = 'produtos' 
  AND auth.role() = 'authenticated'
);

-- Permite que administradores autenticados removam imagens
DROP POLICY IF EXISTS "Produtos: Admin Delete" ON storage.objects;
CREATE POLICY "Produtos: Admin Delete"
ON storage.objects FOR DELETE
USING (
  bucket_id = 'produtos' 
  AND auth.role() = 'authenticated'
);
    
-- ============================================================
-- MIGRATION: Adicionar 'no_show' ao status de agendamentos
-- Execute este script no SQL Editor do Supabase
-- ============================================================

-- 1. Remove a constraint antiga
ALTER TABLE public.agendamentos
  DROP CONSTRAINT IF EXISTS agendamentos_status_check;

-- 2. Recria a constraint com 'no_show' incluído
ALTER TABLE public.agendamentos
  ADD CONSTRAINT agendamentos_status_check
  CHECK (status IN ('pendente', 'confirmado', 'cancelado', 'concluido', 'ausente', 'no_show'));

-- 3. Adicionar coluna 'criado_por' em bloqueios_agenda para distinguir Admin/Profissional
DO $$ 
BEGIN 
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='bloqueios_agenda' AND column_name='criado_por') THEN
        ALTER TABLE public.bloqueios_agenda ADD COLUMN criado_por UUID REFERENCES public.perfis(id);
    END IF;
END $$;

-- 4. Função para notificar Admin sobre No-Show
CREATE OR REPLACE FUNCTION public.fn_notificar_admin_no_show()
RETURNS TRIGGER AS $$
DECLARE
    v_admin_id UUID;
    v_cliente_nome TEXT;
    v_servico_nome TEXT;
    v_profissional_nome TEXT;
BEGIN
    IF (NEW.status = 'no_show' AND (OLD.status IS NULL OR OLD.status <> 'no_show')) THEN
        -- Buscar nomes para a mensagem
        SELECT nome_completo INTO v_cliente_nome FROM public.perfis WHERE id = NEW.cliente_id;
        SELECT nome INTO v_servico_nome FROM public.servicos WHERE id = NEW.servico_id;
        SELECT nome_completo INTO v_profissional_nome FROM public.perfis WHERE id = NEW.profissional_id;

        -- Notificar todos os admins
        FOR v_admin_id IN SELECT id FROM public.perfis WHERE tipo = 'admin' LOOP
            INSERT INTO public.notificacoes (user_id, titulo, mensagem, tipo, metadata)
            VALUES (
                v_admin_id,
                'Cliente não compareceu (No-Show)',
                'O cliente ' || COALESCE(v_cliente_nome, 'Desconhecido') || ' não compareceu ao agendamento de ' || COALESCE(v_servico_nome, 'Serviço') || ' com ' || COALESCE(v_profissional_nome, 'Profissional') || ' em ' || TO_CHAR(NEW.data, 'DD/MM/YYYY') || ' às ' || TO_CHAR(NEW.hora_inicio, 'HH24:MI') || '.',
                'agendamento',
                jsonb_build_object('agendamento_id', NEW.id, 'status', 'no_show')
            );
        END LOOP;
    END IF;
RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;


DROP TRIGGER IF EXISTS trg_notificar_admin_no_show ON public.agendamentos;
CREATE TRIGGER trg_notificar_admin_no_show
AFTER UPDATE ON public.agendamentos
FOR EACH ROW EXECUTE FUNCTION public.fn_notificar_admin_no_show();

-- 5. Função para notificar Mudanças na Agenda (Bloqueios e Almoço)
CREATE OR REPLACE FUNCTION public.fn_notificar_mudanca_agenda()
RETURNS TRIGGER AS $$
DECLARE
    v_prof_nome TEXT;
    v_autor_nome TEXT;
    v_periodo TEXT;
    v_detalhes_admin TEXT;
BEGIN
    -- Obter nome do profissional alvo (ou clínica)
    IF NEW.profissional_id IS NOT NULL THEN
        SELECT nome_completo INTO v_prof_nome FROM public.perfis WHERE id = NEW.profissional_id;
    ELSE
        v_prof_nome := 'BLOQUEIO GLOBAL (CLÍNICA)';
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

    -- Formatar período (usando CONCAT para segurança contra NULLs)
    IF COALESCE(NEW.dia_todo, true) THEN
        v_periodo := 'Dia Todo';
    ELSE
        v_periodo := CONCAT(TO_CHAR(NEW.hora_inicio, 'HH24:MI'), ' às ', TO_CHAR(NEW.hora_fim, 'HH24:MI'));
    END IF;

    IF (TG_TABLE_NAME = 'bloqueios_agenda') THEN
        -- 1. NOTIFICAÇÃO PARA ADMINS
        v_detalhes_admin := CONCAT(
            'DETALHES DO BLOQUEIO',
            E'\nProfissional (que realizou o bloqueio): ', v_autor_nome,
            E'\nData: ', TO_CHAR(NEW.data, 'DD/MM/YYYY'),
            E'\nHora: ', v_periodo,
            E'\nMotivo: ', COALESCE(NEW.motivo, 'Não informado')
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

        -- 2. NOTIFICAÇÃO PARA O PROFISSIONAL (Apenas se for um profissional específico)
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
        v_detalhes_admin := COALESCE(v_prof_nome, 'Profissional') || ' alterou o almoço (' || 
                            CASE NEW.dia_semana 
                            WHEN 0 THEN 'Dom' WHEN 1 THEN 'Seg' WHEN 2 THEN 'Ter' 
                            WHEN 3 THEN 'Qua' WHEN 4 THEN 'Qui' WHEN 5 THEN 'Sex' WHEN 6 THEN 'Sáb' END ||
                            ') para ' || TO_CHAR(NEW.hora_inicio, 'HH24:MI') || ' - ' || TO_CHAR(NEW.hora_fim, 'HH24:MI');

        PERFORM public.notificar_admins('Alteração de Intervalo - ' || COALESCE(v_prof_nome, 'Agenda'), v_detalhes_admin, 'agenda');
        
        -- Notificar profissional
        IF NEW.profissional_id IS NOT NULL THEN
            INSERT INTO public.notificacoes (user_id, titulo, mensagem, tipo)
            VALUES (
                NEW.profissional_id,
                'Intervalo Alterado',
                'Seu horário de almoço foi alterado para ' || TO_CHAR(NEW.hora_inicio, 'HH24:MI') || ' às ' || TO_CHAR(NEW.hora_fim, 'HH24:MI') || '.',
                'agenda'
            );
        END IF;
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Triggers para Bloqueios e Almoço
DROP TRIGGER IF EXISTS trg_notificar_bloqueio ON public.bloqueios_agenda;
CREATE TRIGGER trg_notificar_bloqueio
AFTER INSERT ON public.bloqueios_agenda
FOR EACH ROW EXECUTE FUNCTION public.fn_notificar_mudanca_agenda();

DROP TRIGGER IF EXISTS trg_notificar_almoco ON public.horarios_almoco_profissional;
CREATE TRIGGER trg_notificar_almoco
AFTER UPDATE ON public.horarios_almoco_profissional
FOR EACH ROW EXECUTE FUNCTION public.fn_notificar_mudanca_agenda();

-- Função para atualizar sessoes de pacotes contratados quando um agendamento é concluído
CREATE OR REPLACE FUNCTION public.fn_atualizar_sessao_pacote()
RETURNS TRIGGER AS $$
BEGIN
    -- Se o agendamento foi marcado como concluído e possui um pacote contratado
    IF (OLD.status != 'concluido' AND NEW.status = 'concluido' AND NEW.pacote_contratado_id IS NOT NULL) THEN
        -- Tentar debitar uma sessão do pacote (incrementar as realizadas)
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
    
    -- Se o agendamento for cancelado/voltar de concluído, talvez estornar a sessão?
    -- No momento apenas decrementamos na conclusão.
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trg_atualizar_pacote ON public.agendamentos;
CREATE TRIGGER trg_atualizar_pacote
AFTER UPDATE ON public.agendamentos
FOR EACH ROW EXECUTE FUNCTION public.fn_atualizar_sessao_pacote();

-- Função RPC para incrementar sessões de pacotes (usada pelo app)
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
-- TRIGGER: Automação de Perfis ao Criar Usuário no Auth
-- --------------------------------------------------------

CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  -- Limpeza de registros órfãos para evitar o erro 500 por conflito de Unique Email
  DELETE FROM public.perfis WHERE email = NEW.email AND id <> NEW.id;

  INSERT INTO public.perfis (id, nome_completo, email, tipo, avatar_url, telefone, cargo, ativo)
  VALUES (
    NEW.id,
    NULLIF(BTRIM(COALESCE(NEW.raw_user_meta_data->>'full_name', NEW.raw_user_meta_data->>'nome_completo', 'Usuário Novo')), ''),
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
  -- Log de erro se falhar a criação do perfil, mas permite criação no Auth
  RAISE WARNING 'Erro no trigger handle_new_user: %', SQLERRM;
  RETURN NEW;
END;
$$;


DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

-- Garantir permissões básicas para o funcionamento do Auth e Perfis
GRANT USAGE ON SCHEMA public TO anon, authenticated;
GRANT ALL ON public.perfis TO service_role;
GRANT SELECT ON public.perfis TO anon, authenticated;
GRANT UPDATE, INSERT ON public.perfis TO authenticated;

-- Configuração de RLS para Perfis
ALTER TABLE public.perfis ENABLE ROW LEVEL SECURITY;

-- 1. Qualquer usuário autenticado vê seu próprio perfil
DROP POLICY IF EXISTS "Usuários veem seu próprio perfil" ON public.perfis;
CREATE POLICY "Usuários veem seu próprio perfil" ON public.perfis
    FOR SELECT TO authenticated USING (auth.uid() = id);

-- 2. Qualquer usuário autenticado atualiza seu próprio perfil
DROP POLICY IF EXISTS "Usuários atualizam seu próprio perfil" ON public.perfis;
CREATE POLICY "Usuários atualizam seu próprio perfil" ON public.perfis
    FOR UPDATE TO authenticated USING (auth.uid() = id) WITH CHECK (auth.uid() = id);

-- 3. Admins veem e gerenciam todos os perfis (Usa função para evitar recursão)
DROP POLICY IF EXISTS "Admins veem todos os perfis" ON public.perfis;
CREATE POLICY "Admins veem todos os perfis" ON public.perfis
    FOR SELECT TO authenticated USING (public.is_admin());

DROP POLICY IF EXISTS "Admins gerenciam todos os perfis" ON public.perfis;
CREATE POLICY "Admins gerenciam todos os perfis" ON public.perfis
    FOR ALL TO authenticated USING (public.is_admin());

-- 4. Permitir que novos usuários sejam inseridos (pelo trigger handle_new_user)
-- Nota: O trigger usa SECURITY DEFINER, então tecnicamente ignora RLS,
-- mas é bom ter política de INSERT se o app tentar inserir diretamente.
DROP POLICY IF EXISTS "Inserção de perfil por sistema" ON public.perfis;
CREATE POLICY "Inserção de perfil por sistema" ON public.perfis
    FOR INSERT TO service_role WITH CHECK (true);


-- ############################################################################
-- CONFIGURAÇÃO DE STORAGE (BUCKETS E POLÍTICAS)
-- ############################################################################

-- Criar buckets se não existirem
INSERT INTO storage.buckets (id, name, public)
VALUES 
  ('perfis', 'perfis', true),
  ('servicos', 'servicos', true),
  ('produtos', 'produtos', true),
  ('promocoes', 'promocoes', true),
  ('avaliacoes', 'avaliacoes', true)
ON CONFLICT (id) DO NOTHING;

-- Liberar acesso público para leitura
DROP POLICY IF EXISTS "Acesso Público Leitura" ON storage.objects;
CREATE POLICY "Acesso Público Leitura" ON storage.objects FOR SELECT USING (bucket_id IN ('perfis', 'servicos', 'produtos', 'promocoes', 'avaliacoes'));

-- Liberar upload para usuários autenticados
DROP POLICY IF EXISTS "Upload Autenticado" ON storage.objects;
CREATE POLICY "Upload Autenticado" ON storage.objects FOR INSERT WITH CHECK (auth.role() = 'authenticated');

-- Liberar deleção para usuários autenticados
DROP POLICY IF EXISTS "Deleção Autenticada" ON storage.objects;
CREATE POLICY "Deleção Autenticada" ON storage.objects FOR DELETE USING (auth.role() = 'authenticated');


-- ============================================================================
-- CORREÇÕES DE SEGURANÇA (RLS) - ADMINISTRAÇÃO
-- Permite que administradores realizem ações em nome dos clientes
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

-- 3. Garantir políticas de SELECT consistentes
DROP POLICY IF EXISTS "Agendamentos visíveis para dono/admin" ON public.agendamentos;
CREATE POLICY "Agendamentos visíveis para dono/admin" ON public.agendamentos 
    FOR SELECT 
    USING (auth.uid() = cliente_id OR auth.uid() = profissional_id OR public.is_admin());

DROP POLICY IF EXISTS "Pacotes contratados visíveis para dono/admin" ON public.pacotes_contratados;
CREATE POLICY "Pacotes contratados visíveis para dono/admin" ON public.pacotes_contratados 
    FOR SELECT 
    USING (auth.uid() = cliente_id OR public.is_admin());-- GARANTIR PERMISSÕES TOTAIS PARA CONTAS E CAIXA
GRANT ALL ON public.contas TO authenticated, service_role;
GRANT ALL ON public.caixas TO authenticated, service_role;
GRANT ALL ON public.dashboard_atividades TO authenticated, service_role;
GRANT ALL ON public.vendas_produtos TO authenticated, service_role;
GRANT ALL ON public.historico_estoque TO authenticated, service_role;
GRANT ALL ON public.produtos TO authenticated, service_role;
