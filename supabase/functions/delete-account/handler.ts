// Request handling for delete-account, with its dependencies injected so the
// order of operations and failure handling can be tested without Supabase.

export interface DeleteAccountDeps {
  /** The signed-in user for this Authorization header, or null. */
  getUser(authHeader: string): Promise<{ id: string } | null>;
  /** Removes the user's uploaded files; must throw if any remain. */
  deleteFiles(userId: string): Promise<unknown>;
  /** Deletes the auth user (and, by cascade, their rows). */
  deleteAuthUser(userId: string): Promise<{ message: string } | null>;
  /** Logs a server-side error (never sent to the client). */
  logError(message: string, detail?: unknown): void;
}

export async function handleDeleteAccount(
  req: Request,
  deps: DeleteAccountDeps,
): Promise<Response> {
  if (req.method !== "POST") return reply(405, "Method not allowed.");

  const authHeader = req.headers.get("Authorization") ?? "";
  if (!authHeader.startsWith("Bearer ")) return reply(401, "Sign in first.");

  const user = await deps.getUser(authHeader);
  if (!user) return reply(401, "Your session expired. Sign in again.");

  // Files first: if they cannot be removed, keep the account so the user can
  // retry instead of losing the ability to delete their data.
  try {
    await deps.deleteFiles(user.id);
  } catch (e) {
    deps.logError("delete-account: file cleanup failed", e);
    return reply(500, "Could not delete your files. Your account was not deleted. Try again.");
  }

  const deleteError = await deps.deleteAuthUser(user.id);
  if (deleteError) {
    deps.logError("delete-account: auth user deletion failed", deleteError.message);
    return reply(500, "Could not delete the account. Try again.");
  }

  return reply(200, "Account deleted.");
}

function reply(status: number, message: string): Response {
  return new Response(JSON.stringify({ message }), {
    status,
    headers: { "Content-Type": "application/json" },
  });
}
