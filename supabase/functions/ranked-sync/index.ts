// Supabase Edge Function: ranked-sync
//
// Evaluates the caller's Ranked milestones from their synced workouts,
// cardio sessions and profile (never from numbers the app sends), records
// claims, and returns the resulting rank. Rank itself is computed by the
// database from approved claims (see 20261008000000_ranked_mode.sql).
//
// Body (optional): { "video": { "milestone_id": "...", "level": 4,
//                               "path": "<user id>/<file>" } }
// submits a proof video already uploaded to the ranked-proofs bucket for a
// claim that needs one; the claim then waits for review.
//
// The evaluation mirrors lib/services/ranked/ranked_evaluator.dart and reads
// the same catalog file.

import { createClient } from "jsr:@supabase/supabase-js@2";
import catalog from "../_shared/ranked_milestones.json" with { type: "json" };

type Milestone = {
  id: string;
  measure: string;
  exercisePatterns?: string[];
  excludePatterns?: string[];
  requiresVideo?: boolean;
  male: number[];
  female: number[];
};
type Stat = { id: string; rule: string; milestones: Milestone[] };
type SetJson = { weight?: number; reps?: number; completed?: boolean };
type ExerciseJson = { name?: string; sets?: SetJson[] };

Deno.serve(async (req) => {
  if (req.method !== "POST") return reply(405, { error: "Method not allowed." });
  const authHeader = req.headers.get("Authorization") ?? "";
  if (!authHeader.startsWith("Bearer ")) return reply(401, { error: "Sign in first." });

  const url = Deno.env.get("SUPABASE_URL")!;
  const userClient = createClient(url, Deno.env.get("SUPABASE_ANON_KEY")!, {
    global: { headers: { Authorization: authHeader } },
  });
  const { data: userData, error: userError } = await userClient.auth.getUser();
  const user = userData?.user;
  if (userError || !user) return reply(401, { error: "Your session expired. Sign in again." });

  const admin = createClient(url, Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!);
  let body: { video?: { milestone_id?: string; level?: number; path?: string } } = {};
  try {
    body = await req.json();
  } catch {
    // An empty body just means "re-evaluate".
  }

  // 1. Optional proof video for a claim that needs one.
  if (body.video) {
    const { milestone_id, level, path } = body.video;
    if (!milestone_id || !level || !path || !path.startsWith(`${user.id}/`)) {
      return reply(400, { error: "Invalid video submission." });
    }
    const folder = path.split("/").slice(0, -1).join("/");
    const file = path.split("/").pop()!;
    const { data: objects } = await admin.storage.from("ranked-proofs").list(folder, { search: file });
    if (!objects?.some((o) => o.name === file)) {
      return reply(400, { error: "Upload the video before submitting it." });
    }
    const { error } = await admin.from("ranked_claims")
      .update({ status: "pending_review", video_path: path, reviewer_note: null })
      .eq("user_id", user.id).eq("milestone_id", milestone_id).eq("level", level)
      .in("status", ["needs_video", "rejected"]);
    if (error) return reply(500, { error: "Could not submit the video." });
  }

  // 2. Evaluate milestones from synced data.
  const [{ data: profile }, history, sessions, cardio] = await Promise.all([
    admin.from("profiles").select("data").eq("id", user.id).maybeSingle(),
    rows(admin, "workout_history_records", user.id),
    rows(admin, "workout_session_records", user.id),
    rows(admin, "cardio_session_records", user.id),
  ]);
  const profileData = (profile?.data ?? {}) as Record<string, unknown>;
  const bodyweight = parseFloat(String(profileData.weight ?? ""));
  const gender = String(profileData.gender ?? "");

  const exercises: ExerciseJson[] = [
    ...history.flatMap((h) => (h.sessionExercises as ExerciseJson[] | undefined) ?? []),
    ...sessions.flatMap((s) => (s.exercises as ExerciseJson[] | undefined) ?? []),
  ];

  const claims: Record<string, unknown>[] = [];
  for (const stat of catalog.stats as Stat[]) {
    for (const m of stat.milestones) {
      const best = evaluate(m, exercises, history, cardio, bodyweight);
      if (best === null) continue;
      const level = levelFor(m, best, gender);
      for (let l = 1; l <= level; l++) {
        const needsVideo = (m.requiresVideo ?? false) && l >= catalog.videoRequiredFromLevel;
        claims.push({
          milestone_id: m.id,
          stat_id: stat.id,
          level: l,
          value: Math.round(best * 1000) / 1000,
          status: needsVideo ? "needs_video" : "approved",
        });
      }
    }
  }

  if (claims.length > 0) {
    const { error } = await admin.rpc("upsert_ranked_claims", { p_user_id: user.id, p_claims: claims });
    if (error) return reply(500, { error: "Could not record milestones." });
  } else {
    await admin.rpc("recompute_ranked_profile", { p_user_id: user.id });
  }

  const [{ data: rankRow }, { data: claimRows }] = await Promise.all([
    admin.from("ranked_profiles").select("points, stat_levels").eq("user_id", user.id).maybeSingle(),
    admin.from("ranked_claims").select("milestone_id, level, value, status, reviewer_note").eq("user_id", user.id),
  ]);

  return reply(200, {
    points: rankRow?.points ?? 0,
    stat_levels: rankRow?.stat_levels ?? {},
    claims: claimRows ?? [],
  });
});

async function rows(
  admin: ReturnType<typeof createClient>,
  table: string,
  userId: string,
): Promise<Record<string, unknown>[]> {
  const { data } = await admin.from(table).select("data").eq("user_id", userId).limit(2000);
  return (data ?? []).map((r: { data: Record<string, unknown> }) => r.data ?? {});
}

function matches(m: Milestone, name: string): boolean {
  const n = name.toLowerCase();
  if ((m.excludePatterns ?? []).some((p) => n.includes(p))) return false;
  return (m.exercisePatterns ?? []).some((p) => n.includes(p));
}

/** Estimated one-rep max (Epley) from a set of 1–5 reps. */
function e1rm(weight: number, reps: number): number | null {
  if (!(weight > 0) || reps < 1 || reps > 5) return null;
  return reps === 1 ? weight : weight * (1 + reps / 30);
}

function evaluate(
  m: Milestone,
  exercises: ExerciseJson[],
  history: Record<string, unknown>[],
  cardio: Record<string, unknown>[],
  bodyweight: number,
): number | null {
  let best: number | null = null;
  const completedSets = (ex: ExerciseJson) => (ex.sets ?? []).filter((s) => s.completed);
  switch (m.measure) {
    case "bodyweight_multiple":
      if (!(bodyweight > 0)) return null;
      for (const ex of exercises.filter((e) => matches(m, e.name ?? ""))) {
        for (const s of completedSets(ex)) {
          const est = e1rm(Number(s.weight ?? 0), Number(s.reps ?? 0));
          if (est !== null) best = Math.max(best ?? 0, est / bodyweight);
        }
      }
      return best;
    case "max_reps":
      for (const ex of exercises.filter((e) => matches(m, e.name ?? ""))) {
        for (const s of completedSets(ex)) best = Math.max(best ?? 0, Number(s.reps ?? 0));
      }
      return best;
    case "time_5k_minutes":
      for (const c of cardio) {
        const name = `${c.exerciseName ?? ""} ${c.category ?? ""}`;
        const km = Number(c.distanceKm ?? 0);
        const seconds = Number(c.durationSeconds ?? 0);
        if (!matches(m, name) || km < 5 || seconds <= 0) continue;
        const minutes = (seconds / 60) * (5 / km);
        best = best === null ? minutes : Math.min(best, minutes);
      }
      return best;
    case "workouts_in_window": {
      const since = Date.now() - catalog.consistencyWindowDays * 86_400_000;
      const recent = (iso: unknown) => Date.parse(String(iso ?? "")) > since;
      return history.filter((h) => recent(h.dateCompleted)).length +
        cardio.filter((c) => recent(c.startTime)).length;
    }
  }
  return null;
}

function levelFor(m: Milestone, value: number, gender: string): number {
  const targets = gender.trim().toLowerCase().startsWith("f") ? m.female : m.male;
  const lowerIsBetter = m.measure === "time_5k_minutes";
  let level = 0;
  targets.forEach((t, i) => {
    if (lowerIsBetter ? value <= t : value >= t) level = i + 1;
  });
  return level;
}

function reply(status: number, body: unknown): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "Content-Type": "application/json" },
  });
}
