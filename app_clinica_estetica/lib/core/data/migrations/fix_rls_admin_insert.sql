-- SQL FIX FOR RLS POLICIES (Appointment and Packages)
-- These changes allow administrators to create appointments and contracts on behalf of clients.
-- Run this in your Supabase SQL Editor.

-- 1. ADENDAMENTOS: Allow Admins to insert for any client
DROP POLICY IF EXISTS "Admins inserem agendamentos" ON public.agendamentos;
CREATE POLICY "Admins inserem agendamentos" ON public.agendamentos
    FOR INSERT 
    WITH CHECK (public.is_admin());

-- 2. PACOTES CONTRATADOS: Allow Admins to contract packages for clients
DROP POLICY IF EXISTS "Admins contratam pacotes" ON public.pacotes_contratados;
CREATE POLICY "Admins contratam pacotes" ON public.pacotes_contratados
    FOR INSERT 
    WITH CHECK (public.is_admin());

-- 3. Ensure SELECT policies for consistency (already present, but reinforcing)
DROP POLICY IF EXISTS "Agendamentos visíveis para dono/admin" ON public.agendamentos;
CREATE POLICY "Agendamentos visíveis para dono/admin" ON public.agendamentos 
    FOR SELECT 
    USING (auth.uid() = cliente_id OR auth.uid() = profissional_id OR public.is_admin());

DROP POLICY IF EXISTS "Pacotes contratados visíveis para dono/admin" ON public.pacotes_contratados;
CREATE POLICY "Pacotes contratados visíveis para dono/admin" ON public.pacotes_contratados 
    FOR SELECT 
    USING (auth.uid() = cliente_id OR public.is_admin());
