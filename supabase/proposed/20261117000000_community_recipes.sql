-- REVIEW ONLY. NOT APPLIED. Do not run without explicit approval.
--
-- Why: the Meal Prep redesign shows recipes shared by other Atlas users with
-- ratings and reviews. The app has no table for shared recipes or ratings
-- today, so in a normal (non-Showcase) session the Community recipes section
-- says it is not switched on yet and rating is disabled. Showcase Mode uses
-- bundled sample data on the device and never touches these tables.
--
-- What this adds:
--   * public.recipes          a recipe shared by its author
--   * public.recipe_ratings   one rating (and optional review) per user per recipe
--   * public.recipe_rating_summary  average and count computed from real rows
--
-- Integrity rules enforced in the database, not only in the app:
--   * a user can only create/change/delete their own recipe and their own rating
--   * a rating is 1 to 5 and there is exactly one per (recipe, user), so rating
--     again updates it and cannot inflate the score
--   * nobody can rate their own recipe
--   * averages are computed from the rows, never stored or typed in
--   * the service role key is never used by the app

create table if not exists public.recipes (
  id            uuid primary key default gen_random_uuid(),
  author_id     uuid not null default auth.uid() references public.profiles(id) on delete cascade,
  title         text not null check (char_length(title) between 1 and 60),
  description   text not null default '' check (char_length(description) <= 400),
  servings      integer not null check (servings between 1 and 20),
  prep_minutes  integer not null default 15 check (prep_minutes between 0 and 1440),
  categories    text[] not null default '{}',
  -- ingredients: [{"name": "...", "quantity": 150, "unit": "grams",
  --   "basis": "per100g", "source": "userEntry",
  --   "kcal": 165, "protein": 31, "carbs": 0, "fat": 3.6}]
  -- A missing nutrient is omitted (unknown), never 0.
  ingredients   jsonb not null check (jsonb_typeof(ingredients) = 'array'),
  steps         text[] not null default '{}',
  image_path    text,
  created_at    timestamptz not null default now(),
  updated_at    timestamptz not null default now()
);

create table if not exists public.recipe_ratings (
  recipe_id   uuid not null references public.recipes(id) on delete cascade,
  user_id     uuid not null default auth.uid() references public.profiles(id) on delete cascade,
  stars       smallint not null check (stars between 1 and 5),
  review      text check (review is null or char_length(review) <= 600),
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now(),
  primary key (recipe_id, user_id)
);

alter table public.recipes enable row level security;
alter table public.recipe_ratings enable row level security;

-- Recipes: anyone signed in can read; only the author writes.
create policy recipes_read on public.recipes
  for select to authenticated using (true);
create policy recipes_insert_own on public.recipes
  for insert to authenticated with check (author_id = auth.uid());
create policy recipes_update_own on public.recipes
  for update to authenticated using (author_id = auth.uid()) with check (author_id = auth.uid());
create policy recipes_delete_own on public.recipes
  for delete to authenticated using (author_id = auth.uid());

-- Ratings: anyone signed in can read; each user writes only their own, and not
-- for a recipe they authored.
create policy ratings_read on public.recipe_ratings
  for select to authenticated using (true);
create policy ratings_insert_own on public.recipe_ratings
  for insert to authenticated with check (
    user_id = auth.uid()
    and not exists (
      select 1 from public.recipes r
      where r.id = recipe_id and r.author_id = auth.uid()
    )
  );
create policy ratings_update_own on public.recipe_ratings
  for update to authenticated using (user_id = auth.uid())
  with check (
    user_id = auth.uid()
    and not exists (
      select 1 from public.recipes r
      where r.id = recipe_id and r.author_id = auth.uid()
    )
  );
create policy ratings_delete_own on public.recipe_ratings
  for delete to authenticated using (user_id = auth.uid());

-- Average and count from the real rows. A recipe with no rows has count 0 and
-- a null average ("no ratings yet"), which is different from a rating of 0.
create or replace view public.recipe_rating_summary
with (security_invoker = true) as
select
  recipe_id,
  count(*)::integer                 as rating_count,
  round(avg(stars)::numeric, 2)     as average_stars
from public.recipe_ratings
group by recipe_id;

create index if not exists recipes_author_idx on public.recipes (author_id);
create index if not exists recipe_ratings_recipe_idx on public.recipe_ratings (recipe_id);

-- Keep updated_at honest on edits.
create or replace function public.touch_updated_at() returns trigger
language plpgsql as $$
begin
  new.updated_at = now();
  return new;
end $$;

create trigger recipes_touch before update on public.recipes
  for each row execute function public.touch_updated_at();
create trigger recipe_ratings_touch before update on public.recipe_ratings
  for each row execute function public.touch_updated_at();

-- Not included (needs a decision): a storage bucket for recipe photos with a
-- policy that lets a user upload only under their own user id folder, and a
-- report/moderation path for shared recipes, as the community feed already has.
