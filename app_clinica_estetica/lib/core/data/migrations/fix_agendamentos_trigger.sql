-- SQL TO FIX TRIGGER ERROR: record "new" has no field "data"
-- Run this in your Supabase SQL Editor.

-- This error occurs because a trigger function is trying to access 'NEW.data' 
-- but the column in the 'agendamentos' table is named 'data_hora'.

-- You likely have a function named something like 'handle_agendamento_updated' 
-- or 'sync_agendamento_to_caixa'.

-- Below is a template to fix the common candidate function. 
-- Please adapt the function name if it is different in your Supabase instance.

CREATE OR REPLACE FUNCTION public.handle_agendamento_payment()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
BEGIN
    -- Check if it is being marked as paid
    IF (NEW.pago = true AND (OLD.pago = false OR OLD.pago IS NULL)) THEN
        -- IMPORTANT: Use NEW.data_hora instead of NEW.data
        INSERT INTO public.caixa (
            profissional_id,
            valor,
            descricao,
            tipo,
            data, -- The 'caixa' table likely uses 'data'
            forma_pagamento
        ) VALUES (
            NEW.profissional_id,
            NEW.valor_total,
            'Atendimento: ' || (SELECT nome FROM servicos WHERE id = NEW.servico_id),
            'entrada',
            NEW.data_hora, -- FIX: Changed from NEW.data to NEW.data_hora
            NEW.forma_pagamento
        );
    END IF;
    RETURN NEW;
END;
$function$;

-- If you don't know the function name, you can find it by running:
-- SELECT 
--     trigger_name, 
--     event_object_table, 
--     action_statement 
-- FROM information_schema.triggers 
-- WHERE event_object_table = 'agendamentos';
