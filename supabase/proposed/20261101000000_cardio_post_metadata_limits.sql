-- ============================================================================
-- PROPOSED, NOT APPLIED. Review before moving into supabase/migrations/.
--
-- Why: run and ride posts carry a route in community_posts.metadata (JSONB).
-- Today nothing bounds that column. The app sends at most 120 points, but any
-- signed-in member can insert a post straight through the REST API with a
-- much larger metadata value, which every member then downloads in the feed.
-- Row-level security decides which rows are visible, not how large they are.
--
-- What it does: limits the stored size of metadata, and for cardio posts
-- checks the shape of the route. It does not change who can see a post, so
-- the route of a post stays readable by every signed-in member who can see the
-- post: masking the start and end must therefore happen on the phone, before
-- posting (it does).
--
-- Existing rows: the checks are added NOT VALID so they only apply to new and
-- updated rows; run VALIDATE CONSTRAINT after checking old data.
-- ============================================================================

ALTER TABLE public.community_posts
    ADD CONSTRAINT community_posts_metadata_size
    CHECK (pg_column_size(metadata) <= 32768) NOT VALID;

ALTER TABLE public.community_posts
    ADD CONSTRAINT community_posts_cardio_route_shape
    CHECK (
        type <> 'cardio'
        OR NOT (metadata ? 'route')
        OR (
            jsonb_typeof(metadata -> 'route') = 'array'
            AND jsonb_array_length(metadata -> 'route') <= 200
        )
    ) NOT VALID;

-- To undo:
--   ALTER TABLE public.community_posts DROP CONSTRAINT community_posts_metadata_size;
--   ALTER TABLE public.community_posts DROP CONSTRAINT community_posts_cardio_route_shape;
