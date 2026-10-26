-- =====================================================================
-- Registrar al dueño de la plataforma (se hace UNA sola vez)
--
-- 1) Ejecuta antes schema.sql completo.
-- 2) En Supabase: Authentication > Users > Add user > Create new user
--      Email:    ukeiyo@ukeiyo.app
--      Password: la contraseña que tú elijas
--      Marca "Auto Confirm User".
-- 3) Ejecuta este script en SQL Editor.
-- 4) Abre control.html e ingresa con usuario "Ukeiyo" y esa contraseña.
-- =====================================================================

insert into public.platform_owner(user_id)
select id from auth.users where email = 'ukeiyo@ukeiyo.app'
on conflict do nothing;

-- Debe devolver 1 fila. Si sale vacío, el usuario del paso 2 no existe o el correo no coincide.
select u.email, 'dueño registrado' as estado
from public.platform_owner o join auth.users u on u.id = o.user_id;
