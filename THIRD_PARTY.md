# Third-party software and services

Agent Playbooks does not bundle or redistribute any of the software below.
The playbooks and scripts only call tools you install yourself, and the
installer talks to two hosted services. Licences are listed as
understood at the time of writing; check each project's own page before
you redistribute anything or build on it commercially.

## Tools invoked locally (not bundled)

| Tool | Used for | Where | Licence (verify upstream) |
|---|---|---|---|
| [jq](https://jqlang.github.io/jq/) | Parsing the check-in response and hook input | `install.sh`, `scripts/claude-code-secret-hook.sh` | MIT |
| [curl](https://curl.se/) | Calling the check-in endpoint | `install.sh` | curl licence (MIT-style) |
| [FFmpeg](https://ffmpeg.org/) | Screen capture, muxing, captions | `demo-video.md`, `scripts/assemble.sh`, `scripts/record-screen.sh`, `scripts/captions.sh` | LGPL 2.1+ or GPL 2+, depending on your build |
| [espeak-ng](https://github.com/espeak-ng/espeak-ng) | Offline text to speech | `demo-video.md`, `scripts/narrate.sh` | GPL 3.0 |
| [Piper](https://github.com/OHF-Voice/piper1-gpl) (original [rhasspy/piper](https://github.com/rhasspy/piper) is archived) | Neural text to speech | `demo-video.md`, `scripts/narrate.sh` | The original rhasspy/piper was MIT; current releases are GPL 3.0. Each voice model carries its own licence |
| [whisper.cpp](https://github.com/ggml-org/whisper.cpp) or [openai-whisper](https://github.com/openai/whisper) | Speech to text for video review | `scripts/transcribe.sh`, `scripts/extract-media.sh` | MIT (both). Model weights have their own terms |
| [Poppler](https://poppler.freedesktop.org/) (`pdftotext`, `pdftoppm`, `pdfinfo`) | PDF text and page rendering | `scripts/extract-doc-text.sh`, `scripts/render-doc-pages.sh`, `scripts/doc-page-index.sh` | GPL 2 or 3 |
| [Pandoc](https://pandoc.org/) | Document text extraction | `scripts/extract-doc-text.sh` | GPL 2+ |
| [LibreOffice](https://www.libreoffice.org/) | Rendering office documents to PDF | `scripts/render-doc-pages.sh` | MPL 2.0 |
| [ShellCheck](https://www.shellcheck.net/) | Linting the shell scripts | Referenced in the playbooks | GPL 3.0 |
| [markitdown](https://github.com/microsoft/markitdown) | Spreadsheet text extraction (`pip install 'markitdown[all]'`) | `scripts/extract-doc-text.sh` | MIT |
| [Playwright](https://playwright.dev/) | Browser driven UI testing examples | `quality/frontend-testing.md`, `demo-video.md` | Apache 2.0 |
| [Google Chrome](https://www.google.com/chrome/) or [Chromium](https://www.chromium.org/) | Headless rendering/recording of the teaser's Canvas animation to mp4, driven directly over the Chrome DevTools Protocol | `teaser/record.mts`, `teaser/chrome.ts` | Chrome is proprietary freeware; Chromium is BSD-style |
| [tsx](https://github.com/privatenumber/tsx) | Runs `record.mts` directly, no build step | `teaser/package.json`, `teaser/record.mts` | MIT |

Because these run as separate programs, their licences do not apply to
your project or to the playbooks. They would matter if you redistributed
the tools, or generated audio with a voice model whose licence limits
commercial use. Check the voice model licence before publishing a demo.

## Hosted services (data leaves your machine)

| Service | Role | What it receives |
|---|---|---|
| [Supabase](https://supabase.com/) | Hosts the check-in endpoint and release store | A random install ID (a UUID generated on first install) and, optionally, the version you requested. No name, email or machine identifier |
| [Cloudflare](https://www.cloudflare.com/) | Sits in front of Supabase | Standard network metadata such as your IP address, as with any HTTPS request |
| [Google Fonts](https://fonts.google.com/) | Serves the Bricolage Grotesque and IBM Plex Mono webfonts the teaser's Canvas animation loads via `<link>` | Standard network metadata such as your IP address, as with any HTTPS request, whenever `teaser/agent-playbooks-source.html` is opened or rendered |

Both act as processors for the check-in only (Google Fonts is a separate,
unrelated request made only when the teaser page itself is opened).
Nothing from your project is sent.

## References and credits (not invoked)

| Item | How it is used | Licence |
|---|---|---|
| [blader/humanizer](https://github.com/blader/humanizer) | Linked from `quality/writing-style.md`, `README.md` and `EXAMPLES.md` as an optional deeper reference for AI writing tells. Not a dependency | MIT |
| [Contributor Covenant 2.1](https://www.contributor-covenant.org/) and [Mozilla's diversity guidelines](https://github.com/mozilla/diversity) | Basis of the public repo's `CODE_OF_CONDUCT.md` | Covenant text is CC BY 4.0 |
| [agents.md](https://agents.md) | The `AGENTS.md` convention this project follows | Not applicable |

## Not used

[TypeSafe AI Jev](https://typesafe.ai/) is discussed as an optional
experiment in `safety/safety-guardrail.md`. It is not a dependency and
nothing here calls it.

## Keeping this file honest

When a playbook or script starts using a new tool or service, add a row
here in the same change. Add secrets and API keys to your environment or
secret store, never to this file or the repository.
