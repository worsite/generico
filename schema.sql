-- =====================================================================
-- Dashboard de Ventas: esquema de Supabase
-- Ejecutar UNA VEZ en Supabase > SQL Editor > New query > Run.
-- Antes: Authentication > Providers > Email > desactivar "Confirm email".
-- Es seguro volver a ejecutarlo (usa IF NOT EXISTS / OR REPLACE).
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
  commission_pct   numeric(5,2) not null default 10 check (commission_pct >= 0 and commission_pct <= 100),
  delete_requested boolean not null default false,
  created_at       timestamptz not null default now()
);
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
  commission_pct    numeric(5,2) not null default 0,
  commission_amount numeric(14,2) not null default 0,
  notes             text,
  created_at        timestamptz not null default now()
);
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

-- ---------- Funciones auxiliares (SECURITY DEFINER evita recursion de RLS)

create or replace function public.my_group() returns uuid
language sql stable security definer set search_path = public as $$
  select group_id from public.profiles where id = auth.uid() and status = 'activo'
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

-- Notifica a todos los administradores (y opcionalmente agendadores) de un grupo
create or replace function public.notify_managers(p_group uuid, p_type text, p_title text, p_body text)
returns void language sql security definer set search_path = public as $$
  insert into public.notifications(group_id, user_id, type, title, body)
  select p_group, id, p_type, p_title, p_body
  from public.profiles
  where group_id = p_group and status = 'activo' and role in ('admin','agendador')
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
  v_role   text  := coalesce(meta->>'role', 'vendedor');
  v_name   text  := coalesce(nullif(trim(meta->>'full_name'), ''), split_part(new.email, '@', 1));
  v_group  uuid;
  v_code   text;
begin
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
    return new;
  elsif v_role = 'agendador' and old.id <> auth.uid() then
    -- solo puede aceptar solicitudes pendientes
    if old.status = 'pendiente' and new.status = 'activo' then
      new.role := old.role; new.commission_pct := old.commission_pct;
      new.group_id := old.group_id; new.delete_requested := old.delete_requested; new.id := old.id;
      insert into public.notifications(group_id, user_id, type, title, body)
        values (old.group_id, old.id, 'solicitud', 'Solicitud aceptada', 'Ya haces parte del grupo. Bienvenido.');
      return new;
    end if;
    raise exception 'Sin permiso';
  elsif old.id = auth.uid() then
    -- el propio usuario: solo nombre, telefono y solicitud de baja
    new.role := old.role; new.status := old.status; new.commission_pct := old.commission_pct;
    new.group_id := old.group_id; new.email := old.email; new.id := old.id;
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

-- Eliminar un usuario (admin: cualquiera del grupo; agendador: solo pendientes)
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
  if public.is_admin() or (public.my_role() = 'agendador' and v_target.status = 'pendiente') then
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
declare v_pct numeric;
begin
  if tg_op = 'INSERT' then
    select commission_pct into v_pct from public.profiles where id = new.seller_id;
    new.commission_pct := coalesce(v_pct, 0);
  else
    new.commission_pct := old.commission_pct;
  end if;
  new.commission_amount := round(new.amount * new.commission_pct / 100, 2);
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
      'Obsequios ' || new.status, coalesce(v_name,'Un vendedor') || ' ' ||
      case when new.status = 'aceptado' then 'acepto' else 'rechazo' end || ' ' || new.quantity || ' x ' || new.gift_name || '.');
  end if;
  return new;
end $$;
drop trigger if exists gift_assign_notify on public.gift_assignments;
create trigger gift_assign_notify after insert or update on public.gift_assignments
  for each row execute function public.gift_assign_notify();

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
  using (id = auth.uid() or (group_id = public.my_group() and public.is_manager()));
drop policy if exists profiles_update on public.profiles;
create policy profiles_update on public.profiles for update to authenticated
  using (id = auth.uid() or (group_id = public.my_group() and public.is_manager()))
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
  using (group_id = public.my_group() and (public.is_manager() or seller_id = auth.uid()));
drop policy if exists sales_insert on public.sales;
create policy sales_insert on public.sales for insert to authenticated
  with check (group_id = public.my_group() and (seller_id = auth.uid() or public.is_manager()));
drop policy if exists sales_update on public.sales;
create policy sales_update on public.sales for update to authenticated
  using (group_id = public.my_group() and (public.is_manager() or seller_id = auth.uid()))
  with check (group_id = public.my_group());
drop policy if exists sales_delete on public.sales;
create policy sales_delete on public.sales for delete to authenticated
  using (group_id = public.my_group() and (public.is_manager() or seller_id = auth.uid()));

-- referrals
drop policy if exists refs_select on public.referrals;
create policy refs_select on public.referrals for select to authenticated
  using (group_id = public.my_group() and (public.is_manager() or seller_id = auth.uid()));
drop policy if exists refs_insert on public.referrals;
create policy refs_insert on public.referrals for insert to authenticated
  with check (group_id = public.my_group() and (seller_id = auth.uid() or public.is_manager()));
drop policy if exists refs_update on public.referrals;
create policy refs_update on public.referrals for update to authenticated
  using (group_id = public.my_group() and (public.is_manager() or seller_id = auth.uid()))
  with check (group_id = public.my_group());
drop policy if exists refs_delete on public.referrals;
create policy refs_delete on public.referrals for delete to authenticated
  using (group_id = public.my_group() and (public.is_manager() or seller_id = auth.uid()));

-- gift_assignments (solo el admin asigna; el vendedor acepta/rechaza las suyas)
drop policy if exists gifta_select on public.gift_assignments;
create policy gifta_select on public.gift_assignments for select to authenticated
  using (group_id = public.my_group() and (public.is_manager() or seller_id = auth.uid()));
drop policy if exists gifta_insert on public.gift_assignments;
create policy gifta_insert on public.gift_assignments for insert to authenticated
  with check (group_id = public.my_group() and public.is_admin() and created_by = auth.uid());
drop policy if exists gifta_update on public.gift_assignments;
create policy gifta_update on public.gift_assignments for update to authenticated
  using (group_id = public.my_group() and (public.is_admin() or seller_id = auth.uid()))
  with check (group_id = public.my_group());
drop policy if exists gifta_delete on public.gift_assignments;
create policy gifta_delete on public.gift_assignments for delete to authenticated
  using (group_id = public.my_group() and public.is_admin());

-- gift_deliveries
drop policy if exists giftd_select on public.gift_deliveries;
create policy giftd_select on public.gift_deliveries for select to authenticated
  using (group_id = public.my_group() and (public.is_manager() or seller_id = auth.uid()));
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

-- ---------- Permisos de tabla ---------------------------------------------
grant usage on schema public to anon, authenticated;
grant select, insert, update, delete on all tables in schema public to authenticated;
revoke all on all tables in schema public from anon;
