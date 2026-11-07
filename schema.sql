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
  color              text,
  goal_week          numeric(14,2),
  goal_biweek        numeric(14,2),
  goal_month         numeric(14,2),
  created_at       timestamptz not null default now()
);
alter table public.profiles alter column commission_pct set default 18;
alter table public.profiles add column if not exists avatar_url text;
alter table public.profiles add column if not exists pending_avatar_url text;
alter table public.profiles add column if not exists color text;
alter table public.profiles add column if not exists goal_week numeric(14,2);
alter table public.profiles add column if not exists goal_biweek numeric(14,2);
alter table public.profiles add column if not exists goal_month numeric(14,2);
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
  alter table public.profiles add constraint profiles_color_chk check (color is null or color ~ '^#[0-9A-Fa-f]{6}$');
exception when duplicate_object then null; end $$;
do $$ begin
  alter table public.profiles add constraint profiles_goals_chk
    check (coalesce(goal_week, 0) >= 0 and coalesce(goal_biweek, 0) >= 0 and coalesce(goal_month, 0) >= 0);
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
alter table public.appointments add column if not exists completed_at timestamptz;
alter table public.appointments add column if not exists completed_by uuid references public.profiles(id) on delete set null;
alter table public.appointments add column if not exists process_note text;
alter table public.appointments add column if not exists process_at timestamptz;
alter table public.appointments add column if not exists process_by uuid references public.profiles(id) on delete set null;
alter table public.appointments add column if not exists referrals_count integer;
alter table public.appointments add column if not exists delete_reason text;
alter table public.appointments add column if not exists delete_requested_at timestamptz;
alter table public.appointments add column if not exists delete_requested_by uuid references public.profiles(id) on delete set null;
alter table public.appointments drop constraint if exists appointments_status_check;
alter table public.appointments drop constraint if exists appointments_status_chk;
alter table public.appointments add constraint appointments_status_chk
  check (status in ('pendiente','en_proceso','venta','sin_venta','cancelada'));
do $$ begin
  alter table public.appointments add constraint appointments_refs_chk check (referrals_count is null or referrals_count >= 0);
exception when duplicate_object then null; end $$;

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
do $$ begin
  if not exists (select 1 from information_schema.columns
                 where table_schema = 'public' and table_name = 'platform_settings' and column_name = 'currency') then
    alter table public.platform_settings add column currency text not null default 'USD';
    update public.platform_settings set monthly_price = 30 where id = 1;   -- el valor anterior estaba en pesos: ajustalo en control.html
  end if;
end $$;
do $$ begin
  alter table public.platform_settings add constraint platform_currency_chk check (currency in ('USD','COP'));
exception when duplicate_object then null; end $$;
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
alter table public.subscriptions add column if not exists custom_price numeric(14,2);
alter table public.subscriptions add column if not exists custom_currency text;
do $$ begin
  alter table public.subscriptions add constraint subs_custom_chk
    check ((custom_price is null or custom_price >= 0) and (custom_currency is null or custom_currency in ('USD','COP')));
exception when duplicate_object then null; end $$;
do $$ begin
  if not exists (select 1 from information_schema.columns
                 where table_schema = 'public' and table_name = 'payments' and column_name = 'currency') then
    alter table public.payments add column currency text;
    update public.payments set currency = 'COP' where currency is null;   -- los pagos anteriores eran en pesos
    alter table public.payments alter column currency set default 'USD';
    alter table public.payments alter column currency set not null;
  end if;
end $$;

-- Historial de cambios de administrador de cada grupo (lo ve el dueño en control.html)
create table if not exists public.admin_changes (
  id             uuid primary key default gen_random_uuid(),
  group_id       uuid not null references public.groups(id) on delete cascade,
  old_admin_id   uuid,
  old_admin_name text,
  new_admin_id   uuid,
  new_admin_name text,
  changed_at     timestamptz not null default now()
);
create index if not exists admin_changes_group_idx on public.admin_changes(group_id, changed_at desc);

-- Cotizaciones guardadas. Los valores calculados los fija el servidor (ver quotes_calc)
create table if not exists public.quotes (
  id                 uuid primary key default gen_random_uuid(),
  group_id           uuid not null references public.groups(id) on delete cascade,
  seller_id          uuid references public.profiles(id) on delete set null,
  number             integer,
  client_name        text,
  client_phone       text,
  notes              text,
  total              numeric(14,0) not null,        -- precio total del producto, IVA incluido
  shipping           numeric(14,0) not null default 0,  -- costo de envio, IVA incluido
  purchase_price     numeric(14,0),                 -- precio de compra sin IVA
  shipping_net       numeric(14,0),                 -- envio sin IVA
  iva                numeric(14,0),
  grand_total        numeric(14,0),                 -- precio total = producto + envio
  deposit_total      numeric(14,0) not null,        -- deposito acordado (minimo 5 %)
  deposit_today      numeric(14,0),                 -- parte que paga hoy
  deposit_extra      numeric(14,0),                 -- parte que paga despues (30 o 60 dias)
  deposit_extra_days integer,
  balance            numeric(14,0),                 -- saldo a financiar
  installments       integer not null,
  monthly_pct        numeric(6,2),
  monthly_payment    numeric(14,0),
  created_at         timestamptz not null default now()
);
create index if not exists quotes_group_idx on public.quotes(group_id, created_at desc);
create index if not exists quotes_seller_idx on public.quotes(seller_id, created_at desc);

-- Avisos del dueño de la plataforma para todos los usuarios (se publican desde control.html)
create table if not exists public.announcements (
  id         uuid primary key default gen_random_uuid(),
  title      text not null check (char_length(title) between 1 and 120),
  body       text not null check (char_length(body) between 1 and 2000),
  starts_at  timestamptz not null default now(),
  ends_at    timestamptz not null,
  paused     boolean not null default false,
  created_at timestamptz not null default now(),
  check (ends_at > starts_at)
);
create table if not exists public.announcement_reads (
  announcement_id uuid not null references public.announcements(id) on delete cascade,
  user_id         uuid not null references public.profiles(id) on delete cascade,
  read_at         timestamptz not null default now(),
  primary key (announcement_id, user_id)
);

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
    -- el admin no puede quitarse a si mismo el cargo ni cambiar de grupo, ni dar el cargo de
    -- admin por esta via: para eso existe transfer_admin() (que activa app.transfer)
    if coalesce(current_setting('app.transfer', true), '') <> '1' then
      if old.id = auth.uid() then new.role := old.role; new.status := old.status; end if;
      if new.role = 'admin' and old.role <> 'admin' then
        raise exception 'Para dar la administracion usa "Dar la administracion"';
      end if;
    end if;
    new.group_id := old.group_id;
    new.id := old.id;
    -- avisar al vendedor si se le rechaza la baja o cambian cargo/comision
    if old.delete_requested and not new.delete_requested and old.id <> auth.uid() then
      insert into public.notifications(group_id, user_id, type, title, body)
        values (old.group_id, old.id, 'baja', 'Solicitud de baja rechazada', 'El administrador rechazo tu solicitud de eliminar la cuenta.');
    end if;
    if old.role <> new.role and coalesce(current_setting('app.transfer', true), '') <> '1' then
      insert into public.notifications(group_id, user_id, type, title, body)
        values (old.group_id, old.id, 'cargo', 'Cambio de cargo', 'Tu cargo ahora es: ' || case new.role when 'vendedor' then 'emprendedor' else new.role end || '.');
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
    new.color := old.color;                -- el color en la agenda lo asigna el admin
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

-- Cotizador: porcentaje del saldo a financiar segun el numero de cuotas (2 a 27)
create or replace function public.quote_pct(p_n integer) returns numeric
language sql immutable as $$
  select (array[51.63, 34.79, 26.38, 21.33, 17.96, 15.56, 13.76, 12.36, 11.24, 10.33, 9.56, 8.92, 8.37,
                7.89, 7.47, 7.11, 6.78, 6.49, 6.22, 5.99, 5.77, 5.58, 5.40, 5.18, 5.03, 5.00])[p_n - 1]
  where p_n between 2 and 27
$$;

-- Cotizador: el servidor calcula y valida todo (IVA 19 %, deposito minimo 5 %, cuota mensual)
create or replace function public.quotes_calc() returns trigger
language plpgsql security definer set search_path = public as $$
declare v_min numeric;
begin
  new.seller_id := auth.uid();
  new.number := coalesce((select max(number) from public.quotes where group_id = new.group_id), 0) + 1;
  new.total := round(coalesce(new.total, 0));
  new.shipping := round(coalesce(new.shipping, 0));
  if new.total <= 0 then raise exception 'Escribe el precio total'; end if;
  new.purchase_price := floor(new.total * 100 / 119);      -- sin IVA, redondeado hacia abajo como en la planilla
  new.shipping_net := floor(new.shipping * 100 / 119);
  new.grand_total := new.total + new.shipping;
  new.iva := new.grand_total - new.purchase_price - new.shipping_net;
  v_min := ceil(new.grand_total / 20);
  new.deposit_total := round(coalesce(new.deposit_total, v_min));
  if new.deposit_total < v_min then
    raise exception 'El deposito minimo es el 5 por ciento: %', v_min;
  end if;
  if new.deposit_total >= new.grand_total then
    raise exception 'El deposito debe ser menor al precio total';
  end if;
  new.deposit_today := round(coalesce(new.deposit_today, new.deposit_total));
  if new.deposit_today < 1 or new.deposit_today > new.deposit_total then
    raise exception 'Lo que paga hoy no es valido';
  end if;
  new.deposit_extra := new.deposit_total - new.deposit_today;
  if new.deposit_extra > 0 then
    if new.deposit_extra_days not in (30, 60) then raise exception 'El deposito adicional es a 30 o 60 dias'; end if;
  else
    new.deposit_extra_days := null;
  end if;
  new.balance := new.grand_total - new.deposit_total;
  new.monthly_pct := public.quote_pct(new.installments);
  if new.monthly_pct is null then raise exception 'El numero de cuotas debe estar entre 2 y 27'; end if;
  new.monthly_payment := round(new.balance * new.monthly_pct / 100);
  return new;
end $$;
drop trigger if exists quotes_calc on public.quotes;
create trigger quotes_calc before insert on public.quotes
  for each row execute function public.quotes_calc();

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

-- Cita completada: la hora y quien la completo las pone el servidor; se avisa al admin
create or replace function public.appointments_completed() returns trigger
language plpgsql security definer set search_path = public as $$
declare v_name text;
begin
  if old.completed_at is null and new.completed_at is not null then
    new.completed_at := now();
    new.completed_by := auth.uid();
    if not public.is_admin() then
      select full_name into v_name from public.profiles where id = auth.uid();
      perform public.notify_managers(new.group_id, 'completada', 'Cita completada',
        coalesce(v_name, 'Un emprendedor') || ' completo la cita con ' || new.client_name || '.');
    end if;
  elsif old.completed_at is not null and new.completed_at is null then
    new.completed_by := null;
  else
    new.completed_at := old.completed_at;
    new.completed_by := old.completed_by;
  end if;
  return new;
end $$;
drop trigger if exists appointments_completed on public.appointments;
create trigger appointments_completed before update on public.appointments
  for each row execute function public.appointments_completed();

-- Avisa a los roles indicados (menos a quien hizo la accion)
create or replace function public.notify_roles(p_group uuid, p_roles text[], p_type text, p_title text, p_body text, p_except uuid)
returns void language sql security definer set search_path = public as $$
  insert into public.notifications(group_id, user_id, type, title, body)
  select p_group, id, p_type, p_title, p_body from public.profiles
  where group_id = p_group and status = 'activo' and role = any(p_roles) and id is distinct from p_except
$$;

-- Venta en proceso (con nota), solicitud de eliminacion (con motivo) y referidos registrados
create or replace function public.appointments_flow() returns trigger
language plpgsql security definer set search_path = public as $$
declare v_name text;
begin
  select full_name into v_name from public.profiles where id = auth.uid();
  v_name := coalesce(v_name, 'Un emprendedor');

  -- venta en proceso: la nota es obligatoria; el autor y la hora los pone el servidor
  if new.status = 'en_proceso' and (old.status is distinct from 'en_proceso' or new.process_note is distinct from old.process_note) then
    if coalesce(trim(new.process_note), '') = '' then
      raise exception 'Escribe en que quedo el proceso de la venta';
    end if;
    new.process_at := now(); new.process_by := auth.uid();
    perform public.notify_roles(new.group_id, array['admin'], 'proceso', 'Venta en proceso',
      v_name || ' dejo una nota sobre la venta con ' || new.client_name || ': ' || left(new.process_note, 160), auth.uid());
  else
    new.process_note := old.process_note; new.process_at := old.process_at; new.process_by := old.process_by;
  end if;

  -- eliminacion: el emprendedor la solicita con un motivo; admin o agendador la aprueban o la rechazan
  if new.delete_reason is not null and old.delete_reason is null then
    if trim(new.delete_reason) = '' then raise exception 'Escribe el motivo para eliminar la cita'; end if;
    new.delete_requested_at := now(); new.delete_requested_by := auth.uid();
    perform public.notify_roles(new.group_id, array['admin','agendador'], 'eliminacion', 'Solicitud para eliminar una cita',
      v_name || ' pide eliminar la cita con ' || new.client_name || '. Motivo: ' || left(new.delete_reason, 160), auth.uid());
  elsif new.delete_reason is null and old.delete_reason is not null then
    new.delete_requested_at := null; new.delete_requested_by := null;
    if old.delete_requested_by is not null and old.delete_requested_by is distinct from auth.uid()
       and exists (select 1 from public.profiles where id = old.delete_requested_by) then
      insert into public.notifications(group_id, user_id, type, title, body)
        values (new.group_id, old.delete_requested_by, 'eliminacion', 'Eliminacion rechazada',
                'No se aprobo eliminar la cita con ' || new.client_name || '.');
    end if;
  else
    new.delete_reason := old.delete_reason; new.delete_requested_at := old.delete_requested_at;
    new.delete_requested_by := old.delete_requested_by;
  end if;

  -- referidos: se registra la cantidad y se avisa al admin y al agendador
  if new.referrals_count is distinct from old.referrals_count and coalesce(new.referrals_count, 0) > 0 then
    perform public.notify_roles(new.group_id, array['admin','agendador'], 'referidos', 'Referidos registrados',
      v_name || ' registro ' || new.referrals_count || ' referido(s) de la cita con ' || new.client_name
      || '. Debe enviar la imagen de los referidos.', auth.uid());
  end if;
  return new;
end $$;
drop trigger if exists appointments_flow on public.appointments;
create trigger appointments_flow before update on public.appointments
  for each row execute function public.appointments_flow();

-- Si se aprueba la eliminacion, el emprendedor recibe el aviso
create or replace function public.appointments_deleted() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  if old.delete_reason is not null and old.seller_id is not null
     and exists (select 1 from public.profiles where id = old.seller_id)
     and exists (select 1 from public.groups where id = old.group_id) then
    insert into public.notifications(group_id, user_id, type, title, body)
      values (old.group_id, old.seller_id, 'eliminacion', 'Cita eliminada',
              'Se aprobo eliminar la cita con ' || old.client_name || '.');
  end if;
  return old;
end $$;
drop trigger if exists appointments_deleted on public.appointments;
create trigger appointments_deleted after delete on public.appointments
  for each row execute function public.appointments_deleted();

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
alter table public.admin_changes    enable row level security;
alter table public.quotes           enable row level security;
alter table public.announcements    enable row level security;
alter table public.announcement_reads enable row level security;

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
  using (group_id = public.my_group() and public.is_manager());   -- los emprendedores piden la eliminacion

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

-- quotes: cada quien ve las suyas; el administrador ve todas las del grupo
drop policy if exists quotes_select on public.quotes;
create policy quotes_select on public.quotes for select to authenticated
  using (group_id = public.my_group() and (public.is_admin() or seller_id = auth.uid()));
drop policy if exists quotes_insert on public.quotes;
create policy quotes_insert on public.quotes for insert to authenticated
  with check (group_id = public.my_group());
drop policy if exists quotes_delete on public.quotes;
create policy quotes_delete on public.quotes for delete to authenticated
  using (group_id = public.my_group() and (public.is_admin() or seller_id = auth.uid()));

-- platform_owner: cada quien solo puede ver si es el dueño
drop policy if exists owner_select on public.platform_owner;
create policy owner_select on public.platform_owner for select to authenticated
  using (user_id = auth.uid());

-- ---------- Funciones para la app -----------------------------------------

-- Miembros activos de mi grupo (nombre y cargo), para chats y asignaciones
drop function if exists public.group_members();
create or replace function public.group_members()
returns table(id uuid, full_name text, role text, avatar_url text, color text)
language sql stable security definer set search_path = public as $$
  select p.id, p.full_name, p.role, p.avatar_url, p.color from public.profiles p
  where p.group_id = public.my_group() and p.status = 'activo'
  order by p.full_name
$$;
grant execute on function public.group_members() to authenticated;

-- El administrador "registrado" del grupo siempre sigue al cargo real, sin importar como cambie
create or replace function public.groups_admin_changed() returns trigger
language plpgsql security definer set search_path = public as $$
declare v_old text; v_new text;
begin
  select full_name into v_old from public.profiles where id = old.admin_id;
  select full_name into v_new from public.profiles where id = new.admin_id;
  insert into public.admin_changes(group_id, old_admin_id, old_admin_name, new_admin_id, new_admin_name)
    values (new.id, old.admin_id, v_old, new.admin_id, v_new);
  return new;
end $$;
drop trigger if exists groups_admin_changed on public.groups;
create trigger groups_admin_changed after update of admin_id on public.groups
  for each row when (old.admin_id is distinct from new.admin_id)
  execute function public.groups_admin_changed();

create or replace function public.sync_group_admin() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  if new.role = 'admin' and old.role <> 'admin' then
    update public.groups set admin_id = new.id where id = new.group_id and admin_id is distinct from new.id;
  elsif old.role = 'admin' and new.role <> 'admin' then
    -- si era el administrador registrado, pasa al otro administrador del grupo (si lo hay)
    update public.groups set admin_id = coalesce(
        (select p.id from public.profiles p where p.group_id = new.group_id and p.role = 'admin'
           and p.status = 'activo' and p.id <> new.id order by p.created_at desc limit 1), admin_id)
      where id = new.group_id and admin_id = new.id;
  end if;
  return new;
end $$;
drop trigger if exists sync_group_admin on public.profiles;
create trigger sync_group_admin after update of role on public.profiles
  for each row when (old.role is distinct from new.role)
  execute function public.sync_group_admin();

-- Transferir la administracion del grupo a otro miembro activo.
-- El administrador actual pasa a ser emprendedor; la mensualidad sigue siendo del grupo.
create or replace function public.transfer_admin(p_user uuid) returns void
language plpgsql security definer set search_path = public as $$
declare v_me public.profiles; v_to public.profiles;
begin
  select * into v_me from public.profiles where id = auth.uid() and role = 'admin' and status = 'activo';
  if v_me.id is null or v_me.group_id is distinct from public.my_group() then
    raise exception 'Solo el administrador puede dar la administracion';
  end if;
  select * into v_to from public.profiles where id = p_user;
  if v_to.id is null or v_to.group_id <> v_me.group_id or v_to.status <> 'activo' then
    raise exception 'Esa persona no es un miembro activo de tu grupo';
  end if;
  if v_to.id = v_me.id then raise exception 'Ya eres el administrador'; end if;

  perform set_config('app.transfer', '1', true);
  update public.profiles set role = 'admin' where id = v_to.id;
  update public.profiles set role = 'vendedor' where id = v_me.id;
  perform set_config('app.transfer', '', true);
  update public.groups set admin_id = v_to.id where id = v_me.group_id;

  insert into public.notifications(group_id, user_id, type, title, body) values
    (v_me.group_id, v_to.id, 'cargo', 'Ahora eres el administrador',
     v_me.full_name || ' te dio la administracion del grupo.'),
    (v_me.group_id, v_me.id, 'cargo', 'Administracion transferida',
     'Ahora ' || v_to.full_name || ' es el administrador y tu cargo es emprendedor.');
end $$;
grant execute on function public.transfer_admin(uuid) to authenticated;

-- Estado de la mensualidad del administrador que consulta
create or replace function public.my_subscription() returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare v_group uuid; s public.subscriptions; st public.platform_settings; v_days int; v_price numeric; v_cur text;
begin
  select group_id into v_group from public.profiles
    where id = auth.uid() and role = 'admin' and status = 'activo';
  if v_group is null then return null; end if;
  select * into st from public.platform_settings where id = 1;
  select * into s from public.subscriptions where group_id = v_group;
  v_price := coalesce(s.custom_price, st.monthly_price);
  v_cur   := case when s.custom_price is not null then coalesce(s.custom_currency, 'USD') else st.currency end;
  if s.group_id is null then
    return jsonb_build_object('blocked', false, 'price', v_price, 'currency', v_cur, 'warn_days', st.warn_days);
  end if;
  v_days := s.paid_until - public.bogota_today();
  return jsonb_build_object('blocked', s.blocked or v_days < 0, 'manual', s.blocked,
    'paid_until', s.paid_until, 'days_left', v_days, 'price', v_price, 'currency', v_cur,
    'custom', s.custom_price is not null, 'warn_days', st.warn_days);
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

drop function if exists public.owner_overview();
create or replace function public.owner_overview()
returns table(group_id uuid, group_name text, admin_id uuid, admin_name text, admin_email text,
              admin_phone text, registered_at timestamptz, paid_until date, blocked boolean,
              sellers bigint, payments_count bigint, last_payment timestamptz, paid_usd numeric, paid_cop numeric,
              prev_admin_name text, admin_changed_at timestamptz,
              price numeric, currency text, custom_price boolean)
language plpgsql stable security definer set search_path = public as $$
begin
  if not public.is_owner() then raise exception 'Sin permiso'; end if;
  return query
  select g.id, g.name, a.id, a.full_name, a.email, a.phone, s.registered_at, s.paid_until, s.blocked,
         (select count(*) from public.profiles x where x.group_id = g.id and x.role <> 'admin' and x.status = 'activo'),
         (select count(*) from public.payments y where y.group_id = g.id),
         (select max(y.paid_at) from public.payments y where y.group_id = g.id),
         (select coalesce(sum(y.amount), 0) from public.payments y where y.group_id = g.id and y.currency = 'USD'),
         (select coalesce(sum(y.amount), 0) from public.payments y where y.group_id = g.id and y.currency = 'COP'),
         ch.old_admin_name, ch.changed_at,
         coalesce(s.custom_price, st.monthly_price),
         case when s.custom_price is not null then coalesce(s.custom_currency, 'USD') else st.currency end,
         s.custom_price is not null
  from public.groups g
  join public.subscriptions s on s.group_id = g.id
  cross join (select * from public.platform_settings where id = 1) st
  left join lateral (select x.id, x.full_name, x.email, x.phone from public.profiles x
                     where x.group_id = g.id and x.role = 'admin' and x.status = 'activo'
                     order by (x.id = g.admin_id) desc, x.created_at desc limit 1) a on true
  left join lateral (select c.old_admin_name, c.changed_at from public.admin_changes c
                     where c.group_id = g.id order by c.changed_at desc limit 1) ch on true
  order by s.registered_at desc;
end $$;
grant execute on function public.owner_overview() to authenticated;

create or replace function public.owner_admin_changes(p_group uuid) returns setof public.admin_changes
language plpgsql stable security definer set search_path = public as $$
begin
  if not public.is_owner() then raise exception 'Sin permiso'; end if;
  return query select * from public.admin_changes where group_id = p_group order by changed_at desc;
end $$;
grant execute on function public.owner_admin_changes(uuid) to authenticated;

create or replace function public.owner_payments(p_group uuid) returns setof public.payments
language plpgsql stable security definer set search_path = public as $$
begin
  if not public.is_owner() then raise exception 'Sin permiso'; end if;
  return query select * from public.payments where group_id = p_group order by paid_at desc;
end $$;
grant execute on function public.owner_payments(uuid) to authenticated;

create or replace function public.owner_mark_paid(p_group uuid, p_amount numeric, p_months int, p_note text)
returns void language plpgsql security definer set search_path = public as $$
declare s public.subscriptions; v_new date; v_admin uuid; v_cur text;
begin
  if not public.is_owner() then raise exception 'Sin permiso'; end if;
  if p_months is null or p_months < 1 then raise exception 'Meses invalidos'; end if;
  select * into s from public.subscriptions where group_id = p_group;
  if s.group_id is null then raise exception 'Grupo no encontrado'; end if;
  v_cur := case when s.custom_price is not null then coalesce(s.custom_currency, 'USD')
                else (select currency from public.platform_settings where id = 1) end;
  v_new := (greatest(s.paid_until, public.bogota_today()) + make_interval(months => p_months))::date;
  update public.subscriptions set paid_until = v_new, blocked = false where group_id = p_group;
  insert into public.payments(group_id, amount, currency, months, period_end, note)
    values (p_group, coalesce(p_amount, 0), v_cur, p_months, v_new, nullif(trim(p_note), ''));
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

drop function if exists public.owner_update_settings(numeric, int, int);
create or replace function public.owner_update_settings(p_price numeric, p_first_days int, p_warn_days int, p_currency text)
returns void language plpgsql security definer set search_path = public as $$
begin
  if not public.is_owner() then raise exception 'Sin permiso'; end if;
  if p_price < 0 or p_first_days < 0 or p_warn_days < 0 then raise exception 'Valores invalidos'; end if;
  if p_currency not in ('USD','COP') then raise exception 'Moneda invalida'; end if;
  update public.platform_settings
    set monthly_price = p_price, first_payment_days = p_first_days, warn_days = p_warn_days, currency = p_currency where id = 1;
end $$;
grant execute on function public.owner_update_settings(numeric, int, int, text) to authenticated;

-- Precio personalizado de un administrador (p_price nulo = vuelve al precio general)
create or replace function public.owner_set_price(p_group uuid, p_price numeric, p_currency text)
returns void language plpgsql security definer set search_path = public as $$
begin
  if not public.is_owner() then raise exception 'Sin permiso'; end if;
  if p_price is not null and (p_price < 0 or coalesce(p_currency, 'USD') not in ('USD','COP')) then
    raise exception 'Valores invalidos';
  end if;
  update public.subscriptions
    set custom_price = p_price, custom_currency = case when p_price is null then null else coalesce(p_currency, 'USD') end
    where group_id = p_group;
end $$;
grant execute on function public.owner_set_price(uuid, numeric, text) to authenticated;

-- ---------- Avisos ---------------------------------------------------------

-- Avisos vigentes que la persona todavia no ha confirmado
create or replace function public.pending_announcements()
returns table(id uuid, title text, body text, starts_at timestamptz, ends_at timestamptz)
language sql stable security definer set search_path = public as $$
  select a.id, a.title, a.body, a.starts_at, a.ends_at
  from public.announcements a
  where not a.paused and now() >= a.starts_at and now() < a.ends_at
    and exists (select 1 from public.profiles p where p.id = auth.uid() and p.status = 'activo')
    and not exists (select 1 from public.announcement_reads r where r.announcement_id = a.id and r.user_id = auth.uid())
  order by a.starts_at asc
$$;
grant execute on function public.pending_announcements() to authenticated;

-- La persona confirma que leyo el aviso (no vuelve a aparecer)
create or replace function public.ack_announcement(p_id uuid) returns void
language plpgsql security definer set search_path = public as $$
begin
  if not exists (select 1 from public.profiles where id = auth.uid() and status = 'activo') then
    raise exception 'Sin permiso';
  end if;
  insert into public.announcement_reads(announcement_id, user_id)
    select a.id, auth.uid() from public.announcements a where a.id = p_id
    on conflict do nothing;
end $$;
grant execute on function public.ack_announcement(uuid) to authenticated;

-- Panel del dueño: lista de avisos con cuantas personas los han confirmado
create or replace function public.owner_announcements()
returns table(id uuid, title text, body text, starts_at timestamptz, ends_at timestamptz, paused boolean,
              created_at timestamptz, reads bigint, audience bigint)
language plpgsql stable security definer set search_path = public as $$
begin
  if not public.is_owner() then raise exception 'Sin permiso'; end if;
  return query
  select a.id, a.title, a.body, a.starts_at, a.ends_at, a.paused, a.created_at,
         (select count(*) from public.announcement_reads r where r.announcement_id = a.id),
         (select count(*) from public.profiles p where p.status = 'activo')
  from public.announcements a order by a.created_at desc;
end $$;
grant execute on function public.owner_announcements() to authenticated;

-- Crear (p_id nulo) o editar un aviso
create or replace function public.owner_save_announcement(p_id uuid, p_title text, p_body text, p_starts timestamptz, p_ends timestamptz)
returns uuid language plpgsql security definer set search_path = public as $$
declare v_id uuid;
begin
  if not public.is_owner() then raise exception 'Sin permiso'; end if;
  if coalesce(trim(p_title), '') = '' or coalesce(trim(p_body), '') = '' then raise exception 'Escribe el titulo y el mensaje'; end if;
  if p_ends is null or p_starts is null or p_ends <= p_starts then raise exception 'La fecha final debe ser posterior a la inicial'; end if;
  if p_id is null then
    insert into public.announcements(title, body, starts_at, ends_at)
      values (trim(p_title), trim(p_body), p_starts, p_ends) returning id into v_id;
  else
    update public.announcements set title = trim(p_title), body = trim(p_body), starts_at = p_starts, ends_at = p_ends
      where id = p_id returning id into v_id;
    if v_id is null then raise exception 'Aviso no encontrado'; end if;
  end if;
  return v_id;
end $$;
grant execute on function public.owner_save_announcement(uuid, text, text, timestamptz, timestamptz) to authenticated;

create or replace function public.owner_set_announcement_paused(p_id uuid, p_paused boolean) returns void
language plpgsql security definer set search_path = public as $$
begin
  if not public.is_owner() then raise exception 'Sin permiso'; end if;
  update public.announcements set paused = p_paused where id = p_id;
end $$;
grant execute on function public.owner_set_announcement_paused(uuid, boolean) to authenticated;

create or replace function public.owner_delete_announcement(p_id uuid) returns void
language plpgsql security definer set search_path = public as $$
begin
  if not public.is_owner() then raise exception 'Sin permiso'; end if;
  delete from public.announcements where id = p_id;
end $$;
grant execute on function public.owner_delete_announcement(uuid) to authenticated;

-- ---------- Datos para instalaciones anteriores ----------------------------

-- grupos que ya existian: reciben su periodo inicial de pago
insert into public.subscriptions(group_id, paid_until)
  select g.id, public.bogota_today() + (select first_payment_days from public.platform_settings where id = 1)
  from public.groups g
  where not exists (select 1 from public.subscriptions s where s.group_id = g.id);

-- referidos registrados con el formulario anterior: pasan a ser un numero por cita
alter table public.appointments disable trigger appointments_flow;
update public.appointments a set referrals_count = c.n
  from (select appointment_id, count(*)::int as n from public.referrals where appointment_id is not null group by 1) c
  where c.appointment_id = a.id and a.referrals_count is null;
alter table public.appointments enable trigger appointments_flow;

-- grupos cuyo administrador registrado ya no tiene el cargo: se apunta al administrador actual
update public.groups g set admin_id = a.id
from (select distinct on (p.group_id) p.group_id, p.id from public.profiles p
      where p.role = 'admin' and p.status = 'activo' order by p.group_id, p.created_at desc) a
where a.group_id = g.id and g.admin_id is distinct from a.id
  and not exists (select 1 from public.profiles q where q.id = g.admin_id and q.role = 'admin');

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
