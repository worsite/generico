-- =====================================================================
-- Dashboard de Ventas: esquema de Supabase
-- Ejecutar en Supabase > SQL Editor > New query > Run.
-- Antes: Authentication > Sign In / Providers > Email > desactivar "Confirm email".
-- Es seguro volver a ejecutarlo para actualizar (IF NOT EXISTS / OR REPLACE):
-- no borra usuarios ni datos.
-- =====================================================================

create extension if not exists pgcrypto;

-- ---------- Tablas ----------------------------------------------------

create table if not exists public.groups (
  id          uuid primary key default gen_random_uuid(),
  name        text not null,
  code        text not null unique,
  admin_id    uuid,
  created_at  timestamptz not null default now()
);

create table if not exists public.profiles (
  id               uuid primary key references auth.users(id) on delete cascade,
  group_id         uuid not null references public.groups(id) on delete cascade,
  full_name        text not null default '',
  email            text,
  phone            text,
  role             text not null default 'vendedor' check (role in ('admin','agendador','vendedor')),
  status           text not null default 'pendiente' check (status in ('pendiente','activo')),
  commission_pct   numeric(5,2) not null default 18 check (commission_pct >= 0 and commission_pct <= 100),
  delete_requested boolean not null default false,
  avatar_url         text,
  pending_avatar_url text,
  created_at       timestamptz not null default now()
);
alter table public.profiles alter column commission_pct set default 18;
alter table public.profiles add column if not exists avatar_url text;
alter table public.profiles add column if not exists pending_avatar_url text;
alter table public.groups   add column if not exists photo_url text;

-- Las fotos solo pueden venir del bucket "avatars" de este proyecto
do $$ begin
  alter table public.profiles add constraint profiles_avatar_chk
    check (avatar_url is null or avatar_url like '%/storage/v1/object/public/avatars/%');
exception when duplicate_object then null; end $$;
do $$ begin
  alter table public.profiles add constraint profiles_pending_avatar_chk
    check (pending_avatar_url is null or pending_avatar_url like '%/storage/v1/object/public/avatars/%');
exception when duplicate_object then null; end $$;
do $$ begin
  alter table public.groups add constraint groups_photo_chk
    check (photo_url is null or photo_url like '%/storage/v1/object/public/avatars/%');
exception when duplicate_object then null; end $$;
create index if not exists profiles_group_idx on public.profiles(group_id);

create table if not exists public.appointments (
  id           uuid primary key default gen_random_uuid(),
  group_id     uuid not null references public.groups(id) on delete cascade,
  seller_id    uuid references public.profiles(id) on delete set null,
  created_by   uuid references public.profiles(id) on delete set null,
  client_name  text not null,
  address      text,
  phone        text,
  event_date   timestamptz not null,
  type         text not null default 'demo' check (type in ('mantenimiento','demo','servicio_adicional')),
  status       text not null default 'pendiente' check (status in ('pendiente','venta','sin_venta','cancelada')),
  notes        text,
  created_at   timestamptz not null default now()
);
create index if not exists appointments_group_idx  on public.appointments(group_id, event_date);
create index if not exists appointments_seller_idx on public.appointments(seller_id, event_date);

create table if not exists public.sales (
  id                uuid primary key default gen_random_uuid(),
  group_id          uuid not null references public.groups(id) on delete cascade,
  appointment_id    uuid references public.appointments(id) on delete cascade,
  seller_id         uuid references public.profiles(id) on delete set null,
  amount            numeric(14,2) not null check (amount >= 0),
  net_amount        numeric(14,2),
  commission_pct    numeric(5,2) not null default 0,
  commission_amount numeric(14,2) not null default 0,
  notes             text,
  created_at        timestamptz not null default now()
);
alter table public.sales add column if not exists net_amount numeric(14,2);
create index if not exists sales_group_idx  on public.sales(group_id, created_at);
create index if not exists sales_seller_idx on public.sales(seller_id, created_at);

create table if not exists public.referrals (
  id              uuid primary key default gen_random_uuid(),
  group_id        uuid not null references public.groups(id) on delete cascade,
  appointment_id  uuid references public.appointments(id) on delete cascade,
  seller_id       uuid references public.profiles(id) on delete set null,
  name            text not null,
  phone           text,
  address         text,
  notes           text,
  created_at      timestamptz not null default now()
);
create index if not exists referrals_group_idx on public.referrals(group_id, created_at);

create table if not exists public.gift_assignments (
  id          uuid primary key default gen_random_uuid(),
  group_id    uuid not null references public.groups(id) on delete cascade,
  seller_id   uuid references public.profiles(id) on delete cascade,
  gift_name   text not null default 'Obsequio',
  quantity    integer not null check (quantity > 0),
  status      text not null default 'pendiente' check (status in ('pendiente','aceptado','rechazado')),
  created_by  uuid references public.profiles(id) on delete set null,
  created_at  timestamptz not null default now()
);

create table if not exists public.gift_deliveries (
  id               uuid primary key default gen_random_uuid(),
  group_id         uuid not null references public.groups(id) on delete cascade,
  seller_id        uuid references public.profiles(id) on delete set null,
  appointment_id   uuid references public.appointments(id) on delete set null,
  gift_name        text not null default 'Obsequio',
  quantity         integer not null default 1 check (quantity > 0),
  recipient_name   text not null,
  recipient_contact text,
  reason           text not null,
  delivered_at     date not null default current_date,
  created_at       timestamptz not null default now()
);

-- Actualizacion de instalaciones anteriores (no hace nada si ya existen)
alter table public.gift_assignments add column if not exists gift_name text not null default 'Obsequio';
alter table public.gift_deliveries  add column if not exists gift_name text not null default 'Obsequio';
alter table public.gift_deliveries  add column if not exists appointment_id uuid references public.appointments(id) on delete set null;
alter table public.gift_deliveries  add column if not exists delivered_at date not null default current_date;

create table if not exists public.notifications (
  id          uuid primary key default gen_random_uuid(),
  group_id    uuid references public.groups(id) on delete cascade,
  user_id     uuid not null references public.profiles(id) on delete cascade,
  type        text not null default 'info',
  title       text not null,
  body        text,
  read        boolean not null default false,
  created_at  timestamptz not null default now()
);
create index if not exists notifications_user_idx on public.notifications(user_id, created_at desc);

-- Chats: recipient_id nulo = chat general del grupo
create table if not exists public.messages (
  id            uuid primary key default gen_random_uuid(),
  group_id      uuid not null references public.groups(id) on delete cascade,
  sender_id     uuid references public.profiles(id) on delete set null,
  recipient_id  uuid references public.profiles(id) on delete cascade,
  body          text not null check (char_length(body) between 1 and 2000),
  ref_type      text check (ref_type in ('appointment','sale','referral','delivery')),
  ref_id        uuid,
  created_at    timestamptz not null default now()
);
create index if not exists messages_group_idx on public.messages(group_id, created_at desc);
create index if not exists messages_pair_idx  on public.messages(sender_id, recipient_id, created_at desc);

-- Ultima lectura por conversacion (chat_key = id del otro usuario o 'group')
create table if not exists public.chat_reads (
  user_id       uuid not null references public.profiles(id) on delete cascade,
  chat_key      text not null,
  last_read_at  timestamptz not null default now(),
  primary key (user_id, chat_key)
);

-- Control de la plataforma (solo el dueño, a traves de funciones)
create table if not exists public.platform_owner (
  user_id uuid primary key references auth.users(id) on delete cascade
);
create table if not exists public.platform_settings (
  id                 int primary key default 1 check (id = 1),
  monthly_price      numeric(14,2) not null default 50000,
  first_payment_days int not null default 7,
  warn_days          int not null default 3
);
insert into public.platform_settings(id) values (1) on conflict do nothing;
create table if not exists public.subscriptions (
  group_id      uuid primary key references public.groups(id) on delete cascade,
  registered_at timestamptz not null default now(),
  paid_until    date not null,
  blocked       boolean not null default false,
  note          text
);
create table if not exists public.payments (
  id          uuid primary key default gen_random_uuid(),
  group_id    uuid not null references public.groups(id) on delete cascade,
  amount      numeric(14,2) not null,
  months      int not null default 1,
  paid_at     timestamptz not null default now(),
  period_end  date not null,
  note        text
);
create index if not exists payments_group_idx on public.payments(group_id, paid_at desc);

-- ---------- Funciones auxiliares (SECURITY DEFINER evita recursion de RLS)

create or replace function public.bogota_today() returns date
language sql stable as $$ select (now() at time zone 'America/Bogota')::date $$;

-- El grupo tiene acceso si su suscripcion no esta bloqueada ni vencida
create or replace function public.access_ok(p_group uuid) returns boolean
language sql stable security definer set search_path = public as $$
  select not exists (
    select 1 from public.subscriptions s
    where s.group_id = p_group and (s.blocked or s.paid_until < public.bogota_today()))
$$;

-- Solo el ADMIN pierde el acceso cuando su suscripcion esta bloqueada o vencida
create or replace function public.my_group() returns uuid
language sql stable security definer set search_path = public as $$
  select p.group_id from public.profiles p
  where p.id = auth.uid() and p.status = 'activo'
    and (p.role <> 'admin' or public.access_ok(p.group_id))
$$;

create or replace function public.is_owner() returns boolean
language sql stable security definer set search_path = public as $$
  select exists (select 1 from public.platform_owner where user_id = auth.uid())
$$;

create or replace function public.same_group_user(p_user uuid) returns boolean
language sql stable security definer set search_path = public as $$
  select exists (select 1 from public.profiles
                 where id = p_user and group_id = public.my_group() and status = 'activo')
$$;

create or replace function public.my_role() returns text
language sql stable security definer set search_path = public as $$
  select role from public.profiles where id = auth.uid() and status = 'activo'
$$;

create or replace function public.is_admin() returns boolean
language sql stable security definer set search_path = public as $$
  select coalesce(public.my_role() = 'admin', false)
$$;

create or replace function public.is_manager() returns boolean
language sql stable security definer set search_path = public as $$
  select coalesce(public.my_role() in ('admin','agendador'), false)
$$;

-- Notifica a los administradores de un grupo
create or replace function public.notify_managers(p_group uuid, p_type text, p_title text, p_body text)
returns void language sql security definer set search_path = public as $$
  insert into public.notifications(group_id, user_id, type, title, body)
  select p_group, id, p_type, p_title, p_body
  from public.profiles
  where group_id = p_group and status = 'activo' and role = 'admin'
$$;

-- Validacion publica del codigo de grupo (la usa la pantalla de registro)
create or replace function public.check_group_code(p_code text) returns text
language sql stable security definer set search_path = public as $$
  select name from public.groups where upper(code) = upper(trim(p_code)) limit 1
$$;
grant execute on function public.check_group_code(text) to anon, authenticated;

-- ---------- Alta de usuario: crea perfil (y grupo si es administrador) ----

create or replace function public.handle_new_user() returns trigger
language plpgsql security definer set search_path = public as $$
declare
  meta     jsonb := coalesce(new.raw_user_meta_data, '{}'::jsonb);
  v_role   text  := meta->>'role';
  v_name   text  := coalesce(nullif(trim(meta->>'full_name'), ''), split_part(new.email, '@', 1));
  v_group  uuid;
  v_code   text;
begin
  -- usuarios creados a mano desde el panel de Supabase (sin datos): no tienen perfil
  if v_role is null then
    return new;
  end if;
  if v_role = 'admin' then
    loop
      v_code := 'GRP-' || upper(substr(md5(random()::text || clock_timestamp()::text), 1, 6));
      exit when not exists (select 1 from public.groups where code = v_code);
    end loop;
    insert into public.groups(name, code, admin_id)
      values (coalesce(nullif(trim(meta->>'group_name'), ''), 'Grupo de ' || v_name), v_code, new.id)
      returning id into v_group;
    insert into public.profiles(id, group_id, full_name, email, phone, role, status)
      values (new.id, v_group, v_name, new.email, meta->>'phone', 'admin', 'activo');
    insert into public.subscriptions(group_id, paid_until)
      values (v_group, public.bogota_today() + (select first_payment_days from public.platform_settings where id = 1));
  else
    select id into v_group from public.groups where upper(code) = upper(trim(coalesce(meta->>'group_code', '')));
    if v_group is null then
      raise exception 'Codigo de grupo invalido';
    end if;
    insert into public.profiles(id, group_id, full_name, email, phone, role, status)
      values (new.id, v_group, v_name, new.email, meta->>'phone', 'vendedor', 'pendiente');
    perform public.notify_managers(v_group, 'solicitud', 'Nueva solicitud de ingreso',
      v_name || ' quiere unirse al grupo.');
  end if;
  return new;
end $$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created after insert on auth.users
  for each row execute function public.handle_new_user();

-- ---------- Proteccion de campos sensibles en profiles --------------------

create or replace function public.guard_profile_update() returns trigger
language plpgsql security definer set search_path = public as $$
declare
  v_role text := public.my_role();
begin
  if v_role = 'admin' then
    -- el admin no puede quitarse a si mismo el cargo ni cambiar de grupo
    if old.id = auth.uid() then new.role := old.role; new.status := old.status; end if;
    new.group_id := old.group_id;
    new.id := old.id;
    -- avisar al vendedor si se le rechaza la baja o cambian cargo/comision
    if old.delete_requested and not new.delete_requested and old.id <> auth.uid() then
      insert into public.notifications(group_id, user_id, type, title, body)
        values (old.group_id, old.id, 'baja', 'Solicitud de baja rechazada', 'El administrador rechazo tu solicitud de eliminar la cuenta.');
    end if;
    if old.role <> new.role then
      insert into public.notifications(group_id, user_id, type, title, body)
        values (old.group_id, old.id, 'cargo', 'Cambio de cargo', 'Tu cargo ahora es: ' || new.role || '.');
    end if;
    if old.commission_pct <> new.commission_pct then
      insert into public.notifications(group_id, user_id, type, title, body)
        values (old.group_id, old.id, 'comision', 'Comision actualizada', 'Tu comision ahora es ' || new.commission_pct || '% de cada venta.');
    end if;
    if old.status = 'pendiente' and new.status = 'activo' then
      insert into public.notifications(group_id, user_id, type, title, body)
        values (old.group_id, old.id, 'solicitud', 'Solicitud aceptada', 'Ya haces parte del grupo. Bienvenido.');
    end if;
    -- aprobacion o rechazo de la foto de perfil de un emprendedor
    if old.id <> auth.uid() and old.pending_avatar_url is not null and new.pending_avatar_url is null then
      if new.avatar_url is not distinct from old.pending_avatar_url then
        insert into public.notifications(group_id, user_id, type, title, body)
          values (old.group_id, old.id, 'foto', 'Foto aprobada', 'Tu nueva foto de perfil ya es visible para tu equipo.');
      else
        insert into public.notifications(group_id, user_id, type, title, body)
          values (old.group_id, old.id, 'foto', 'Foto rechazada', 'El administrador no aprobo tu foto de perfil. Puedes subir otra.');
      end if;
    end if;
    return new;
  elsif old.id = auth.uid() then
    -- el propio usuario: solo nombre, telefono y solicitud de baja
    new.role := old.role; new.status := old.status; new.commission_pct := old.commission_pct;
    new.group_id := old.group_id; new.email := old.email; new.id := old.id;
    new.avatar_url := old.avatar_url;      -- la foto visible solo la cambia el admin al aprobar
    if new.pending_avatar_url is not null and new.pending_avatar_url is distinct from old.pending_avatar_url then
      perform public.notify_managers(old.group_id, 'foto', 'Foto de perfil por aprobar',
        old.full_name || ' subio una nueva foto de perfil.');
    end if;
    if new.delete_requested and not old.delete_requested then
      perform public.notify_managers(old.group_id, 'baja', 'Solicitud de eliminar cuenta',
        old.full_name || ' pidio eliminar su cuenta.');
    end if;
    return new;
  end if;
  raise exception 'Sin permiso';
end $$;

drop trigger if exists guard_profile_update on public.profiles;
create trigger guard_profile_update before update on public.profiles
  for each row execute function public.guard_profile_update();

-- Eliminar un usuario (solo el administrador, dentro de su grupo)
create or replace function public.admin_remove_user(p_user uuid) returns void
language plpgsql security definer set search_path = public, auth as $$
declare
  v_target public.profiles;
begin
  select * into v_target from public.profiles where id = p_user;
  if v_target.id is null or v_target.group_id is distinct from public.my_group() then
    raise exception 'Usuario no encontrado';
  end if;
  if p_user = auth.uid() then raise exception 'No puedes eliminarte a ti mismo'; end if;
  if public.is_admin() then
    delete from auth.users where id = p_user;
  else
    raise exception 'Sin permiso';
  end if;
end $$;
grant execute on function public.admin_remove_user(uuid) to authenticated;

-- ---------- Triggers de negocio -------------------------------------------

-- Ventas: la comision se fija en el servidor con el % vigente del vendedor
create or replace function public.sales_set_commission() returns trigger
language plpgsql security definer set search_path = public as $$
declare v_pct numeric; v_net numeric;
begin
  if tg_op = 'INSERT' then
    select commission_pct into v_pct from public.profiles where id = new.seller_id;
    new.commission_pct := coalesce(v_pct, 0);
  else
    new.commission_pct := old.commission_pct;
  end if;
  -- la comision se calcula sobre la venta sin IVA: venta / 1.19
  v_net := new.amount / 1.19;
  new.net_amount := round(v_net, 2);
  new.commission_amount := round(v_net * new.commission_pct / 100, 2);
  return new;
end $$;
drop trigger if exists sales_set_commission on public.sales;
create trigger sales_set_commission before insert or update on public.sales
  for each row execute function public.sales_set_commission();

-- Citas asignadas por otra persona -> notificacion al vendedor
create or replace function public.appointments_notify() returns trigger
language plpgsql security definer set search_path = public as $$
declare v_send boolean := false;
begin
  if new.seller_id is not null and new.seller_id is distinct from auth.uid() then
    if tg_op = 'INSERT' then
      v_send := true;
    elsif new.seller_id is distinct from old.seller_id then
      v_send := true;
    end if;
  end if;
  if v_send then
    insert into public.notifications(group_id, user_id, type, title, body)
      values (new.group_id, new.seller_id, 'agenda', 'Nueva cita asignada',
        new.client_name || ' - ' || to_char(new.event_date at time zone 'America/Bogota', 'DD/MM/YYYY HH24:MI'));
  end if;
  return new;
end $$;
drop trigger if exists appointments_notify on public.appointments;
create trigger appointments_notify after insert or update on public.appointments
  for each row execute function public.appointments_notify();

-- Obsequios: avisar al vendedor; congelar columnas cuando el vendedor responde
create or replace function public.gift_assign_notify() returns trigger
language plpgsql security definer set search_path = public as $$
declare v_name text;
begin
  if tg_op = 'INSERT' then
    insert into public.notifications(group_id, user_id, type, title, body)
      values (new.group_id, new.seller_id, 'obsequio', 'Te enviaran obsequios',
        'El administrador te asigno ' || new.quantity || ' x ' || new.gift_name || '. Aceptalos en la seccion Obsequios.');
  elsif old.status = 'pendiente' and new.status in ('aceptado','rechazado') then
    select full_name into v_name from public.profiles where id = new.seller_id;
    perform public.notify_managers(new.group_id, 'obsequio',
      'Obsequios ' || new.status, coalesce(v_name,'Un emprendedor') || ' ' ||
      case when new.status = 'aceptado' then 'acepto' else 'rechazo' end || ' ' || new.quantity || ' x ' || new.gift_name || '.');
  end if;
  return new;
end $$;
drop trigger if exists gift_assign_notify on public.gift_assignments;
create trigger gift_assign_notify after insert or update on public.gift_assignments
  for each row execute function public.gift_assign_notify();

create or replace function public.gift_assign_deleted() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  if old.seller_id is not null and exists (select 1 from public.profiles where id = old.seller_id) then
    insert into public.notifications(group_id, user_id, type, title, body)
      values (old.group_id, old.seller_id, 'obsequio', 'Envio de obsequios cancelado',
        'El administrador cancelo el envio de ' || old.quantity || ' x ' || old.gift_name || '.');
  end if;
  return old;
end $$;
drop trigger if exists gift_assign_deleted on public.gift_assignments;
create trigger gift_assign_deleted after delete on public.gift_assignments
  for each row execute function public.gift_assign_deleted();

create or replace function public.gift_assign_guard() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  if not public.is_admin() then
    new.quantity := old.quantity; new.seller_id := old.seller_id;
    new.group_id := old.group_id; new.created_by := old.created_by; new.gift_name := old.gift_name;
    if old.status <> 'pendiente' then new.status := old.status; end if;
    if new.status not in ('aceptado','rechazado','pendiente') then new.status := old.status; end if;
  end if;
  return new;
end $$;
drop trigger if exists gift_assign_guard on public.gift_assignments;
create trigger gift_assign_guard before update on public.gift_assignments
  for each row execute function public.gift_assign_guard();

-- Entregas: no se puede entregar mas de lo aceptado de ESE obsequio
create or replace function public.gift_delivery_check() returns trigger
language plpgsql security definer set search_path = public as $$
declare v_accepted int; v_delivered int;
begin
  select coalesce(sum(quantity),0) into v_accepted from public.gift_assignments
    where seller_id = new.seller_id and status = 'aceptado' and lower(trim(gift_name)) = lower(trim(new.gift_name));
  select coalesce(sum(quantity),0) into v_delivered from public.gift_deliveries
    where seller_id = new.seller_id and lower(trim(gift_name)) = lower(trim(new.gift_name));
  if new.quantity + v_delivered > v_accepted then
    raise exception 'No tienes suficientes unidades de "%" disponibles', new.gift_name;
  end if;
  return new;
end $$;
drop trigger if exists gift_delivery_check on public.gift_deliveries;
create trigger gift_delivery_check before insert on public.gift_deliveries
  for each row execute function public.gift_delivery_check();

-- ---------- Row Level Security --------------------------------------------

alter table public.groups           enable row level security;
alter table public.profiles         enable row level security;
alter table public.appointments     enable row level security;
alter table public.sales            enable row level security;
alter table public.referrals        enable row level security;
alter table public.gift_assignments enable row level security;
alter table public.gift_deliveries  enable row level security;
alter table public.notifications    enable row level security;
alter table public.messages         enable row level security;
alter table public.chat_reads       enable row level security;
alter table public.platform_owner   enable row level security;
alter table public.platform_settings enable row level security;
alter table public.subscriptions    enable row level security;
alter table public.payments         enable row level security;

-- groups
drop policy if exists groups_select on public.groups;
create policy groups_select on public.groups for select to authenticated
  using (id = public.my_group() or admin_id = auth.uid()
         or id in (select group_id from public.profiles where id = auth.uid()));
drop policy if exists groups_update on public.groups;
create policy groups_update on public.groups for update to authenticated
  using (public.is_admin() and id = public.my_group()) with check (id = public.my_group());

-- profiles
drop policy if exists profiles_select on public.profiles;
create policy profiles_select on public.profiles for select to authenticated
  using (id = auth.uid() or (group_id = public.my_group() and public.is_admin()));
drop policy if exists profiles_update on public.profiles;
create policy profiles_update on public.profiles for update to authenticated
  using (id = auth.uid() or (group_id = public.my_group() and public.is_admin()))
  with check (id = auth.uid() or group_id = public.my_group());

-- appointments
drop policy if exists appts_select on public.appointments;
create policy appts_select on public.appointments for select to authenticated
  using (group_id = public.my_group() and (public.is_manager() or seller_id = auth.uid() or created_by = auth.uid()));
drop policy if exists appts_insert on public.appointments;
create policy appts_insert on public.appointments for insert to authenticated
  with check (group_id = public.my_group() and created_by = auth.uid()
              and (seller_id = auth.uid() or public.is_manager()));
drop policy if exists appts_update on public.appointments;
create policy appts_update on public.appointments for update to authenticated
  using (group_id = public.my_group() and (public.is_manager() or seller_id = auth.uid()))
  with check (group_id = public.my_group() and (public.is_manager() or seller_id = auth.uid()));
drop policy if exists appts_delete on public.appointments;
create policy appts_delete on public.appointments for delete to authenticated
  using (group_id = public.my_group() and (public.is_manager() or seller_id = auth.uid()));

-- sales
drop policy if exists sales_select on public.sales;
create policy sales_select on public.sales for select to authenticated
  using (group_id = public.my_group() and (public.is_admin() or seller_id = auth.uid()));
drop policy if exists sales_insert on public.sales;
create policy sales_insert on public.sales for insert to authenticated
  with check (group_id = public.my_group() and (seller_id = auth.uid() or public.is_admin()));
drop policy if exists sales_update on public.sales;
create policy sales_update on public.sales for update to authenticated
  using (group_id = public.my_group() and (public.is_admin() or seller_id = auth.uid()))
  with check (group_id = public.my_group());
drop policy if exists sales_delete on public.sales;
create policy sales_delete on public.sales for delete to authenticated
  using (group_id = public.my_group() and (public.is_admin() or seller_id = auth.uid()));

-- referrals
drop policy if exists refs_select on public.referrals;
create policy refs_select on public.referrals for select to authenticated
  using (group_id = public.my_group() and (public.is_admin() or seller_id = auth.uid()));
drop policy if exists refs_insert on public.referrals;
create policy refs_insert on public.referrals for insert to authenticated
  with check (group_id = public.my_group() and (seller_id = auth.uid() or public.is_admin()));
drop policy if exists refs_update on public.referrals;
create policy refs_update on public.referrals for update to authenticated
  using (group_id = public.my_group() and (public.is_admin() or seller_id = auth.uid()))
  with check (group_id = public.my_group());
drop policy if exists refs_delete on public.referrals;
create policy refs_delete on public.referrals for delete to authenticated
  using (group_id = public.my_group() and (public.is_admin() or seller_id = auth.uid()));

-- gift_assignments (solo el admin asigna; el vendedor acepta/rechaza las suyas)
drop policy if exists gifta_select on public.gift_assignments;
create policy gifta_select on public.gift_assignments for select to authenticated
  using (group_id = public.my_group() and (public.is_admin() or seller_id = auth.uid()));
drop policy if exists gifta_insert on public.gift_assignments;
create policy gifta_insert on public.gift_assignments for insert to authenticated
  with check (group_id = public.my_group() and public.is_admin() and created_by = auth.uid());
drop policy if exists gifta_update on public.gift_assignments;
create policy gifta_update on public.gift_assignments for update to authenticated
  using (group_id = public.my_group() and (public.is_admin() or seller_id = auth.uid()))
  with check (group_id = public.my_group());
drop policy if exists gifta_delete on public.gift_assignments;
create policy gifta_delete on public.gift_assignments for delete to authenticated
  using (group_id = public.my_group() and public.is_admin() and status = 'pendiente');

-- gift_deliveries
drop policy if exists giftd_select on public.gift_deliveries;
create policy giftd_select on public.gift_deliveries for select to authenticated
  using (group_id = public.my_group() and (public.is_admin() or seller_id = auth.uid()));
drop policy if exists giftd_insert on public.gift_deliveries;
create policy giftd_insert on public.gift_deliveries for insert to authenticated
  with check (group_id = public.my_group() and seller_id = auth.uid());

-- notifications
drop policy if exists notif_select on public.notifications;
create policy notif_select on public.notifications for select to authenticated
  using (user_id = auth.uid());
drop policy if exists notif_update on public.notifications;
create policy notif_update on public.notifications for update to authenticated
  using (user_id = auth.uid()) with check (user_id = auth.uid());
drop policy if exists notif_delete on public.notifications;
create policy notif_delete on public.notifications for delete to authenticated
  using (user_id = auth.uid());
drop policy if exists notif_insert on public.notifications;
create policy notif_insert on public.notifications for insert to authenticated
  with check (group_id = public.my_group() and public.is_admin());

-- messages: el remitente y el destinatario (o todo el grupo si es chat general)
drop policy if exists msg_select on public.messages;
create policy msg_select on public.messages for select to authenticated
  using (group_id = public.my_group()
         and (sender_id = auth.uid() or recipient_id = auth.uid() or recipient_id is null));
drop policy if exists msg_insert on public.messages;
create policy msg_insert on public.messages for insert to authenticated
  with check (group_id = public.my_group() and sender_id = auth.uid()
              and (recipient_id is null or public.same_group_user(recipient_id)));

-- chat_reads: cada quien escribe lo suyo; el otro lado puede leerlo (para el doble check)
drop policy if exists reads_select on public.chat_reads;
create policy reads_select on public.chat_reads for select to authenticated
  using (user_id = auth.uid() or chat_key = auth.uid()::text);
drop policy if exists reads_insert on public.chat_reads;
create policy reads_insert on public.chat_reads for insert to authenticated
  with check (user_id = auth.uid() and
    case when chat_key = 'group' then public.my_group() is not null
         when chat_key ~ '^[0-9a-fA-F-]{36}$' then public.same_group_user(chat_key::uuid)
         else false end);
drop policy if exists reads_update on public.chat_reads;
create policy reads_update on public.chat_reads for update to authenticated
  using (user_id = auth.uid()) with check (user_id = auth.uid());

-- platform_owner: cada quien solo puede ver si es el dueño
drop policy if exists owner_select on public.platform_owner;
create policy owner_select on public.platform_owner for select to authenticated
  using (user_id = auth.uid());

-- ---------- Funciones para la app -----------------------------------------

-- Miembros activos de mi grupo (nombre y cargo), para chats y asignaciones
drop function if exists public.group_members();
create or replace function public.group_members()
returns table(id uuid, full_name text, role text, avatar_url text)
language sql stable security definer set search_path = public as $$
  select p.id, p.full_name, p.role, p.avatar_url from public.profiles p
  where p.group_id = public.my_group() and p.status = 'activo'
  order by p.full_name
$$;
grant execute on function public.group_members() to authenticated;

-- Estado de la mensualidad del administrador que consulta
create or replace function public.my_subscription() returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare v_group uuid; s public.subscriptions; st public.platform_settings; v_days int;
begin
  select group_id into v_group from public.profiles
    where id = auth.uid() and role = 'admin' and status = 'activo';
  if v_group is null then return null; end if;
  select * into st from public.platform_settings where id = 1;
  select * into s from public.subscriptions where group_id = v_group;
  if s.group_id is null then
    return jsonb_build_object('blocked', false, 'price', st.monthly_price, 'warn_days', st.warn_days);
  end if;
  v_days := s.paid_until - public.bogota_today();
  return jsonb_build_object('blocked', s.blocked or v_days < 0, 'manual', s.blocked,
    'paid_until', s.paid_until, 'days_left', v_days, 'price', st.monthly_price, 'warn_days', st.warn_days);
end $$;
grant execute on function public.my_subscription() to authenticated;

-- ---------- Funciones del panel de control (solo el dueño) ----------------

create or replace function public.owner_check() returns boolean
language sql stable security definer set search_path = public as $$
  select public.is_owner()
$$;
grant execute on function public.owner_check() to authenticated;

create or replace function public.owner_settings() returns public.platform_settings
language plpgsql stable security definer set search_path = public as $$
declare r public.platform_settings;
begin
  if not public.is_owner() then raise exception 'Sin permiso'; end if;
  select * into r from public.platform_settings where id = 1;
  return r;
end $$;
grant execute on function public.owner_settings() to authenticated;

create or replace function public.owner_overview()
returns table(group_id uuid, group_name text, admin_id uuid, admin_name text, admin_email text,
              admin_phone text, registered_at timestamptz, paid_until date, blocked boolean,
              sellers bigint, payments_count bigint, last_payment timestamptz, total_paid numeric)
language plpgsql stable security definer set search_path = public as $$
begin
  if not public.is_owner() then raise exception 'Sin permiso'; end if;
  return query
  select g.id, g.name, p.id, p.full_name, p.email, p.phone, s.registered_at, s.paid_until, s.blocked,
         (select count(*) from public.profiles x where x.group_id = g.id and x.role <> 'admin' and x.status = 'activo'),
         (select count(*) from public.payments y where y.group_id = g.id),
         (select max(y.paid_at) from public.payments y where y.group_id = g.id),
         (select coalesce(sum(y.amount), 0) from public.payments y where y.group_id = g.id)
  from public.groups g
  join public.subscriptions s on s.group_id = g.id
  left join public.profiles p on p.id = g.admin_id
  order by s.registered_at desc;
end $$;
grant execute on function public.owner_overview() to authenticated;

create or replace function public.owner_payments(p_group uuid) returns setof public.payments
language plpgsql stable security definer set search_path = public as $$
begin
  if not public.is_owner() then raise exception 'Sin permiso'; end if;
  return query select * from public.payments where group_id = p_group order by paid_at desc;
end $$;
grant execute on function public.owner_payments(uuid) to authenticated;

create or replace function public.owner_mark_paid(p_group uuid, p_amount numeric, p_months int, p_note text)
returns void language plpgsql security definer set search_path = public as $$
declare s public.subscriptions; v_new date; v_admin uuid;
begin
  if not public.is_owner() then raise exception 'Sin permiso'; end if;
  if p_months is null or p_months < 1 then raise exception 'Meses invalidos'; end if;
  select * into s from public.subscriptions where group_id = p_group;
  if s.group_id is null then raise exception 'Grupo no encontrado'; end if;
  v_new := (greatest(s.paid_until, public.bogota_today()) + make_interval(months => p_months))::date;
  update public.subscriptions set paid_until = v_new, blocked = false where group_id = p_group;
  insert into public.payments(group_id, amount, months, period_end, note)
    values (p_group, coalesce(p_amount, 0), p_months, v_new, nullif(trim(p_note), ''));
  select admin_id into v_admin from public.groups where id = p_group;
  if v_admin is not null and exists (select 1 from public.profiles where id = v_admin) then
    insert into public.notifications(group_id, user_id, type, title, body)
      values (p_group, v_admin, 'pago', 'Pago registrado',
              'Tu mensualidad quedo paga hasta el ' || to_char(v_new, 'DD/MM/YYYY') || '. Gracias.');
  end if;
end $$;
grant execute on function public.owner_mark_paid(uuid, numeric, int, text) to authenticated;

create or replace function public.owner_set_blocked(p_group uuid, p_blocked boolean) returns void
language plpgsql security definer set search_path = public as $$
begin
  if not public.is_owner() then raise exception 'Sin permiso'; end if;
  update public.subscriptions set blocked = p_blocked where group_id = p_group;
end $$;
grant execute on function public.owner_set_blocked(uuid, boolean) to authenticated;

create or replace function public.owner_set_due(p_group uuid, p_date date) returns void
language plpgsql security definer set search_path = public as $$
begin
  if not public.is_owner() then raise exception 'Sin permiso'; end if;
  update public.subscriptions set paid_until = p_date where group_id = p_group;
end $$;
grant execute on function public.owner_set_due(uuid, date) to authenticated;

create or replace function public.owner_update_settings(p_price numeric, p_first_days int, p_warn_days int)
returns void language plpgsql security definer set search_path = public as $$
begin
  if not public.is_owner() then raise exception 'Sin permiso'; end if;
  if p_price < 0 or p_first_days < 0 or p_warn_days < 0 then raise exception 'Valores invalidos'; end if;
  update public.platform_settings
    set monthly_price = p_price, first_payment_days = p_first_days, warn_days = p_warn_days where id = 1;
end $$;
grant execute on function public.owner_update_settings(numeric, int, int) to authenticated;

-- ---------- Datos para instalaciones anteriores ----------------------------

-- grupos que ya existian: reciben su periodo inicial de pago
insert into public.subscriptions(group_id, paid_until)
  select g.id, public.bogota_today() + (select first_payment_days from public.platform_settings where id = 1)
  from public.groups g
  where not exists (select 1 from public.subscriptions s where s.group_id = g.id);

-- ventas anteriores: se calcula la base sin IVA (la comision registrada no se toca)
alter table public.sales disable trigger sales_set_commission;
update public.sales set net_amount = round(amount / 1.19, 2) where net_amount is null;
alter table public.sales enable trigger sales_set_commission;

-- fotos de perfil: bucket publico "avatars"; cada usuario solo sube dentro de su carpeta
insert into storage.buckets (id, name, public) values ('avatars', 'avatars', true)
  on conflict (id) do update set public = true;
do $$ begin
  update storage.buckets set file_size_limit = 1048576,
    allowed_mime_types = array['image/jpeg','image/png','image/webp'] where id = 'avatars';
exception when others then null;
end $$;
drop policy if exists avatars_insert on storage.objects;
create policy avatars_insert on storage.objects for insert to authenticated
  with check (bucket_id = 'avatars' and (storage.foldername(name))[1] = auth.uid()::text);
drop policy if exists avatars_update on storage.objects;
create policy avatars_update on storage.objects for update to authenticated
  using (bucket_id = 'avatars' and (storage.foldername(name))[1] = auth.uid()::text);
drop policy if exists avatars_delete on storage.objects;
create policy avatars_delete on storage.objects for delete to authenticated
  using (bucket_id = 'avatars' and (storage.foldername(name))[1] = auth.uid()::text);

-- tiempo real para los chats (si la publicacion no existe, se ignora)
do $$ begin
  alter publication supabase_realtime add table public.messages;
exception when others then null;
end $$;

-- ---------- Permisos de tabla ---------------------------------------------
grant usage on schema public to anon, authenticated;
grant select, insert, update, delete on all tables in schema public to authenticated;
revoke all on all tables in schema public from anon;
