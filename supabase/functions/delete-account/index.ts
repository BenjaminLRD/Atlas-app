// Supabase Edge Function: delete-account
//
// Permanently deletes the calling user: first their uploaded files in the
// ranked-proofs and community-photos buckets, then the auth user (all of their
// rows are removed by ON DELETE CASCADE from auth.users). Storage objects do
// not cascade, so they are removed explicitly; if that fails the account is
// kept and an error is returned. App Store and Google Play both require in-app
// account deletion. Deleting a user needs the service role key, which only
// exists here on the server.

import { createClient } from "jsr:@supabase/supabase-js@2";
import { handleDeleteAccount } from "./handler.ts";
import { deleteUserFiles, type StorageApi } from "./storage_cleanup.ts";

Deno.serve((req) => {
  const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
  const admin = createClient(supabaseUrl, Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!);

  return handleDeleteAccount(req, {
    async getUser(authHeader) {
      const userClient = createClient(supabaseUrl, Deno.env.get("SUPABASE_ANON_KEY")!, {
        global: { headers: { Authorization: authHeader } },
      });
      const { data, error } = await userClient.auth.getUser();
      return error || !data?.user ? null : { id: data.user.id };
    },
    deleteFiles: (userId) => deleteUserFiles(admin.storage as unknown as StorageApi, userId),
    async deleteAuthUser(userId) {
      const { error } = await admin.auth.admin.deleteUser(userId);
      return error ? { message: error.message } : null;
    },
    logError: (message, detail) => console.error(message, detail),
  });
});
