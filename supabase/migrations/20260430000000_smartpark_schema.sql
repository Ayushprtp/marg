-- USERS (extends Supabase auth.users)
create table public.profiles (
  id uuid references auth.users primary key,
  full_name text not null,
  phone text unique not null,
  role text not null default 'client' check (role in ('client', 'operator', 'root')),
  avatar_url text,
  created_at timestamptz default now()
);

-- VEHICLES
create table public.vehicles (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references public.profiles not null,
  plate_number text not null unique,              -- e.g. UP32QP0001
  engine_number text not null,                    -- full, stored encrypted or hashed
  chassis_number text not null,
  owner_name text,                                -- from API response
  manufacturer text,
  maker_model text,
  vehicle_class text,                             -- car_models / motorcycle etc
  vehicle_type text,                              -- 'bike','car','suv','ev'  (we derive)
  fuel_type text,
  color text,
  rc_status text,
  insurance_upto text,
  fitness_upto text,
  raw_api_response jsonb,                         -- store full API response
  verified boolean default false,
  is_default boolean default false,
  created_at timestamptz default now()
);

-- PARKING LOTS (added by operators)
create table public.parking_lots (
  id uuid primary key default gen_random_uuid(),
  operator_id uuid references public.profiles not null,
  name text not null,
  description text,
  address text,
  latitude double precision not null,
  longitude double precision not null,
  images text[],                                  -- Supabase storage URLs
  total_slots int not null,
  is_active boolean default true,
  amenities text[],                               -- ['covered', '24x7', 'cctv', 'ev_charging']
  created_at timestamptz default now()
);

-- PARKING SLOTS (individual slots within a lot)
create table public.parking_slots (
  id uuid primary key default gen_random_uuid(),
  lot_id uuid references public.parking_lots not null,
  slot_label text not null,                       -- 'A1', 'A2', 'B1' etc
  slot_row text not null,                         -- 'A', 'B' for grid display
  slot_col int not null,                          -- 1,2,3... for grid display
  vehicle_type text not null check (vehicle_type in ('bike','car','suv','ev')),
  status text not null default 'free' check (status in ('free','occupied','reserved','disabled')),
  price_per_hour decimal(10,2) not null,
  price_per_30min decimal(10,2),                  -- optional, if lot uses 30min billing
  peak_price_per_hour decimal(10,2),              -- surge pricing
  peak_hours_start time,
  peak_hours_end time,
  camera_id text,                                 -- which camera covers this slot
  last_updated timestamptz default now()
);

-- CAMERAS (registered by operators)
create table public.cameras (
  id uuid primary key default gen_random_uuid(),
  lot_id uuid references public.parking_lots not null,
  camera_label text not null,                     -- 'CAM_A', 'ENTRY_CAM'
  stream_url text not null,                       -- RTSP url or for testing: webcam index or HTTP mjpeg
  camera_type text not null check (camera_type in ('slot_cam','entry_cam','exit_cam')),
  covers_slots text[],                            -- slot labels this camera can see
  is_active boolean default true,
  is_virtual boolean default false,               -- true for OBS virtual cam / test
  created_at timestamptz default now()
);

-- BOOKINGS (pre-bookings by users)
create table public.bookings (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references public.profiles not null,
  slot_id uuid references public.parking_slots not null,
  lot_id uuid references public.parking_lots not null,
  vehicle_id uuid references public.vehicles not null,
  booked_for timestamptz not null,               -- scheduled arrival time
  grace_until timestamptz not null,              -- booked_for + 15 minutes
  status text not null default 'active' check (status in ('active','arrived','cancelled','expired')),
  created_at timestamptz default now()
);

-- PARKING SESSIONS (active + historical)
create table public.parking_sessions (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references public.profiles not null,
  slot_id uuid references public.parking_slots not null,
  lot_id uuid references public.parking_lots not null,
  vehicle_id uuid references public.vehicles,    -- nullable: matched from plate detection
  plate_detected text,                           -- raw plate from camera OCR
  booking_id uuid references public.bookings,   -- if came from a booking
  entered_at timestamptz not null default now(),
  exited_at timestamptz,
  duration_minutes int,                          -- computed on exit
  amount_due decimal(10,2),                      -- computed on exit
  amount_paid decimal(10,2) default 0,
  payment_status text default 'pending' check (payment_status in ('pending','paid','overdue','challan_issued')),
  payment_deadline timestamptz,                  -- exited_at + 48 hours
  payment_method text,
  camera_entry_snapshot text,                    -- Storage URL of frame when detected
  camera_exit_snapshot text,
  challan_issued boolean default false,
  challan_pdf_url text,
  created_at timestamptz default now()
);

-- CAMERA DETECTION EVENTS (raw events from Python worker)
create table public.camera_events (
  id uuid primary key default gen_random_uuid(),
  camera_id uuid references public.cameras not null,
  lot_id uuid references public.parking_lots not null,
  event_type text not null check (event_type in ('vehicle_parked','vehicle_unparked','plate_detected','unknown')),
  slot_label text,
  plate_text text,                               -- OCR result
  confidence decimal(4,3),
  snapshot_url text,                             -- frame that triggered event
  processed boolean default false,
  created_at timestamptz default now()
);

-- PAYMENTS
create table public.payments (
  id uuid primary key default gen_random_uuid(),
  session_id uuid references public.parking_sessions not null,
  user_id uuid references public.profiles not null,
  amount decimal(10,2) not null,
  method text,
  razorpay_order_id text,
  razorpay_payment_id text,
  status text default 'created' check (status in ('created','paid','failed')),
  created_at timestamptz default now()
);

-- ROW LEVEL SECURITY (RLS)

alter table public.profiles enable row level security;
alter table public.vehicles enable row level security;
alter table public.parking_lots enable row level security;
alter table public.parking_slots enable row level security;
alter table public.cameras enable row level security;
alter table public.bookings enable row level security;
alter table public.parking_sessions enable row level security;
alter table public.camera_events enable row level security;
alter table public.payments enable row level security;

-- Profiles Policies
create policy "Users can read own profile" on public.profiles for select using (auth.uid() = id);
create policy "Users can update own profile" on public.profiles for update using (auth.uid() = id);
create policy "Root can read all profiles" on public.profiles for select using (
  exists (select 1 from public.profiles where id = auth.uid() and role = 'root')
);

-- Vehicles Policies
create policy "Users can CRUD own vehicles" on public.vehicles for all using (auth.uid() = user_id);
create policy "Root can read all vehicles" on public.vehicles for select using (
  exists (select 1 from public.profiles where id = auth.uid() and role = 'root')
);

-- Parking Lots Policies
create policy "Clients can read active lots" on public.parking_lots for select using (is_active = true);
create policy "Operators can CRUD own lots" on public.parking_lots for all using (auth.uid() = operator_id);

-- Parking Slots Policies
create policy "Clients can read all slots" on public.parking_slots for select using (true);
create policy "Operators can CRUD slots for their lots" on public.parking_slots for all using (
  exists (select 1 from public.parking_lots where id = public.parking_slots.lot_id and operator_id = auth.uid())
);

-- Bookings Policies
create policy "Users can CRUD own bookings" on public.bookings for all using (auth.uid() = user_id);
create policy "Operators can read bookings for their lots" on public.bookings for select using (
  exists (select 1 from public.parking_lots where id = public.bookings.lot_id and operator_id = auth.uid())
);

-- Parking Sessions Policies
create policy "Users can read own sessions" on public.parking_sessions for select using (auth.uid() = user_id);
create policy "Operators can read sessions for their lots" on public.parking_sessions for select using (
  exists (select 1 from public.parking_lots where id = public.parking_sessions.lot_id and operator_id = auth.uid())
);
create policy "Root can read all sessions" on public.parking_sessions for select using (
  exists (select 1 from public.profiles where id = auth.uid() and role = 'root')
);

-- Camera Events Policies
-- Only service_role can insert events, and operators can read their lot events.
create policy "Operators can read their lot events" on public.camera_events for select using (
  exists (select 1 from public.parking_lots where id = public.camera_events.lot_id and operator_id = auth.uid())
);

-- REALTIME REPLICATION
alter publication supabase_realtime add table public.parking_slots;
alter publication supabase_realtime add table public.parking_sessions;
alter publication supabase_realtime add table public.bookings;
alter publication supabase_realtime add table public.camera_events;
