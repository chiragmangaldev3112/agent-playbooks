# Playbook flows

A visual map of every playbook's actual process — the shape of what happens, not the detailed rules and anti-patterns behind each step (those are delivered on install; see the main [README](README.md)). Each diagram mirrors the real numbered process in that playbook, not a simplified stand-in.

## Core

### `core/engineering-loop.md`

Router + independent-verification rule — start every task here

```mermaid
flowchart TD
    A[Request comes in] --> B{Classify against\nplaybook triggers}
    B -->|Ambiguous| C[clarify-before-building.md]
    B -->|Unsorted report| D[issue-triage.md]
    B -->|Matches a playbook| E[Plan the approach]
    C --> E
    D --> E
    E --> F[Implement via\nthe routed playbook]
    F --> G[Verify independently—\nfresh, evidence-based pass]
    G -->|Fails| F
    G -->|Passes| H{Matches AGENTS.md\nrule 5?}
    H -->|Yes| I[Stop, ask\nfor confirmation]
    H -->|No| J[Report]
    I -->|Approved| J
```

### `core/bug-fix.md`

Reproduce-before-fix workflow

```mermaid
flowchart TD
    A[Bug reported] --> B[Reproduce it]
    B -->|Can't reproduce| C[Ask for more detail]
    B -->|Reproduced| D[Isolate smallest\nfailing case]
    D --> E[Fix the root cause]
    E --> F[Re-run repro +\nfull test suite]
    F -->|Still fails| D
    F -->|Passes| G[Report]
```

### `core/feature-development.md`

Test-first feature workflow

```mermaid
flowchart TD
    A[Feature request] --> B{Spec ambiguous\nin a way that\nchanges the design?}
    B -->|Yes| C[Ask, don't guess]
    B -->|No / resolved| D[Write failing test]
    D --> E[Confirm it fails\nfor the right reason]
    E --> F[Implement minimum code]
    F --> G[Run full suite,\nconfirm new test passes]
    G -->|New test still fails| F
    G -->|Passes, no regressions| H[Report]
```

### `core/clarify-before-building.md`

Resolve a genuinely ambiguous request before implementation starts

```mermaid
flowchart TD
    A[Request has\napparent ambiguity] --> B{Would two reasonable\nanswers change\nwhat gets built?}
    B -->|No| C[Not a real fork—\npick one, proceed]
    B -->|Yes| D[Ask specific,\nanswerable questions]
    D --> E[Batch all blocking\nquestions together]
    E --> F[Write the resolved\ndecision down]
    F --> G[Proceed to\nfeature-development.md\nor bug-fix.md]
```

### `core/issue-triage.md`

Sort a new bug/enhancement report into a category and status

```mermaid
flowchart TD
    A[New report arrives] --> B[Assign category:\nDefect or Enhancement]
    B --> C{Actionable as-is?}
    C -->|No| D[Incomplete—\nask for the specific gap]
    C -->|Yes| E{Being worked\nright now?}
    E -->|No| F[Deferred or Declined\n+ written reason]
    E -->|Yes| G[Ready →\nengineering-loop.md]
    G --> H[Resolved, once\nindependently verified]
    D -->|Info arrives| B
```


## Quality

### `quality/code-review.md`

Diff review checklist

```mermaid
flowchart TD
    A[Diff/PR to review] --> B[Get the real diff]
    B --> C[Check correctness\n+ edge cases]
    C --> D[Check security—\nsecurity-review.md]
    D --> E[Check convention\nadherence]
    E --> F[Confirm tests\nactually ran]
    F --> G[Report: Blocking /\nSuggestions / Confirmed good]
```

### `quality/security-review.md`

Language-agnostic security checklist

```mermaid
flowchart TD
    A[Diff to review] --> B[Get the real diff]
    B --> C[Walk every changed file\nagainst the checklist]
    C --> D{Concrete exploitable\nscenario exists?}
    D -->|No| E[Not a finding—\nnote as investigated]
    D -->|Yes| F[Record: file, line,\nscenario, severity]
    F --> G[Rank by severity]
    G --> H[Report]
```

### `quality/architecture-review.md`

Design-level review: visibility, failure containment, access boundaries, operational control

```mermaid
flowchart TD
    A[Design to review] --> B[Add system-specific\nitems to the base checklist]
    B --> C[Walk checklist against\nthe actual design]
    C --> D[Name where each item\nis actually satisfied]
    D --> E{Item unsatisfied?}
    E -->|Yes| F[Real gap, or a\ndeliberate tradeoff?]
    E -->|No| G[Next item]
    F --> H[Report gaps ranked by\nwhat breaks first]
```

### `quality/frontend-testing.md`

Test layering for UI code

```mermaid
flowchart TD
    A[UI code to test] --> B{Pick the layer}
    B --> C[Component/unit]
    B --> D[Integration]
    B --> E[End-to-end/browser]
    C --> F[Assert on behavior,\nnot implementation]
    D --> F
    E --> F
    F --> G[Handle async correctly]
    G --> H[Check accessibility]
    H --> I[Run suite: fails without\nchange, passes with it]
    I --> J[Capture video/screenshot\nevidence for E2E]
```

### `quality/backend-testing.md`

Test layering for server code

```mermaid
flowchart TD
    A[API/logic to test] --> B[Derive test matrix\nfrom real schema]
    B --> C{Pick the layer}
    C --> D[Unit]
    C --> E[Integration—\nreal dependency]
    C --> F[Contract]
    D --> G[Cover auth,\nconcurrency, idempotency]
    E --> G
    F --> G
    G --> H[Manage test\ndata deliberately]
    H --> I[Run suite: new test\nfails, then passes]
```

### `quality/docs-sync.md`

Verify doc claims against real code, run the project's real linter

```mermaid
flowchart TD
    A[Docs may be stale] --> B[Inventory\ndoc claims]
    B --> C[Verify each claim\nagainst real code]
    C --> D[Run the real linter]
    C --> E{Classify the claim}
    E -->|Accurate| F[Leave alone]
    E -->|Drifted| G[Update to\nmatch code]
    E -->|Orphaned| H[Remove]
    C --> I{Real capability with\nno doc coverage?}
    I -->|Yes| J[Flag—ask before\nwriting new docs]
```

### `quality/observability.md`

Instrument a feature so its failures surface before a user reports them

```mermaid
flowchart TD
    A[Feature going to prod] --> B[Name 1-2 signals\nthat reveal failure]
    B --> C[Log at decision\n+ failure points]
    C --> D{Page someone,\nor just record?}
    D -->|Alert-worthy| E[Wire to a\nreal alert]
    D -->|Diagnostic only| F[Log/dashboard only]
    E --> G[Confirm signal reaches\na real dashboard/alert]
    F --> G
```


## Change types

### `change-types/refactoring.md`

Behavior-preserving restructuring

```mermaid
flowchart TD
    A[Structural change,\nno behavior change] --> B{Tests already\ncover this code?}
    B -->|No| C[Write characterization\ntests first]
    B -->|Yes| D[Confirm they pass]
    C --> E[Make one small step]
    D --> E
    E --> F[Run full suite]
    F -->|Red| E
    F -->|Green| G{More steps\nneeded?}
    G -->|Yes| E
    G -->|No| H{Behavior change\nturned out necessary?}
    H -->|Yes| I[Stop—route to\nbug-fix/feature-development]
    H -->|No| J[Confirm nothing\nobservable changed]
```

### `change-types/dependency-upgrades.md`

Bumping a dependency version safely

```mermaid
flowchart TD
    A[Bump a dependency] --> B[Read changelog for\nbreaking changes]
    B --> C[Check how it's\nactually used here]
    C --> D[Upgrade one dependency\nat a time]
    D --> E[Run full test suite]
    E --> F{Coverage incomplete\nfor this area?}
    F -->|Yes| G[Actually run the app]
    F -->|No| H{Security-driven\nupgrade?}
    G --> H
    H -->|Yes| I[Confirm CVE\nactually addressed]
    H -->|No| J[Done]
    I --> J
```

### `change-types/database-migration.md`

Safe schema changes via expand/migrate/contract

```mermaid
flowchart TD
    A[Schema change] --> B{Additive\nor breaking?}
    B -->|Additive| C[Safe by default]
    B -->|Breaking| D[Expand: add new\nshape alongside old]
    D --> E[Migrate: backfill,\ndual-write]
    E --> F[Contract: remove old\nonce all callers moved]
    C --> G[Write rollback before\nforward migration]
    F --> G
    G --> H[Test against realistic\nconcurrent access]
    H --> I[Run against\nreal data copy]
    I --> J[Confirm before\nshared/production]
    J --> K[Query real state after\neach stage, confirm it matches]
```

### `change-types/incident-response.md`

Restore service first, root-cause after

```mermaid
flowchart TD
    A[Live outage] --> B[Assess blast radius]
    B --> C{Rollback available?}
    C -->|Yes| D[Roll back]
    C -->|No / equal harm| E[Forward-fix]
    D --> F[Verify via real signal,\nnot command success]
    E --> F
    F -->|Still broken| B
    F -->|Restored| G[Root-cause properly,\nno longer under pressure]
    G --> H[Write down\nwhat happened]
```

### `change-types/release.md`

Decide blast-radius limits and rollback path before a release starts

```mermaid
flowchart TD
    A[Change ready to ship] --> B{Risk level?}
    B -->|Low| C[Deploy normally]
    B -->|Higher| D[Pick rollout mechanism:\nflag / staged / window]
    D --> E[Decide rollback\npath up front]
    E --> F[Name the health signal]
    F --> G[Release to a small stage]
    G --> H[Watch the signal]
    H -->|Degraded| I[Roll back →\nincident-response.md]
    H -->|Healthy| J{More exposure\nto reach?}
    J -->|Yes| K[Confirm before\nwidening]
    K --> G
    J -->|No| L[Done]
```

### `change-types/performance.md`

Profile before optimizing, measure the same way after

```mermaid
flowchart TD
    A[Reported slowdown] --> B[Profile before\ntouching anything]
    B --> C[Reproduce under\nrealistic conditions]
    C --> D[Identify actual\nbottleneck]
    D --> E[Smallest change\nthat addresses it]
    E --> F[Measure again,\nsame way]
    F --> G[Run full test suite]
    G -->|Regressed| E
    G -->|Faster, no regression| H[State any\ntradeoff explicitly]
```


## Autonomy

### `autonomy/mission-mode.md`

Standing-objective autonomous operation, with an explicit autonomy dial

```mermaid
flowchart TD
    A[Standing mission written] --> B[Pick autonomy level:\nsupervised/bounded/full-lights-out]
    B --> C[Perceive real\ncurrent state]
    C --> D[Plan next\nhighest-value item]
    D --> E[Act via\nengineering-loop.md]
    E --> F[Verify independently]
    F --> G{Hard stop or\nescalation trigger?}
    G -->|Yes| H[Stop, surface it]
    G -->|No| I[Report, repeat]
    I --> C
```

### `autonomy/roles.md`

Reusable personas, and when delegating to one is worth it

```mermaid
flowchart TD
    A{Need to delegate?} -->|Can't state the exact ask,\nor can't verify the answer| B[Do it directly]
    A -->|Can do both| C{Existing persona fits?}
    C -->|Yes| D[Use it: Bug Hunter,\nFeature Builder, Code Reviewer,\nTest Writer, Manual Tester,\nProject Bootstrapper]
    C -->|No| E[Define new role:\nname, remit,\nplaybook, access level]
    D --> F[Follow its\nlinked playbook exactly]
    E --> F
```

### `autonomy/standing-permission.md`

A written, bounded grant letting the agent skip per-action confirmation for explicitly named actions only

```mermaid
flowchart TD
    A[Human writes grant:\nactions + scope + duration] --> B[Agent hits an action]
    B --> C{Literally named\nin the grant?}
    C -->|No| D[Ungranted—\nnormal confirmation gate]
    C -->|Yes| E{On the permanent\nfloor list?}
    E -->|Yes—destructive/\nguardrail-blocked| D
    E -->|No| F[Proceed without asking]
    F --> G[Log action + which\ngrant line covered it]
    D --> H[Ask for confirmation]
```


## Safety

### `safety/safety-guardrail.md`

A real, enforced block on destructive shell commands

```mermaid
flowchart TD
    A[Command about to run] --> B[block-dangerous.sh checks\nagainst deny_patterns]
    B -->|Matches destructive pattern| C[Exit 2: blocked,\nreason on stderr]
    B -->|Safe| D[Exit 0: runs normally]
    C --> E[Hard block\nin the tool]
```

### `safety/memory-hygiene.md`

Don't trust a remembered fact once its source code has changed

```mermaid
flowchart TD
    A[Recalled memory\nabout code] --> B{References specific\ncode/file/symbol?}
    B -->|No—a preference\nor decision| C[Label as stated intent,\nnot a code fact]
    B -->|Yes| D[Re-check the\nsource it's about]
    D --> E{Still matches?}
    E -->|Yes| F[Treat as valid]
    E -->|No / gone| G[Treat as unverified—\nre-derive from current code]
```

### `safety/sensitive-data.md`

Classify data before deciding how strictly to handle it

```mermaid
flowchart TD
    A[Feature touches personal/\nsensitive data] --> B[Classify: direct /\nindirect / not sensitive]
    B -->|Unsure| C[Treat as more sensitive\nuntil confirmed]
    B --> D[Minimize what's\ncollected/stored]
    D --> E[Encrypt at rest\n+ in transit]
    E --> F[Keep out of logs,\nerrors, analytics]
    F --> G[Define retention\n+ deletion story]
    G --> H[Restrict access\nto minimum needed]
```


## Top level

### `project-bootstrap.md`

Onboard an agent to an unfamiliar repo, and wire the guardrail + personas into it

```mermaid
flowchart TD
    A[Unfamiliar repo] --> B[Detect real stack\nfrom actual files]
    B --> C[Write grounded AGENTS.md]
    C --> D{Tool supports\na hook mechanism?}
    D -->|Yes| E[Wire safety-guardrail.md]
    D -->|No| F[Say so explicitly—\ndon't fake it]
    E --> G{Tool supports\nsub-agents?}
    F --> G
    G -->|Yes| H[Install roles.md personas]
    G -->|No| I[Skip honestly]
    H --> J[Offer standing-permission\ngrant, don't assume one]
    I --> J
    J --> K[Verify: run test/lint,\ntest the guardrail]
    K --> L[Report summary]
```

### `codebase-mapping.md`

Document a codebase module by module from real dependency structure

```mermaid
flowchart TD
    A[Document a codebase] --> B[Find real module boundaries\nfrom the dependency graph]
    B --> C[Read each module's\ninterface + tests]
    C --> D[Write + verify\none doc per module]
    D --> E{Skill/agent\nrequested?}
    E -->|No| F[Done—docs are\nthe deliverable]
    E -->|Yes| G[Generate in tool's format,\ngrounded in verified doc]
    G --> H[Verify generated\nskill with a real question]
```

### `database-mapping.md`

Document a database table by table from the real schema and code usage

```mermaid
flowchart TD
    A[Document a database] --> B[Read real schema /\nmigration history]
    B --> C[Capture constraints\nper column]
    C --> D[Record relationships,\nenforced or not]
    D --> E[Cross-reference against\nreal code usage]
    E --> F{Name matches\nreal meaning?}
    F -->|No| G[Flag naming mismatch]
    F -->|Yes| H[Write + verify\ntable doc]
    G --> H
    H --> I{Skill/agent\nrequested?}
    I -->|Yes| J[Generate, grounded\nin verified doc]
    I -->|No| K[Done]
```

### `third-party-api-integration.md`

Analyze and test a third-party API for real, credentials never handled or logged

```mermaid
flowchart TD
    A[Integrate external API] --> B[Phase 1: read all docs\nin batches]
    B --> C[Extract endpoints,\nauth, response shapes]
    C --> D[Phase 2: name env var\nfor the credential]
    D --> E{Human pastes\nraw key anyway?}
    E -->|Yes| F[Treat as compromised,\nrequire rotation]
    E -->|No| G[Write script reading\nfrom env var, masked output]
    F --> G
    G --> H[Call real API,\ncompare vs docs]
    H --> I{Asked to link\nto the schema?}
    I -->|No| J[Done—tested\nand understood]
    I -->|Yes| K[Phase 3: map fields\nvs database-mapping.md]
    K --> L[Propose migration—\nnever apply directly]
```

### `project-audit.md`

Audit a whole project, then fix only what's explicitly approved

```mermaid
flowchart TD
    A[Audit a project] --> B[Run existing checklists\nat project scope]
    B --> C[Record findings:\nwhere, why, severity]
    C --> D[Report, ranked\nby impact]
    D --> E[Stop—wait for\nexplicit approval]
    E -->|Approved subset| F[Route each fix through\nengineering-loop.md]
    F --> G[Independently\nreverify each fix]
    G --> H[Report fixed /\ndeferred / open]
```

### `demo-video.md`

Generate a narrated screen-recording demo from a script

```mermaid
flowchart TD
    A[Write script:\nSAY/SHOW lines] --> B[Generate voice-over\nnarrate.sh]
    B --> C[Generate captions\ncaptions.sh]
    C --> D[Record screen\nrecord-screen.sh]
    D --> E[Assemble video + narration\n+ captions assemble.sh]
    E --> F[Watch it—confirm timing\nactually lines up]
```

