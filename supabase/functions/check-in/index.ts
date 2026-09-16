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
// Pure passthrough to check_in() (see schema.sql), with no content
// mutation of any kind -- this used to also inject a per-install
// watermark into AGENTS.md's content before returning it, removed once
// the playbook content was relicensed MIT (content v1.18.0): a token
// meant to trace an unauthorized "leaked" copy back to its source
// install stopped making sense the moment redistribution itself became
// explicitly licensed. Attribution is now a static line baked directly
// into AGENTS.md's own source content instead (same for every install,
// no per-install data involved), which also means every fetched file's
// hash matches its signed manifest entry exactly, with zero runtime
// mutation anywhere in this path -- a strictly stronger trust property
// than the watermarking version had.
//
// manifest_json / manifest_signature: check_in() returns these two
// columns from `releases` alongside archive_base64. Nothing here needs
// to touch them -- this function has never filtered fields out of the
// row, so they flow to the installer as-is, and install.sh verifies them
// against a fixed public key before trusting anything this function
// returns.
//
// Deploy:
//   supabase functions deploy check-in --no-verify-jwt
//   supabase secrets set SB_URL=https://xxxx.supabase.co
//   supabase secrets set SB_SERVICE_ROLE_KEY=<service_role key, from
//     Project Settings -> API -- NOT the anon key>

const SB_URL = Deno.env.get("SB_URL")!;
const SB_SERVICE_ROLE_KEY = Deno.env.get("SB_SERVICE_ROLE_KEY")!;

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

  return new Response(text, {
    status: upstream.status,
    headers: { "Content-Type": "application/json" },
  });
});
