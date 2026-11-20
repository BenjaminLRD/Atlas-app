// Tests for delete-account file cleanup and request handling.
//
// Run with Node 22.18+ (no install needed):
//   node --test supabase/functions/delete-account/delete_account_test.ts
// or with Deno:
//   deno test supabase/functions/delete-account/delete_account_test.ts

import { test } from "node:test";
import assert from "node:assert/strict";
import { handleDeleteAccount, type DeleteAccountDeps } from "./handler.ts";
import {
  deleteUserFiles,
  type StorageApi,
  type StorageBucketApi,
  StorageCleanupError,
} from "./storage_cleanup.ts";

const ALICE = "11111111-1111-4111-8111-111111111111";
// Same leading characters as ALICE: a prefix match would wrongly include it.
const ALICE_LOOKALIKE = "11111111-1111-4111-8111-111111111110";
const BOB = "22222222-2222-4222-8222-222222222222";

/** In-memory storage that pages like the real service (max 100 per page). */
class FakeStorage implements StorageApi {
  buckets = new Map<string, Set<string>>();
  removeCalls: string[][] = [];
  listCalls = 0;
  failListIn: string | null = null;
  failRemoveIn: string | null = null;
  removeIsNoop = false;

  put(bucket: string, ...paths: string[]) {
    const set = this.buckets.get(bucket) ?? new Set<string>();
    paths.forEach((p) => set.add(p));
    this.buckets.set(bucket, set);
  }

  paths(bucket: string): string[] {
    return [...(this.buckets.get(bucket) ?? [])].sort();
  }

  from(bucket: string): StorageBucketApi {
    const files = () => this.buckets.get(bucket) ?? new Set<string>();
    return {
      list: async (path, { limit, offset }) => {
        this.listCalls++;
        if (this.failListIn === bucket) return { data: null, error: { message: "boom (list)" } };
        const names = new Map<string, boolean>(); // name -> isFolder
        for (const p of files()) {
          if (!p.startsWith(`${path}/`)) continue;
          const [head, ...rest] = p.slice(path.length + 1).split("/");
          names.set(head, rest.length > 0 || names.get(head) === true);
        }
        const entries = [...names.entries()]
          .sort(([a], [b]) => a.localeCompare(b))
          .map(([name, isFolder]) => ({ name, id: isFolder ? null : `id-${name}` }));
        return { data: entries.slice(offset, offset + Math.min(limit, 100)), error: null };
      },
      remove: async (paths) => {
        this.removeCalls.push(paths);
        if (this.failRemoveIn === bucket) return { data: null, error: { message: "boom (remove)" } };
        if (!this.removeIsNoop) paths.forEach((p) => files().delete(p));
        return { data: paths.map((name) => ({ name })), error: null };
      },
    };
  }
}

// ---------------------------------------------------------------------------
// File cleanup
// ---------------------------------------------------------------------------

test("removes only the target user's files, in both buckets", async () => {
  const s = new FakeStorage();
  s.put("ranked-proofs", `${ALICE}/bench_4_1.mp4`, `${ALICE}/squat_5_2.mp4`, `${BOB}/bench_4_9.mp4`);
  s.put("community-photos", `${ALICE}/1700.jpg`, `${BOB}/1800.jpg`, `${ALICE_LOOKALIKE}/1900.jpg`);

  const { removed } = await deleteUserFiles(s, ALICE);

  assert.equal(removed, 3);
  assert.deepEqual(s.paths("ranked-proofs"), [`${BOB}/bench_4_9.mp4`]);
  assert.deepEqual(s.paths("community-photos"), [`${ALICE_LOOKALIKE}/1900.jpg`, `${BOB}/1800.jpg`]);
  // Everything handed to remove() belongs to Alice.
  for (const call of s.removeCalls) {
    for (const path of call) assert.ok(path.startsWith(`${ALICE}/`), path);
  }
});

test("follows pagination: 250 files are all removed", async () => {
  const s = new FakeStorage();
  const files = Array.from({ length: 250 }, (_, i) => `${ALICE}/clip_${String(i).padStart(3, "0")}.mp4`);
  s.put("ranked-proofs", ...files, `${BOB}/keep.mp4`);

  const { removed } = await deleteUserFiles(s, ALICE);

  assert.equal(removed, 250);
  assert.deepEqual(s.paths("ranked-proofs"), [`${BOB}/keep.mp4`]);
  assert.ok(s.removeCalls.every((c) => c.length <= 100), "removals are batched");
});

test("removes files inside sub-folders", async () => {
  const s = new FakeStorage();
  s.put("community-photos", `${ALICE}/a.jpg`, `${ALICE}/albums/b.jpg`, `${ALICE}/albums/2026/c.jpg`);

  const { removed } = await deleteUserFiles(s, ALICE);

  assert.equal(removed, 3);
  assert.deepEqual(s.paths("community-photos"), []);
});

test("a user with no files succeeds without calling remove", async () => {
  const s = new FakeStorage();
  s.put("ranked-proofs", `${BOB}/x.mp4`);

  assert.deepEqual(await deleteUserFiles(s, ALICE), { removed: 0 });
  assert.equal(s.removeCalls.length, 0);
});

test("a listing error aborts before anything is removed", async () => {
  const s = new FakeStorage();
  s.put("ranked-proofs", `${ALICE}/a.mp4`);
  s.put("community-photos", `${ALICE}/a.jpg`);
  s.failListIn = "community-photos";

  await assert.rejects(() => deleteUserFiles(s, ALICE), (e: unknown) => {
    assert.ok(e instanceof StorageCleanupError);
    assert.match(e.message, /community-photos/);
    return true;
  });
});

test("a removal error is reported, not swallowed", async () => {
  const s = new FakeStorage();
  s.put("ranked-proofs", `${ALICE}/a.mp4`);
  s.failRemoveIn = "ranked-proofs";

  await assert.rejects(() => deleteUserFiles(s, ALICE), /Could not remove files from ranked-proofs/);
  assert.deepEqual(s.paths("ranked-proofs"), [`${ALICE}/a.mp4`]);
});

test("files that survive a 'successful' removal are an error", async () => {
  const s = new FakeStorage();
  s.put("community-photos", `${ALICE}/a.jpg`);
  s.removeIsNoop = true;

  await assert.rejects(() => deleteUserFiles(s, ALICE), /1 file\(s\) remain in community-photos/);
});

test("retrying after a partial failure finishes the job", async () => {
  const s = new FakeStorage();
  s.put("ranked-proofs", `${ALICE}/a.mp4`);
  s.put("community-photos", `${ALICE}/a.jpg`);
  s.failRemoveIn = "community-photos";
  await assert.rejects(() => deleteUserFiles(s, ALICE));
  assert.deepEqual(s.paths("ranked-proofs"), []); // first bucket already done

  s.failRemoveIn = null;
  const { removed } = await deleteUserFiles(s, ALICE);
  assert.equal(removed, 1);
  assert.deepEqual(s.paths("community-photos"), []);
});

test("anything but a plain UUID is rejected without touching storage", async () => {
  for (const bad of ["", "..", "../" + BOB, `${ALICE}/..`, `${ALICE}/`, "*", "not-a-uuid"]) {
    const s = new FakeStorage();
    s.put("ranked-proofs", `${BOB}/keep.mp4`);
    await assert.rejects(() => deleteUserFiles(s, bad), StorageCleanupError, JSON.stringify(bad));
    assert.equal(s.listCalls, 0, JSON.stringify(bad));
    assert.equal(s.removeCalls.length, 0, JSON.stringify(bad));
  }
});

// ---------------------------------------------------------------------------
// Request handling
// ---------------------------------------------------------------------------

function makeDeps(overrides: Partial<DeleteAccountDeps> = {}) {
  const calls: string[] = [];
  const deps: DeleteAccountDeps = {
    getUser: async () => {
      calls.push("getUser");
      return { id: ALICE };
    },
    deleteFiles: async (id) => {
      calls.push(`deleteFiles:${id}`);
    },
    deleteAuthUser: async (id) => {
      calls.push(`deleteAuthUser:${id}`);
      return null;
    },
    logError: () => {},
    ...overrides,
  };
  return { deps, calls };
}

const post = (headers: Record<string, string> = { Authorization: "Bearer token" }) =>
  new Request("https://example.test/delete-account", { method: "POST", headers });

test("deletes files, then the account, for the authenticated user", async () => {
  const { deps, calls } = makeDeps();
  const res = await handleDeleteAccount(post(), deps);

  assert.equal(res.status, 200);
  assert.deepEqual(calls, ["getUser", `deleteFiles:${ALICE}`, `deleteAuthUser:${ALICE}`]);
});

test("rejects non-POST, missing and invalid credentials without deleting anything", async () => {
  for (const [req, deps, status] of [
    [new Request("https://example.test/delete-account", { method: "GET" }), makeDeps(), 405],
    [post({}), makeDeps(), 401],
    [post({ Authorization: "Basic abc" }), makeDeps(), 401],
    [post(), makeDeps({ getUser: async () => null }), 401],
  ] as const) {
    const res = await handleDeleteAccount(req, deps.deps);
    assert.equal(res.status, status);
    assert.ok(!deps.calls.some((c) => c.startsWith("delete")), "nothing deleted");
  }
});

test("if file cleanup fails the account is NOT deleted and the error is reported", async () => {
  const logged: string[] = [];
  const { deps, calls } = makeDeps({
    deleteFiles: async () => {
      throw new StorageCleanupError("Could not remove files from ranked-proofs: boom");
    },
    logError: (m) => logged.push(m),
  });

  const res = await handleDeleteAccount(post(), deps);
  const body = await res.json();

  assert.equal(res.status, 500);
  assert.match(body.message, /account was not deleted/i);
  assert.ok(!body.message.includes("boom"), "internal detail is not sent to the client");
  assert.ok(!calls.some((c) => c.startsWith("deleteAuthUser")), "auth user must survive");
  assert.equal(logged.length, 1);
});

test("if the auth user cannot be deleted, the client gets an error", async () => {
  const { deps } = makeDeps({ deleteAuthUser: async () => ({ message: "db down" }) });
  const res = await handleDeleteAccount(post(), deps);

  assert.equal(res.status, 500);
  assert.ok(!(await res.text()).includes("db down"));
});
