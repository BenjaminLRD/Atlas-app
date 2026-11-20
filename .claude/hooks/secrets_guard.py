#!/usr/bin/env python3
"""PreToolUse guard: keep Claude's file-editing tools away from real secret files.

Blocked (by file name, in any folder): `.env`, `.env.*` (for example
`.env.production`) and `*.env`. `.env.example` is allowed: it is the tracked
template, holds no secrets and is edited when a new setting is added.

Wired to Edit, Write, MultiEdit and NotebookEdit only (see
.claude/settings.json). It does not look at Bash or PowerShell commands, or Read.

Input: the hook JSON on stdin. Output: exit 2 with a reason on stderr to block,
exit 0 to leave the call alone. Anything unexpected is blocked, not allowed:
a hook input that is not an object, a `tool_input` that is not an object, a
path that is missing or not a non-empty string, and any error while checking.

Hard links: a file with more than one link is compared against the protected
files found under the project folder (CLAUDE_PROJECT_DIR, else the hook's
working directory), skipping build and tool folders. A hard link to a secret
that lives outside the project folder cannot be recognised this way; that is a
known limit. If the scan is cut off by its size bound, the edit is blocked.
"""
import json
import os
import posixpath
import sys

ALLOWED_NAMES = {".env.example"}
PATH_KEYS = ("file_path", "notebook_path", "path")
SKIP_DIRS = {
    ".git", ".dart_tool", ".gradle", ".idea", "build", "node_modules",
    "Pods", "graphify-out", ".pub-cache",
}
MAX_SCAN_ENTRIES = 100000


class ScanLimit(Exception):
    pass


def is_protected_name(name):
    # Windows ignores trailing dots and spaces, and any ":stream" suffix.
    name = name.split(":", 1)[0].rstrip(" .").lower()
    if not name or name in ALLOWED_NAMES:
        return False
    return name == ".env" or name.startswith(".env.") or name.endswith(".env")


def last_component(path):
    p = path.replace("\\", "/")
    for prefix in ("//?/", "//./"):
        if p.startswith(prefix):
            p = p[len(prefix):]
    return posixpath.basename(posixpath.normpath(p))


def long_path(path):
    """Expand 8.3 short names (Windows only); returns the input on failure."""
    if os.name != "nt":
        return path
    try:
        import ctypes

        buf = ctypes.create_unicode_buffer(32768)
        n = ctypes.windll.kernel32.GetLongPathNameW(path, buf, len(buf))
        return buf.value if 0 < n < len(buf) else path
    except Exception:
        return path


def protected_files_under(root):
    """Protected files below [root], skipping tool and build folders."""
    seen = 0
    found = []
    for dirpath, dirnames, filenames in os.walk(root):
        dirnames[:] = [d for d in dirnames if d not in SKIP_DIRS]
        seen += len(dirnames) + len(filenames)
        if seen > MAX_SCAN_ENTRIES:
            raise ScanLimit()
        for name in filenames:
            if is_protected_name(name):
                found.append(os.path.join(dirpath, name))
    return found


def is_hard_link_to_protected(path, project_root):
    """True when [path] is another name for a protected file in the project."""
    try:
        if os.stat(path).st_nlink <= 1:
            return False
    except OSError:
        return False  # no existing file, so nothing it could be linked to
    for candidate in protected_files_under(project_root):
        try:
            if os.path.samefile(path, candidate):
                return True
        except OSError:
            continue
    return False


def is_protected_path(path, project_root):
    if "\x00" in path:
        return True
    names = {last_component(path)}
    for variant in (long_path(path), os.path.realpath(path)):
        names.add(last_component(variant))
    if any(is_protected_name(n) for n in names):
        return True
    return is_hard_link_to_protected(path, project_root)


def check(data):
    """Returns None to allow, or the reason to block."""
    if not isinstance(data, dict):
        return "the hook input is not an object"
    tool_input = data.get("tool_input")
    if not isinstance(tool_input, dict):
        return "tool_input is not an object"
    cwd = data.get("cwd")
    if not isinstance(cwd, str) or not cwd:
        cwd = os.getcwd()
    project_root = os.environ.get("CLAUDE_PROJECT_DIR") or cwd

    found = False
    for key in PATH_KEYS:
        if key not in tool_input:
            continue
        value = tool_input[key]
        if not isinstance(value, str) or not value.strip():
            return "%s must be a non-empty string" % key
        found = True
        if is_protected_path(value, project_root):
            return (
                "%s is a protected secrets file (.env, .env.* or *.env; "
                ".env.example is allowed). Edit it yourself." % value
            )
    if not found:
        return "tool_input has no file path"
    return None


def deny(reason):
    try:
        sys.stderr.write("Blocked by secrets_guard: %s\n" % reason)
    except Exception:
        pass
    return 2


def main():
    try:
        data = json.loads(sys.stdin.buffer.read().decode("utf-8", "replace"))
        reason = check(data)
    except ScanLimit:
        return deny(
            "the project is too large to check for hard links to secret "
            "files, so the edit was not allowed."
        )
    except Exception as e:
        return deny(
            "could not check this edit (%s), so it was not allowed."
            % type(e).__name__
        )
    return deny(reason) if reason else 0


if __name__ == "__main__":
    sys.exit(main())
