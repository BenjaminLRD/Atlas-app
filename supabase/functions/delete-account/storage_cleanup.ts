// Removes a user's uploaded files from the private/public storage buckets.
//
// Files are stored as "<user id>/<file>" in both buckets (the storage policies
// enforce that first folder), so everything under that prefix belongs to the
// user and nothing else is touched. Any storage error aborts with an error so
// the caller can refuse to delete the account while files would be left behind.

export const USER_FILE_BUCKETS = ["ranked-proofs", "community-photos"] as const;

const PAGE_SIZE = 100;
const REMOVE_BATCH = 100;
const MAX_DEPTH = 5;
const MAX_FILES = 10_000;
const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

type StorageError = { message: string } | null;
export type StorageEntry = { name: string; id?: string | null };

/** The slice of the Supabase storage client this module uses. */
export interface StorageBucketApi {
  list(
    path: string,
    options: { limit: number; offset: number },
  ): Promise<{ data: StorageEntry[] | null; error: StorageError }>;
  remove(paths: string[]): Promise<{ data: unknown; error: StorageError }>;
}
export interface StorageApi {
  from(bucket: string): StorageBucketApi;
}

export class StorageCleanupError extends Error {
  constructor(message: string) {
    super(message);
    this.name = "StorageCleanupError";
  }
}

/**
 * Deletes every file under "<userId>/" in each of [buckets]. Throws
 * [StorageCleanupError] on an invalid user id, any storage error, or when
 * files are still present after removal. Safe to retry: already-removed files
 * simply are not listed again.
 */
export async function deleteUserFiles(
  storage: StorageApi,
  userId: string,
  buckets: readonly string[] = USER_FILE_BUCKETS,
): Promise<{ removed: number }> {
  // Never build a prefix from anything but a plain UUID (no empty string, no
  // "..", no slashes), so a bad id can never widen the delete.
  if (!UUID.test(userId)) throw new StorageCleanupError("Invalid user id.");

  let removed = 0;
  for (const bucketName of buckets) {
    const bucket = storage.from(bucketName);
    const paths = await listAll(bucket, bucketName, userId, 0);

    for (let i = 0; i < paths.length; i += REMOVE_BATCH) {
      const { error } = await bucket.remove(paths.slice(i, i + REMOVE_BATCH));
      if (error) {
        throw new StorageCleanupError(`Could not remove files from ${bucketName}: ${error.message}`);
      }
    }
    removed += paths.length;

    // Confirm nothing is left (a silent partial failure must not look like success).
    const left = await listAll(bucket, bucketName, userId, 0);
    if (left.length > 0) {
      throw new StorageCleanupError(`${left.length} file(s) remain in ${bucketName}.`);
    }
  }
  return { removed };
}

/** Lists all file paths under [prefix], following pages and sub-folders. */
async function listAll(
  bucket: StorageBucketApi,
  bucketName: string,
  prefix: string,
  depth: number,
): Promise<string[]> {
  if (depth > MAX_DEPTH) {
    throw new StorageCleanupError(`Folders in ${bucketName} are nested too deeply.`);
  }
  const files: string[] = [];
  for (let offset = 0;; offset += PAGE_SIZE) {
    const { data, error } = await bucket.list(prefix, { limit: PAGE_SIZE, offset });
    if (error) {
      throw new StorageCleanupError(`Could not list files in ${bucketName}: ${error.message}`);
    }
    const page = data ?? [];
    for (const entry of page) {
      const path = `${prefix}/${entry.name}`;
      // Storage reports sub-folders as entries without an id.
      if (entry.id == null) {
        files.push(...await listAll(bucket, bucketName, path, depth + 1));
      } else {
        files.push(path);
      }
    }
    if (files.length > MAX_FILES) {
      throw new StorageCleanupError(`Too many files in ${bucketName} to delete in one request.`);
    }
    if (page.length < PAGE_SIZE) break;
  }
  return files;
}
