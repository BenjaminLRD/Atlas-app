-- ====================================================================
-- Aizawl Gym: Trainer & Gym Management Foundation Schema & RLS Policies
-- ====================================================================

-- 1. Create gyms table
CREATE TABLE IF NOT EXISTS public.gyms (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT NOT NULL,
  location TEXT NOT NULL,
  contact_email TEXT NOT NULL,
  contact_phone TEXT NOT NULL,
  member_count INT DEFAULT 0,
  trainer_count INT DEFAULT 0,
  created_at TIMESTAMPTZ DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- 2. Create trainer_profiles table
CREATE TABLE IF NOT EXISTS public.trainer_profiles (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  gym_id UUID NOT NULL REFERENCES public.gyms(id) ON DELETE CASCADE,
  display_name TEXT NOT NULL,
  specializations TEXT[] DEFAULT '{}',
  assigned_member_ids UUID[] DEFAULT '{}',
  bio TEXT DEFAULT '',
  rating NUMERIC(3, 2) DEFAULT 5.0,
  years_experience INT DEFAULT 1,
  created_at TIMESTAMPTZ DEFAULT timezone('utc'::text, now()) NOT NULL,
  UNIQUE(user_id)
);

-- 3. Create gym_memberships table
CREATE TABLE IF NOT EXISTS public.gym_memberships (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  gym_id UUID NOT NULL REFERENCES public.gyms(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  role TEXT DEFAULT 'member' CHECK (role IN ('member', 'trainer', 'admin')),
  joined_at TIMESTAMPTZ DEFAULT timezone('utc'::text, now()) NOT NULL,
  UNIQUE(gym_id, user_id)
);

-- 4. Create trainer_assignments table
CREATE TABLE IF NOT EXISTS public.trainer_assignments (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  trainer_id UUID NOT NULL REFERENCES public.trainer_profiles(id) ON DELETE CASCADE,
  member_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  assigned_at TIMESTAMPTZ DEFAULT timezone('utc'::text, now()) NOT NULL,
  UNIQUE(trainer_id, member_id)
);

-- 5. Create coach_notes table
CREATE TABLE IF NOT EXISTS public.coach_notes (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  trainer_id UUID NOT NULL REFERENCES public.trainer_profiles(id) ON DELETE CASCADE,
  member_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  note_text TEXT NOT NULL,
  category TEXT DEFAULT 'general' CHECK (category IN ('training', 'nutrition', 'injury', 'general')),
  created_at TIMESTAMPTZ DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- ====================================================================
-- ENABLE ROW LEVEL SECURITY (RLS)
-- ====================================================================

ALTER TABLE public.gyms ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.trainer_profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.gym_memberships ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.trainer_assignments ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.coach_notes ENABLE ROW LEVEL SECURITY;

-- Gyms: Everyone authenticated can read gym info
CREATE POLICY "Allow public read access to gyms"
  ON public.gyms FOR SELECT
  TO authenticated
  USING (true);

-- Trainer Profiles: Authenticated users can view trainer profiles
CREATE POLICY "Allow authenticated users to view trainer profiles"
  ON public.trainer_profiles FOR SELECT
  TO authenticated
  USING (true);

-- Coach Notes: Trainers can read and insert notes for assigned members
CREATE POLICY "Allow trainers to view notes for assigned members"
  ON public.coach_notes FOR SELECT
  TO authenticated
  USING (
    auth.uid() IN (
      SELECT user_id FROM public.trainer_profiles WHERE id = trainer_id
    )
    OR auth.uid() = member_id
  );

CREATE POLICY "Allow trainers to insert notes"
  ON public.coach_notes FOR INSERT
  TO authenticated
  WITH CHECK (
    auth.uid() IN (
      SELECT user_id FROM public.trainer_profiles WHERE id = trainer_id
    )
  );
