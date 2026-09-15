// Public-facing check-in endpoint. Deployed with `--no-verify-jwt`, so the
// installer needs zero credentials of any kind -- no token, no signup,
// nothing to ask the maintainer for. It sends only a random local ID it
// generated itself, and gets back the current release (or a block
// notice, if that specific ID was later revoked -- see schema.sql).
//
// p_requested_version (optional): pins the response to a specific past
// release instead of whatever's currently latest -- install.sh's
// --version flag / AGENT_PLAYBOOKS_VERSION sets this. Omitted (the
// default), behavior is unchanged: latest, same as before this existed.
//
// The real Supabase access (service role key) lives only in this
// function's environment as a Supabase secret, never returned to the
// caller or visible in any client-side code, repo, or log. That's the
// actual security property here: not "you need permission to install,"
// but "no infrastructure credential ever leaves the server."
//
// Per-install watermark: the stored release is a JSON map of
// {relative path: base64 file content} (see maintainer/package-release.sh),
// not a single opaque archive -- deliberately, so this function can
// modify one file's content before returning it. A short token derived
// from the caller's own p_id (no secret needed -- p_id is already an
// opaque random UUID with no PII) gets appended to AGENTS.md as an
// inconspicuous HTML comment. It's invisible in normal markdown
// rendering and doesn't change how an AI reads the instructions, but if
// a full copy of this content ever turns up somewhere it shouldn't,
// the token traces it back to exactly which install it came from. The
// token is fully deterministic from p_id (sha256, truncated) -- nothing
// extra is stored; to identify an install from a found token, recompute
// the same hash for each row in `installations` and compare (see
// schema.sql's comments for the query).
//
// Deploy:
//   supabase functions deploy check-in --no-verify-jwt
//   supabase secrets set SB_URL=https://xxxx.supabase.co
//   supabase secrets set SB_SERVICE_ROLE_KEY=<service_role key, from
//     Project Settings -> API -- NOT the anon key>

const SB_URL = Deno.env.get("SB_URL")!;
const SB_SERVICE_ROLE_KEY = Deno.env.get("SB_SERVICE_ROLE_KEY")!;

function base64ToBytes(b64: string): Uint8Array {
  const binStr = atob(b64);
  const bytes = new Uint8Array(binStr.length);
  for (let i = 0; i < binStr.length; i++) bytes[i] = binStr.charCodeAt(i);
  return bytes;
}

function bytesToBase64(bytes: Uint8Array): string {
  let binStr = "";
  for (let i = 0; i < bytes.length; i++) binStr += String.fromCharCode(bytes[i]);
  return btoa(binStr);
}

async function watermarkToken(installId: string): Promise<string> {
  // Lowercase first: Postgres normalizes uuid columns to lowercase
  // canonical form, and the lookup query in schema.sql hashes id::text
  // read back from that column. macOS's uuidgen (the primary path
  // install.sh uses to create a local ID) produces UPPERCASE UUIDs, so
  // without this normalization the token embedded here would never
  // match what the documented lookup query computes -- found by
  // actually running that lookup query against a real install rather
  // than assuming the two sides agreed on casing.
  const data = new TextEncoder().encode(installId.toLowerCase());
  const hashBuf = await crypto.subtle.digest("SHA-256", data);
  const hashHex = Array.from(new Uint8Array(hashBuf))
    .map((b) => b.toString(16).padStart(2, "0"))
    .join("");
  return hashHex.slice(0, 12);
}

// Mutates fileMap in place: appends a watermark comment to AGENTS.md's
// content, UTF-8 safe (this content has real em-dashes, arrows, etc. --
// naive Latin1 atob/btoa would corrupt them, hence the explicit
// TextDecoder/TextEncoder round-trip rather than a direct string append
// on the base64 itself).
async function watermarkFileMap(fileMap: Record<string, string>, installId: string): Promise<void> {
  const target = fileMap["AGENTS.md"];
  if (!target) return; // defensive: don't fail the whole install if the shape ever changes
  const bytes = base64ToBytes(target);
  const content = new TextDecoder("utf-8").decode(bytes);
  const token = await watermarkToken(installId);
  const watermarked = `${content}\n<!-- ref: ${token} -->\n`;
  fileMap["AGENTS.md"] = bytesToBase64(new TextEncoder().encode(watermarked));
}

Deno.serve(async (req: Request) => {
  if (req.method !== "POST") {
    return new Response(JSON.stringify({ error: "POST only" }), {
      status: 405,
      headers: { "Content-Type": "application/json" },
    });
  }

  let body: { p_id?: string; p_version?: string; p_requested_version?: string };
  try {
    body = await req.json();
  } catch {
    return new Response(JSON.stringify({ error: "invalid JSON body" }), {
      status: 400,
      headers: { "Content-Type": "application/json" },
    });
  }

  if (!body.p_id) {
    return new Response(JSON.stringify({ error: "p_id is required" }), {
      status: 400,
      headers: { "Content-Type": "application/json" },
    });
  }

  const upstream = await fetch(`${SB_URL}/rest/v1/rpc/check_in`, {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      apikey: SB_SERVICE_ROLE_KEY,
      Authorization: `Bearer ${SB_SERVICE_ROLE_KEY}`,
    },
    body: JSON.stringify({
      p_id: body.p_id,
      p_version: body.p_version ?? null,
      p_requested_version: body.p_requested_version ?? null,
    }),
  });

  const text = await upstream.text();

  if (!upstream.ok) {
    return new Response(text, {
      status: upstream.status,
      headers: { "Content-Type": "application/json" },
    });
  }

  let data: Array<{ blocked?: boolean; archive_base64?: string; [k: string]: unknown }>;
  try {
    data = JSON.parse(text);
  } catch {
    // Upstream didn't return the JSON shape expected -- pass it through
    // unmodified rather than crash; nothing here should ever be able to
    // turn a working install into a broken one.
    return new Response(text, {
      status: upstream.status,
      headers: { "Content-Type": "application/json" },
    });
  }

  const row = data[0];
  if (row && !row.blocked && row.archive_base64) {
    try {
      const fileMap = JSON.parse(row.archive_base64) as Record<string, string>;
      await watermarkFileMap(fileMap, body.p_id);
      row.archive_base64 = JSON.stringify(fileMap);
    } catch {
      // Watermarking is a nice-to-have, not something that should ever
      // block a real install -- if anything about this fails, fall back
      // to serving the unwatermarked archive rather than erroring out.
    }
  }

  return new Response(JSON.stringify(data), {
    status: upstream.status,
    headers: { "Content-Type": "application/json" },
  });
});
