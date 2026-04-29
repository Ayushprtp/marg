-- ==============================================================================
-- MAARG PROJECT - SQL SCHEMA & RBAC CONFIGURATION
-- ==============================================================================

-- 1. Create the application roles enum
CREATE TYPE public.app_role AS ENUM ('root', 'operator', 'client');

-- 2. Create the user_roles table to map Supabase Auth users to our roles
-- This references the auth.users table securely.
CREATE TABLE public.user_roles (
  id uuid references auth.users(id) on delete cascade not null primary key,
  role public.app_role not null default 'client'::public.app_role,
  created_at timestamp with time zone default timezone('utc'::text, now()) not null
);

-- Secure the user_roles table with Row Level Security (RLS)
ALTER TABLE public.user_roles ENABLE ROW LEVEL SECURITY;

-- 3. RLS Policies for user_roles
-- Users can only read their own role (Prevents IDOR)
CREATE POLICY "Users can read own role" 
  ON public.user_roles 
  FOR SELECT 
  USING (auth.uid() = id);

-- 'root' users can read all roles
CREATE POLICY "Root can read all roles" 
  ON public.user_roles 
  FOR SELECT 
  USING (
    public.has_role('root')
  );

-- 'root' users can update roles (e.g., promote a client to operator)
CREATE POLICY "Root can update roles" 
  ON public.user_roles 
  FOR UPDATE 
  USING (
    public.has_role('root')
  );

-- 4. Helper Function to easily check roles in other RLS policies
-- SECURITY DEFINER ensures it runs with privileges of the creator, allowing it to bypass RLS on user_roles for checking.
CREATE OR REPLACE FUNCTION public.has_role(role_to_check public.app_role)
RETURNS BOOLEAN
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT EXISTS (
    SELECT 1
    FROM public.user_roles
    WHERE id = auth.uid()
    AND role = role_to_check
  );
$$;

-- 5. Auto-assign default 'client' role to new users signing up via Supabase Auth
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER 
SET search_path = public
AS $$
BEGIN
  INSERT INTO public.user_roles (id, role)
  VALUES (new.id, 'client');
  RETURN new;
END;
$$;

-- Trigger to run handle_new_user when a new row is inserted into auth.users
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

-- ==============================================================================
-- EXAMPLE: How to secure a data table using the RBAC system
-- ==============================================================================

-- Example table: tasks
CREATE TABLE public.tasks (
  id uuid primary key default gen_random_uuid(),
  title text not null,
  description text,
  client_id uuid references auth.users(id) not null default auth.uid(),
  created_at timestamp with time zone default timezone('utc'::text, now()) not null
);

ALTER TABLE public.tasks ENABLE ROW LEVEL SECURITY;

-- POLICY: Clients can read and create their OWN tasks only (Prevents IDOR)
CREATE POLICY "Clients can manage their own tasks" 
  ON public.tasks
  FOR ALL 
  USING (
    auth.uid() = client_id AND public.has_role('client')
  );

-- POLICY: Operators can read and update ALL tasks
CREATE POLICY "Operators can manage all tasks" 
  ON public.tasks
  FOR ALL 
  USING (
    public.has_role('operator')
  );

-- POLICY: Root has full access to everything
CREATE POLICY "Root can do anything" 
  ON public.tasks
  FOR ALL 
  USING (
    public.has_role('root')
  );
