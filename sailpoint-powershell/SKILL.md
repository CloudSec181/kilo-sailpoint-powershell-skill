---
name: sailpoint-powershell
description: Use this skill whenever writing, optimizing, reviewing, or debugging PowerShell code that interacts with SailPoint Identity Security Cloud (ISC / IdentityNow). Triggers include any mention of SailPoint, ISC, IdentityNow, PSSailpoint, sailpoint-oss, tenant.api.identitynow.com, Personal Access Tokens (PAT), or any PowerShell script that calls SailPoint APIs via either the official PSSailpoint SDK (PSSailpoint, PSSailpoint.Beta, PSSailpoint.V3, PSSailpoint.V2024) or direct REST calls (Invoke-RestMethod / Invoke-WebRequest against /v3, /beta, or /v2024 endpoints). Use this skill for tasks involving identities, accounts, sources, entitlements, access profiles, roles, certifications, workflows, search, transforms, OAuth client credentials, pagination, rate limiting, retries, or PAT-based authentication against ISC. Apply this skill even when the user does not explicitly say "use the SailPoint skill" — if the request involves SailPoint and PowerShell, this skill applies.
---

# SailPoint ISC + PowerShell Expert

This skill turns the agent into a senior engineer for SailPoint Identity Security Cloud (ISC, formerly IdentityNow) automation in PowerShell. It covers writing new scripts, optimizing existing ones, enforcing team coding standards, and applying the right idioms for authentication, pagination, error handling, and retries.

The team uses a mix of the official **PSSailpoint SDK** modules and **direct REST** calls (`Invoke-RestMethod`). Both are valid; pick the right tool per task using the guidance in `references/sdk-vs-rest.md`.

## Before writing or changing any code

Work through these steps every time, in order. They prevent the most common failure modes.

1. **Identify the API surface.** Is this an account, identity, source, entitlement, access profile, role, certification, workflow, search, or transform operation? The answer determines which API version (V3, V2024, Beta) and which cmdlet or endpoint to use.
2. **Choose SDK vs REST.** Default to the SDK when an idiomatic cmdlet exists. Fall back to `Invoke-RestMethod` only when the SDK lacks coverage, when you need fine-grained control over headers or body shape, or when the team has an existing REST helper for the area. See `references/sdk-vs-rest.md`.
3. **Confirm the API version.** ISC versions endpoints (`/v3`, `/v2024`, `/beta`). The SDK mirrors this with `PSSailpoint.V3`, `PSSailpoint.V2024`, and `PSSailpoint.Beta`. Never mix versions in the same logical call. Prefer GA (`V3`/`V2024`) over `Beta` unless Beta is the only option.
4. **Plan auth.** Scripts authenticate via PAT (OAuth2 client credentials). Never hardcode secrets. See `references/auth-and-config.md`.
5. **Plan for scale.** Any list endpoint returns up to 250 records per page by default. If the result set could exceed 250, pagination is required, not optional. See `references/patterns.md`.
6. **Plan failure handling.** Network errors, 429 rate limits, and 5xx responses are expected at scale. Every script that runs unattended needs try/catch and retry with backoff. See `references/patterns.md`.

## Core principles

These apply to every script.

**Use approved PowerShell verbs and `PascalCase-Noun` naming.** `Get-IscAccounts`, not `getAccounts`. Run `Get-Verb` if unsure. This matters because SailPoint scripts get reused across the team; predictable names compound.

**Always declare `[CmdletBinding()]` and parameters with types.** Scripts without parameter blocks become unmaintainable the moment a second person touches them. Include `[Parameter(Mandatory)]` for required inputs and validate with `[ValidateNotNullOrEmpty()]`, `[ValidateSet(...)]`, or `[ValidatePattern(...)]`.

**Set `$ErrorActionPreference = 'Stop'` at the top of any script that calls APIs.** PowerShell's default of `Continue` silently swallows API failures and produces confusing downstream behavior. Stop early, log, fail loudly.

**Never store secrets in scripts or in source control.** PAT credentials live in environment variables (`SAIL_BASE_URL`, `SAIL_CLIENT_ID`, `SAIL_CLIENT_SECRET`), in a `config.json` excluded by `.gitignore`, or in a secret store (Azure Key Vault, CredentialManager, SecretManagement). See `references/auth-and-config.md`.

**Prefer the SDK's built-in helpers over hand-rolled equivalents.** Specifically: use `Invoke-Paginate` for paginated list calls, use the SDK's typed parameters instead of constructing query strings, and let the SDK handle token refresh. Rewriting these by hand is a leading source of bugs.

**Log structured progress with `Write-Verbose` and `Write-Information`, not `Write-Host`.** `Write-Host` cannot be captured, redirected, or suppressed cleanly. Use `Write-Verbose` for diagnostic detail (visible with `-Verbose`), `Write-Warning` for recoverable problems, and `throw` for unrecoverable ones.

**Output objects, not strings.** A function that returns `[pscustomobject]` (or SDK-typed objects) composes with `Where-Object`, `Select-Object`, `Export-Csv`, and the pipeline. A function that returns `Write-Host` output is a dead end. Reserve formatted strings for the very top layer (the script's final report).

**Test against a non-production tenant first.** Many ISC endpoints are destructive or trigger workflows. When optimizing or refactoring, run the new and old versions side by side against a sandbox tenant and diff the outputs before promoting.

## Standard script skeleton

Every new script starts from `templates/new-script.ps1`. It includes the parameter block, error preference, auth verification, logging setup, and an example paginated call. Copy it, then fill in the body. Do not write a script from a blank file when this template exists.

## When optimizing existing scripts

Refactoring patterns specific to SailPoint scripts, in priority order:

1. **Replace manual pagination loops with `Invoke-Paginate`.** Hand-written `do/while` loops over `offset` and `limit` are the #1 source of subtle bugs (off-by-one, infinite loops on empty pages, missed final page). The SDK's helper is correct by construction.
2. **Replace `Invoke-RestMethod` calls with SDK cmdlets where coverage exists.** The SDK handles auth refresh, retries on transient errors, and JSON typing. Only keep direct REST where SDK coverage is genuinely missing or where the script needs custom headers.
3. **Replace `Where-Object` client-side filtering with server-side filters.** ISC supports SCIM-style filters (`?filters=name co "smith"`). Filtering server-side is dramatically faster and avoids pulling the full dataset.
4. **Replace string concatenation in URLs with proper parameter handling.** `"$baseUrl/v3/accounts?filters=$filter"` is brittle and unsafe with special characters. Use the SDK or `[System.Web.HttpUtility]::UrlEncode`.
5. **Replace bare `try/catch` with structured error handling and retry-with-backoff** on transient errors (429, 502, 503, 504). See `references/patterns.md`.
6. **Replace synchronous-per-item loops with batched calls** where the API supports it (bulk identity refresh, bulk entitlement updates).
7. **Replace `Write-Host` with proper streams** as described above.

When you refactor, narrate the change: what was wrong, what changed, and why it's safer or faster. Don't just rewrite silently.

## Reference files

Load these on demand when the task touches their domain. They are organized so a single SKILL.md read gets the agent oriented, and deeper detail loads only when needed.

- `references/auth-and-config.md` — PAT creation, OAuth2 client credentials flow, `config.json` schema, environment variable setup, secret management options, token lifetime and refresh.
- `references/patterns.md` — Pagination (SDK and REST), search with Elasticsearch DSL, error handling and retry-with-exponential-backoff, rate limit (429) handling, batch operations.
- `references/sdk-vs-rest.md` — Decision tree for choosing between PSSailpoint SDK and `Invoke-RestMethod`, with a translation table showing equivalent calls in both styles.
- `references/coding-standards.md` — The team's PowerShell style guide: naming, formatting, comments, headers, parameter conventions, output conventions. **Treat these as binding for any new or refactored code.**

## Templates

- `templates/new-script.ps1` — Skeleton for a new script. Includes parameter block, error preference, auth check, logging setup, paginated call example, and structured error handling.

## What to do when the SDK doesn't cover something

This happens periodically — a new ISC endpoint ships in Beta before the SDK is updated, or there's a niche admin endpoint that was never wrapped. The right pattern is:

1. Check the SDK reference for the closest matching cmdlet first: https://developer.sailpoint.com/docs/tools/powershell/reference/
2. If genuinely absent, write a thin REST helper following the pattern in `references/sdk-vs-rest.md` — get a token via the SDK's auth, then use `Invoke-RestMethod` with the bearer token. Don't roll your own OAuth flow.
3. Wrap the REST call in a function with the same naming conventions as the SDK cmdlets (`Get-IscFooBar`, `Set-IscFooBar`). This way the call site is indistinguishable from native SDK usage and is easy to swap out when the SDK catches up.

## Common pitfalls to flag in review

When reviewing someone else's code, watch for these. Each one is a real bug we have seen.

- Missing pagination on a list endpoint — the script "works" with 200 records and silently truncates at 250 in production.
- Hardcoded tenant URL or PAT — works for the author, breaks for everyone else, and is a security issue.
- `$ErrorActionPreference` not set — errors get swallowed, partial runs look successful.
- Client-side filtering of a full dataset that could have been server-side filtered.
- Catching all exceptions and continuing — masks 429 rate limits, 401 auth failures, and 5xx errors that should retry.
- Polling without backoff — hammers the API and triggers rate limiting that then masks itself.
- Mixing API versions in the same logical operation (e.g., creating with V3 and reading with Beta).
- Using `Write-Host` for anything other than top-level human-facing output.
- No `-WhatIf` / `-Confirm` support on destructive operations (delete identity, revoke access).

When you spot one, point to the exact line and suggest the fix concretely. Don't just say "needs error handling" — show the try/catch block that should replace it.
