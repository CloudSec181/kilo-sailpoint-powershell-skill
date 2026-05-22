# SailPoint PowerShell Skill for Kilo Code

A [Kilo Code](https://kilo.ai) [Agent Skill](https://kilo.ai/docs/customize/skills) that turns the agent into a senior engineer for SailPoint Identity Security Cloud (ISC, formerly IdentityNow) automation in PowerShell.

The skill covers writing new scripts from scratch, refactoring and optimizing existing scripts, and enforcing team coding standards. It supports both the official [PSSailpoint SDK](https://developer.sailpoint.com/docs/tools/sdk/powershell/) and direct REST calls (`Invoke-RestMethod`) against the ISC API.

---

## Table of Contents

- [Why this exists](#why-this-exists)
- [What the skill does](#what-the-skill-does)
- [Repository layout](#repository-layout)
- [Installation](#installation)
- [Verifying it works](#verifying-it-works)
- [Usage examples](#usage-examples)
- [Customizing for your team](#customizing-for-your-team)
- [Requirements](#requirements)
- [How Kilo Skills work](#how-kilo-skills-work)
- [Updating the skill](#updating-the-skill)
- [Contributing](#contributing)
- [License](#license)
- [Acknowledgements](#acknowledgements)

---

## Quick Start

```bash
# Clone directly into your project's skills directory
cd your-project
mkdir -p .kilo/skills
git clone https://github.com/CloudSec181/kilo-sailpoint-powershell-skill.git .kilo/skills/_source
ln -s _source/sailpoint-powershell .kilo/skills/sailpoint-powershell

# Or clone globally for all projects (macOS/Linux)
mkdir -p ~/.kilo/skills
git clone https://github.com/CloudSec181/kilo-sailpoint-powershell-skill.git /tmp/sp-skill
cp -r /tmp/sp-skill/sailpoint-powershell ~/.kilo/skills/
rm -rf /tmp/sp-skill
```

Restart your Kilo session. The skill activates automatically when you mention SailPoint, ISC, IdentityNow, or PSSailpoint.

---

## Why this exists

SailPoint PowerShell scripts have a small number of recurring failure modes — missed pagination, swallowed errors, hardcoded secrets, hand-rolled OAuth, retry loops without backoff, mixed API versions. The fixes are well-known but easy to forget when you're under time pressure or new to the platform.

This skill bakes those fixes into the agent's working memory. When you ask Kilo to write or review a SailPoint script, it loads the skill, runs through a checklist before producing code, and follows your team's conventions instead of inventing its own.

The goal is not "AI writes our scripts for us." The goal is **every script the team ships, AI-written or not, matches the same quality bar** — because the agent reviewing or drafting it knows what good looks like.

---

## What the skill does

Concretely, when triggered, the skill makes the agent:

- **Run a pre-flight checklist before writing any code.** Identify the API surface (identity, account, source, entitlement, etc.), choose SDK vs REST, confirm the API version (V3 / V2024 / Beta), plan auth, plan for pagination, plan for failure handling.
- **Default to the right idioms.** `Invoke-Paginate` over hand-rolled pagination loops. Server-side filters over client-side `Where-Object`. Structured error capture (`detailCode`, `messages`, response headers) over bare `$_.Exception.Message`. Exponential backoff that honors `Retry-After` over fixed sleeps.
- **Enforce team coding standards.** Approved verbs, `Verb-IscNoun` naming, `[CmdletBinding(SupportsShouldProcess)]`, `Set-StrictMode -Version Latest`, `$ErrorActionPreference = 'Stop'`, typed parameters with validation, output objects (not strings), proper PowerShell streams (`Write-Verbose` / `Write-Information` / `Write-Warning`, never `Write-Host` for data).
- **Refactor existing scripts safely.** A prioritized refactoring playbook: pagination first, SDK adoption second, server-side filters third, structured errors fourth, retries fifth, batching sixth.
- **Flag common pitfalls during review.** Each pitfall maps to a real bug we've seen in production scripts.

---

## Repository layout

```
sailpoint-powershell-skill/
├── README.md                       ← you are here
├── LICENSE
├── CHANGELOG.md
├── CONTRIBUTING.md
├── .gitignore
└── sailpoint-powershell/           ← the actual skill folder
    ├── SKILL.md                    ← triggering metadata + core checklist
    ├── references/
    │   ├── auth-and-config.md      ← PAT setup, OAuth2, secret storage
    │   ├── patterns.md             ← pagination, errors, retries, search
    │   ├── sdk-vs-rest.md          ← decision tree + translation table
    │   └── coding-standards.md     ← team style guide (customize this)
    ├── examples/                   ← gold-standard SDK examples
    │   ├── README.md               ← index and sourcing info
    │   ├── paginate-accounts.ps1   ← Invoke-Paginate with filters
    │   ├── paginate-search.ps1     ← Invoke-PaginateSearch with ES DSL
    │   ├── patch-entitlement.ps1   ← JSON Patch via Beta API
    │   ├── get-accounts.ps1        ← basic list with params
    │   ├── search.ps1              ← Search-Post with proxy
    │   └── create-transform.ps1    ← transform creation from JSON
    └── templates/
        └── new-script.ps1          ← starter script with all conventions
```

Only the `sailpoint-powershell/` folder needs to land in your Kilo skills directory. The rest is repo-level documentation and metadata.

---

## Installation

### Project-level (recommended for team use)

Place the skill folder inside your project's `.kilo/skills/` directory:

```
your-project/
└── .kilo/
    └── skills/
        └── sailpoint-powershell/
            ├── SKILL.md
            ├── references/
            └── templates/
```

Commit it. Everyone on the team picks it up automatically on their next Kilo session.

**Option A — git submodule (keeps the skill in sync with this repo):**

```bash
cd your-project
mkdir -p .kilo/skills
git submodule add https://github.com/CloudSec181/kilo-sailpoint-powershell-skill.git .kilo/skills/_source
ln -s _source/sailpoint-powershell .kilo/skills/sailpoint-powershell
```

**Option B — vendored copy (snapshot in time):**

```bash
cd your-project
mkdir -p .kilo/skills
cp -r /path/to/cloned/kilo-sailpoint-powershell-skill/sailpoint-powershell .kilo/skills/
```

**Option C — sparse checkout (just the skill, no repo overhead):**

```bash
cd your-project/.kilo/skills
git clone --depth 1 --filter=blob:none --sparse https://github.com/CloudSec181/kilo-sailpoint-powershell-skill.git tmp
cd tmp && git sparse-checkout set sailpoint-powershell && cd ..
mv tmp/sailpoint-powershell .
rm -rf tmp
```

### Global (personal, all projects)

Place the skill folder in your home directory:

- **macOS / Linux:** `~/.kilo/skills/sailpoint-powershell/`
- **Windows:** `%USERPROFILE%\.kilo\skills\sailpoint-powershell\`

```bash
# macOS / Linux
mkdir -p ~/.kilo/skills
cp -r sailpoint-powershell ~/.kilo/skills/
```

```powershell
# Windows PowerShell
New-Item -ItemType Directory -Force -Path "$env:USERPROFILE\.kilo\skills"
Copy-Item -Recurse .\sailpoint-powershell "$env:USERPROFILE\.kilo\skills\"
```

### Remote URL (Kilo CLI)

If you'd rather not vendor the files, point Kilo at a raw `SKILL.md` URL in your `kilo.jsonc`:

```jsonc
{
  "skills": {
    "urls": [
      "https://raw.githubusercontent.com/CloudSec181/kilo-sailpoint-powershell-skill/main/sailpoint-powershell/SKILL.md"
    ]
  }
}
```

Note: remote URL loading fetches the top-level `SKILL.md` on demand but does not currently load bundled reference files automatically. Vendoring (Options A–C above) is preferred when you want the full skill experience.

---

## Verifying it works

After installing, start a new Kilo session — skills are scanned at session start, not live.

Ask the agent directly:

> Do you have access to the `sailpoint-powershell` skill?

The agent should confirm and briefly describe what the skill covers. If it doesn't, see [Troubleshooting](#troubleshooting) below.

You can also confirm by watching for a `skill` tool call in the conversation when you give it a relevant prompt — that's the agent loading the full `SKILL.md` into context.

### Troubleshooting

If the skill isn't loading:

1. **Path check.** `SKILL.md` must be at `.kilo/skills/sailpoint-powershell/SKILL.md` — directly inside the named folder, not nested further.
2. **Name match.** The `name:` field in the YAML frontmatter must exactly match the folder name (`sailpoint-powershell`).
3. **New session.** Skills are loaded at session start. Restart your Kilo session after installing.
4. **VS Code only.** Open `View → Output → "Kilo Code"` from the dropdown and look for skill-related errors.

---

## Usage examples

Once installed, the skill triggers automatically when you mention SailPoint, PSSailpoint, ISC, IdentityNow, or describe work that touches the SailPoint API. You don't need to invoke it explicitly.

### Writing a new script

> Write a PowerShell script that exports all disabled accounts from source `7a8b9c...` to CSV, with proper pagination and error handling.

Expected: the agent loads the skill, copies the `templates/new-script.ps1` skeleton, fills in the body using `Invoke-Paginate` against `Get-Accounts` with server-side filters, wraps the call in `Invoke-IscWithRetry`, and emits `[pscustomobject]` rows that pipe to `Export-Csv`.

### Optimizing an existing script

> Review this script and tell me what's wrong with it.
>
> ```powershell
> $offset = 0
> $all = @()
> do {
>     $page = Invoke-RestMethod -Uri "https://tenant.api.identitynow.com/v3/identities?offset=$offset&limit=100"
>     $all += $page
>     $offset += 100
> } while ($page.Count -gt 0)
> ```

Expected: the agent identifies the missing auth header, hardcoded tenant URL, missing error handling, missing retry logic, suboptimal page size (100 instead of 250), and the infinite-loop risk (stops at empty page rather than partial page). Then it shows the corrected version.

### Asking about patterns

> What's the right way to handle 429 rate limit errors when calling `Get-Identities` in a long-running script?

Expected: the agent loads `references/patterns.md` and walks through the `Invoke-IscWithRetry` helper — exponential backoff with a cap, honoring `Retry-After`, distinguishing transient from permanent failures.

### Choosing SDK vs REST

> I need to call a Beta endpoint that doesn't have a PSSailpoint cmdlet yet. What's the right pattern?

Expected: the agent loads `references/sdk-vs-rest.md`, walks the decision tree, and produces a thin REST helper named `Get-IscFooBar` (matching SDK conventions) that uses `Get-IscAccessToken` for auth and is wrapped in the same retry logic as native SDK calls.

---

## Customizing for your team

The skill ships with sensible defaults. Two changes are worth making before you roll it out widely.

### 1. Edit `references/coding-standards.md`

This is the team's style guide. The defaults (approved verbs, `Verb-IscNoun` naming, splatting at 3+ params, 4-space indent, no `Write-Host` for data) are reasonable but they're not yours. Edit them to match what your team already does or wants to do.

Once edited, this file becomes the single source of truth — both for humans on code review and for the agent when drafting or refactoring scripts.

### 2. Add gold-standard example scripts

The single highest-leverage change you can make. Drop 1–3 of your team's best existing scripts into a new `sailpoint-powershell/examples/` folder, then add a section to `SKILL.md` pointing to them:

```markdown
## Examples

Reference these when in doubt about how a real script should look:

- `examples/export-identities.ps1` — canonical paginated export with retries
- `examples/bulk-disable-accounts.ps1` — destructive op with `-WhatIf` and confirmation
- `examples/sync-entitlement-descriptions.ps1` — patch updates with JSON Patch
```

Real examples from your codebase outperform any generic guidance. The agent uses them as templates and matches their idioms.

### 3. (Optional) Tighten the description

The `description:` field in `SKILL.md` controls when the skill triggers. The default is intentionally broad. If you find it triggering on non-SailPoint PowerShell tasks too aggressively, narrow it. If it's missing relevant tasks, broaden it. Edit and start a new Kilo session to test.

---

## Requirements

The skill itself has no install dependencies — it's just Markdown files. The PowerShell scripts it produces require:

- **PowerShell 7.0 or later.** PowerShell 5.1 mostly works but the skill targets 7+ for null-coalescing, ternary operators, and consistent error handling.
- **PSSailpoint SDK modules** (when using SDK-style calls):
  ```powershell
  Install-Module -Name PSSailpoint        -Scope CurrentUser
  Install-Module -Name PSSailpoint.Beta   -Scope CurrentUser
  Install-Module -Name PSSailpoint.V3     -Scope CurrentUser
  Install-Module -Name PSSailpoint.V2024  -Scope CurrentUser
  ```
- **A Personal Access Token (PAT)** with appropriate scopes for the operations the script performs. See `sailpoint-powershell/references/auth-and-config.md`.
- **Tenant URL** in the form `https://[tenant].api.identitynow.com`.

The skill also references but does not require:
- `Microsoft.PowerShell.SecretManagement` (recommended for production secret storage).
- The [SailPoint CLI](https://developer.sailpoint.com/docs/tools/cli) (handy for bootstrapping `config.json`).

---

## How Kilo Skills work

If you're new to Kilo Skills, the model is simple:

1. **Discovery.** When Kilo starts, it scans the skills directories and reads only the `name` and `description` from each `SKILL.md`. The full content is not loaded yet — this keeps the context window small.
2. **Decision.** When you give Kilo a task, the agent checks all available skill descriptions and decides whether one applies. The decision is made by the language model, not by keyword matching.
3. **Loading.** If a skill applies, the agent reads the full `SKILL.md` into context and follows the instructions. From there it can load additional files (like the ones in `references/`) on demand.

This means **the `description:` field is the single most important line in the whole skill.** It's the only thing the agent sees until it decides to load the rest. Be specific about both what the skill does and when it should be used.

For the full mental model, see Kilo's [Skills documentation](https://kilo.ai/docs/customize/skills) and the open [Agent Skills specification](https://agentskills.io/specification).

---

## Updating the skill

Edit any file and start a new Kilo session — changes are picked up on session start, not live.

To distribute updates across your team:

1. Commit changes to whichever branch your team treats as canonical (`main`, usually).
2. If you used the git submodule install (Option A), teammates run `git submodule update --remote .kilo/skills/_source` to pull updates.
3. If you used a vendored copy (Option B), recopy the folder.
4. If you used remote URL loading, Kilo refetches on next session automatically.

---

## Contributing

Contributions welcome. See [CONTRIBUTING.md](CONTRIBUTING.md) for the full guide. The short version:

- For bug fixes (typos, broken examples, wrong API references), open a PR directly.
- For changes to the team coding standards, open an issue first so we can discuss.
- For new reference files (new patterns, new domains), open an issue with the proposed scope before writing.

When testing changes, install the skill into a sandbox project, restart Kilo, and run the test prompts in [Usage examples](#usage-examples). Confirm the agent loads the skill and produces output matching the updated guidance.

---

## License

[MIT](LICENSE). Use it, fork it, adapt it. If you make improvements that would benefit others, PRs are appreciated.

---

## Acknowledgements

- The [SailPoint Developer Community](https://developer.sailpoint.com) for the [PowerShell SDK](https://github.com/sailpoint-oss/powershell-sdk) and the documentation this skill draws from.
- [Kilo Code](https://kilo.ai) for the agent platform and the open [Agent Skills specification](https://agentskills.io/specification).
- Darren Robinson's [original IdentityNow PowerShell module work](https://blog.darrenjrobinson.com/) for shaping how a generation of SailPoint admins think about PowerShell automation.
