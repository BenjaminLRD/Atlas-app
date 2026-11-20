-- ============================================================================
-- Community: posts, likes, comments, blocks and reports.
--
-- Blocking is enforced in the database: a viewer never receives posts or
-- comments from someone they blocked or who blocked them. A post reported by
-- three different people is hidden until a moderator reviews it
-- (community_review_queue). Authors' public name and rank come from
-- ranked_profiles.
-- ============================================================================

CREATE TABLE IF NOT EXISTS public.community_posts (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    type TEXT NOT NULL,
    title TEXT NOT NULL DEFAULT '' CHECK (char_length(title) <= 140),
    description TEXT NOT NULL DEFAULT '' CHECK (char_length(description) <= 2000),
    images TEXT[] NOT NULL DEFAULT '{}',
    metadata JSONB NOT NULL DEFAULT '{}'::jsonb,
    likes_count INTEGER NOT NULL DEFAULT 0,
    comments_count INTEGER NOT NULL DEFAULT 0,
    report_count INTEGER NOT NULL DEFAULT 0,
    hidden BOOLEAN NOT NULL DEFAULT FALSE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT TIMEZONE('utc'::text, NOW())
);
CREATE INDEX IF NOT EXISTS idx_community_posts_created ON public.community_posts (created_at DESC);

CREATE TABLE IF NOT EXISTS public.community_likes (
    post_id UUID NOT NULL REFERENCES public.community_posts(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT TIMEZONE('utc'::text, NOW()),
    PRIMARY KEY (post_id, user_id)
);

CREATE TABLE IF NOT EXISTS public.community_comments (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    post_id UUID NOT NULL REFERENCES public.community_posts(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    body TEXT NOT NULL CHECK (char_length(body) BETWEEN 1 AND 1000),
    hidden BOOLEAN NOT NULL DEFAULT FALSE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT TIMEZONE('utc'::text, NOW())
);
CREATE INDEX IF NOT EXISTS idx_community_comments_post ON public.community_comments (post_id, created_at);

CREATE TABLE IF NOT EXISTS public.user_blocks (
    blocker_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    blocked_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT TIMEZONE('utc'::text, NOW()),
    PRIMARY KEY (blocker_id, blocked_id),
    CHECK (blocker_id <> blocked_id)
);

CREATE TABLE IF NOT EXISTS public.content_reports (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    reporter_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    post_id UUID REFERENCES public.community_posts(id) ON DELETE CASCADE,
    comment_id UUID REFERENCES public.community_comments(id) ON DELETE CASCADE,
    reason TEXT NOT NULL CHECK (char_length(reason) BETWEEN 1 AND 500),
    status TEXT NOT NULL DEFAULT 'open' CHECK (status IN ('open', 'actioned', 'dismissed')),
    created_at TIMESTAMPTZ NOT NULL DEFAULT TIMEZONE('utc'::text, NOW()),
    CHECK ((post_id IS NULL) <> (comment_id IS NULL))
);
CREATE UNIQUE INDEX IF NOT EXISTS uq_content_reports_post
    ON public.content_reports (reporter_id, post_id) WHERE post_id IS NOT NULL;
CREATE UNIQUE INDEX IF NOT EXISTS uq_content_reports_comment
    ON public.content_reports (reporter_id, comment_id) WHERE comment_id IS NOT NULL;

-- True when either user has blocked the other.
CREATE OR REPLACE FUNCTION public.is_blocked_between(a UUID, b UUID)
RETURNS BOOLEAN
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
    SELECT EXISTS (
        SELECT 1 FROM public.user_blocks
        WHERE (blocker_id = a AND blocked_id = b)
           OR (blocker_id = b AND blocked_id = a)
    );
$$;

-- ---------------------------------------------------------------------------
-- Row Level Security
-- ---------------------------------------------------------------------------
ALTER TABLE public.community_posts ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Visible posts" ON public.community_posts;
CREATE POLICY "Visible posts" ON public.community_posts FOR SELECT TO authenticated
    USING (
        user_id = auth.uid()
        OR (NOT hidden AND NOT public.is_blocked_between(auth.uid(), user_id))
    );
DROP POLICY IF EXISTS "Authors create posts" ON public.community_posts;
CREATE POLICY "Authors create posts" ON public.community_posts FOR INSERT TO authenticated
    WITH CHECK (user_id = auth.uid());
DROP POLICY IF EXISTS "Authors delete posts" ON public.community_posts;
CREATE POLICY "Authors delete posts" ON public.community_posts FOR DELETE TO authenticated
    USING (user_id = auth.uid());
-- No UPDATE policy: counters, hidden and report_count are server-managed.

ALTER TABLE public.community_likes ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Read likes" ON public.community_likes;
CREATE POLICY "Read likes" ON public.community_likes FOR SELECT TO authenticated USING (true);
DROP POLICY IF EXISTS "Like as yourself" ON public.community_likes;
CREATE POLICY "Like as yourself" ON public.community_likes FOR INSERT TO authenticated
    WITH CHECK (user_id = auth.uid());
DROP POLICY IF EXISTS "Unlike your own" ON public.community_likes;
CREATE POLICY "Unlike your own" ON public.community_likes FOR DELETE TO authenticated
    USING (user_id = auth.uid());

ALTER TABLE public.community_comments ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Visible comments" ON public.community_comments;
CREATE POLICY "Visible comments" ON public.community_comments FOR SELECT TO authenticated
    USING (
        user_id = auth.uid()
        OR (NOT hidden AND NOT public.is_blocked_between(auth.uid(), user_id))
    );
DROP POLICY IF EXISTS "Comment as yourself" ON public.community_comments;
CREATE POLICY "Comment as yourself" ON public.community_comments FOR INSERT TO authenticated
    WITH CHECK (
        user_id = auth.uid()
        AND NOT public.is_blocked_between(
            auth.uid(),
            (SELECT p.user_id FROM public.community_posts p WHERE p.id = post_id)
        )
    );
DROP POLICY IF EXISTS "Delete your comments" ON public.community_comments;
CREATE POLICY "Delete your comments" ON public.community_comments FOR DELETE TO authenticated
    USING (user_id = auth.uid());

ALTER TABLE public.user_blocks ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Manage your blocks" ON public.user_blocks;
CREATE POLICY "Manage your blocks" ON public.user_blocks FOR ALL TO authenticated
    USING (blocker_id = auth.uid()) WITH CHECK (blocker_id = auth.uid());

ALTER TABLE public.content_reports ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "File reports as yourself" ON public.content_reports;
CREATE POLICY "File reports as yourself" ON public.content_reports FOR INSERT TO authenticated
    WITH CHECK (reporter_id = auth.uid() AND status = 'open');
DROP POLICY IF EXISTS "See your reports" ON public.content_reports;
CREATE POLICY "See your reports" ON public.content_reports FOR SELECT TO authenticated
    USING (reporter_id = auth.uid());

-- ---------------------------------------------------------------------------
-- Counters and auto-hide
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.community_likes_count()
RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
    UPDATE public.community_posts
    SET likes_count = (SELECT COUNT(*) FROM public.community_likes WHERE post_id = COALESCE(NEW.post_id, OLD.post_id))
    WHERE id = COALESCE(NEW.post_id, OLD.post_id);
    RETURN NULL;
END;
$$;
DROP TRIGGER IF EXISTS community_likes_count ON public.community_likes;
CREATE TRIGGER community_likes_count AFTER INSERT OR DELETE ON public.community_likes
    FOR EACH ROW EXECUTE FUNCTION public.community_likes_count();

CREATE OR REPLACE FUNCTION public.community_comments_count()
RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
    UPDATE public.community_posts
    SET comments_count = (
        SELECT COUNT(*) FROM public.community_comments
        WHERE post_id = COALESCE(NEW.post_id, OLD.post_id) AND NOT hidden
    )
    WHERE id = COALESCE(NEW.post_id, OLD.post_id);
    RETURN NULL;
END;
$$;
DROP TRIGGER IF EXISTS community_comments_count ON public.community_comments;
CREATE TRIGGER community_comments_count AFTER INSERT OR DELETE OR UPDATE OF hidden ON public.community_comments
    FOR EACH ROW EXECUTE FUNCTION public.community_comments_count();

-- Three distinct reports hide the content until a moderator decides.
CREATE OR REPLACE FUNCTION public.content_reports_threshold()
RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
    v_reports INTEGER;
BEGIN
    IF NEW.post_id IS NOT NULL THEN
        SELECT COUNT(*) INTO v_reports FROM public.content_reports
        WHERE post_id = NEW.post_id AND status = 'open';
        UPDATE public.community_posts
        SET report_count = v_reports, hidden = hidden OR v_reports >= 3
        WHERE id = NEW.post_id;
    ELSE
        SELECT COUNT(*) INTO v_reports FROM public.content_reports
        WHERE comment_id = NEW.comment_id AND status = 'open';
        IF v_reports >= 3 THEN
            UPDATE public.community_comments SET hidden = TRUE WHERE id = NEW.comment_id;
        END IF;
    END IF;
    RETURN NULL;
END;
$$;
DROP TRIGGER IF EXISTS content_reports_threshold ON public.content_reports;
CREATE TRIGGER content_reports_threshold AFTER INSERT ON public.content_reports
    FOR EACH ROW EXECUTE FUNCTION public.content_reports_threshold();

-- Moderators work through this in the dashboard: set the post or comment's
-- hidden flag, then mark the reports 'actioned' or 'dismissed'.
CREATE OR REPLACE VIEW public.community_review_queue
WITH (security_invoker = true) AS
SELECT r.id AS report_id, r.reason, r.created_at AS reported_at,
       r.post_id, p.title, p.description, p.images, p.user_id AS post_author,
       p.report_count, p.hidden AS post_hidden,
       r.comment_id, c.body AS comment_body, c.user_id AS comment_author
FROM public.content_reports r
LEFT JOIN public.community_posts p ON p.id = r.post_id
LEFT JOIN public.community_comments c ON c.id = r.comment_id
WHERE r.status = 'open'
ORDER BY r.created_at;

-- ---------------------------------------------------------------------------
-- Post photos: public read (the feed shows them), uploads into your folder.
-- ---------------------------------------------------------------------------
INSERT INTO storage.buckets (id, name, public)
VALUES ('community-photos', 'community-photos', true)
ON CONFLICT (id) DO NOTHING;

DROP POLICY IF EXISTS "Users upload their own community photos" ON storage.objects;
CREATE POLICY "Users upload their own community photos" ON storage.objects
    FOR INSERT TO authenticated
    WITH CHECK (
        bucket_id = 'community-photos'
        AND (storage.foldername(name))[1] = auth.uid()::text
    );

DROP POLICY IF EXISTS "Users delete their own community photos" ON storage.objects;
CREATE POLICY "Users delete their own community photos" ON storage.objects
    FOR DELETE TO authenticated
    USING (
        bucket_id = 'community-photos'
        AND (storage.foldername(name))[1] = auth.uid()::text
    );
