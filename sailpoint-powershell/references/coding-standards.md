# Team Coding Standards

These standards apply to all new and refactored SailPoint PowerShell scripts. They exist because consistency across the team matters more than personal preference; predictable code is reviewable code.

> **Note for the team:** Customize this file for your team. The sections below capture sensible defaults — edit the rules to match your actual conventions, then keep this file as the single source of truth.

## Naming

- **Functions:** `Verb-IscNoun` using approved PowerShell verbs (`Get-Verb` lists them). The `Isc` prefix distinguishes our wrappers from SDK cmdlets and prevents collisions.
  - ✅ `Get-IscIdentityAccounts`, `Set-IscEntitlementDescription`, `Remove-IscStaleAccess`
  - ❌ `getAccounts`, `update-ent`, `RevokeAccess`
- **Parameters:** `PascalCase`, singular when one value, plural when array. `[string] $IdentityId`, `[string[]] $EntitlementIds`.
- **Variables:** `camelCase` for local, `PascalCase` for script-scoped (`$script:Config`).
- **Files:** `Verb-IscNoun.ps1` for functions; `<action>-<target>.ps1` for top-level scripts (`reconcile-orphan-accounts.ps1`).

## Script header

Every top-level script begins with a comment-based help block. This lets `Get-Help script.ps1` produce real documentation.

```powershell
<#
.SYNOPSIS
    Brief one-line description of what this script does.

.DESCRIPTION
    Longer description covering: which ISC objects are read or modified,
    side effects, and any preconditions.

.PARAMETER TenantUrl
    The ISC tenant URL. Defaults to $env:SAIL_BASE_URL.

.PARAMETER WhatIf
    Show what would happen without making changes.

.EXAMPLE
    .\reconcile-orphan-accounts.ps1 -SourceId 'abc123' -WhatIf

.NOTES
    Author:  <name>
    Version: 1.0
    Requires: PSSailpoint, PSSailpoint.V3
#>
```

## Required preamble

Every script starts with these lines. They are not optional.

```powershell
#Requires -Version 7.0
#Requires -Modules PSSailpoint

[CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'Medium')]
param(
    # ...
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
```

Why:
- `#Requires -Version 7.0` — PowerShell 5.1 and 7 differ in subtle ways (null handling, ternary, pipeline parallel). Pin a version.
- `#Requires -Modules` — fails fast if the SDK isn't installed.
- `SupportsShouldProcess` — gives the script `-WhatIf` and `-Confirm` for free. Required on anything destructive.
- `Set-StrictMode -Version Latest` — surfaces typos in variable names and missing properties instead of returning `$null`.
- `$ErrorActionPreference = 'Stop'` — covered in SKILL.md, applies here too.

## Parameter conventions

- Always type parameters. `[string]`, `[int]`, `[switch]`, `[string[]]`. Never untyped.
- Use `[Parameter(Mandatory)]` for required inputs. Don't fall back to prompting in scripts meant for automation.
- Validate inputs:
  - `[ValidateNotNullOrEmpty()]` on every string.
  - `[ValidateSet('A','B','C')]` for enumerated values.
  - `[ValidatePattern('^[a-f0-9]{32}$')]` for IDs with known formats.
- Default sensitive parameters to environment variables:
  ```powershell
  [string] $TenantUrl = $env:SAIL_BASE_URL
  ```

## Output

- **Functions return objects, not strings.** Use `[pscustomobject]@{ ... }` or pass through SDK objects.
- **Use proper streams for non-data output:**
  - `Write-Verbose` for diagnostic detail (`-Verbose` flag enables).
  - `Write-Information` for normal progress messages (`-InformationAction Continue`).
  - `Write-Warning` for recoverable problems.
  - `Write-Error` / `throw` for failures.
  - `Write-Host` only for the script's final human-facing summary, and even then prefer `Write-Information`.
- **Never `return` a formatted table.** Return the objects; let the caller decide how to format.

## Error handling

Every API call is wrapped in try/catch. Every script gets a top-level try/catch that logs and re-throws so the caller knows it failed.

```powershell
try {
    # main work
}
catch {
    Write-Error "Script failed: $($_.Exception.Message)"
    Write-Verbose ($_.ScriptStackTrace)
    throw
}
finally {
    # cleanup
}
```

See `patterns.md` for the full retry-with-backoff helper.

## Logging

- Use `Write-Verbose` and `Write-Information` for progress, not `Write-Host`.
- Include timing information for long operations:
  ```powershell
  $sw = [System.Diagnostics.Stopwatch]::StartNew()
  $accounts = Invoke-Paginate -Function 'Get-Accounts' -Limit 10000
  Write-Verbose "Retrieved $($accounts.Count) accounts in $($sw.Elapsed.TotalSeconds)s"
  ```
- For scheduled scripts, write a structured summary at the end (JSON or CSV) — not log lines. Logs get truncated; summary files are queryable.

## Formatting

- 4-space indent. No tabs.
- Lines under 120 chars where reasonable.
- Use splatting for cmdlets with 3+ parameters:
  ```powershell
  # Good
  $params = @{
      Function      = 'Get-Accounts'
      Increment     = 250
      Limit         = 10000
      InitialOffset = 0
      Parameters    = $filterParams
  }
  $accounts = Invoke-Paginate @params

  # Avoid — hard to read, hard to diff
  $accounts = Invoke-Paginate -Function 'Get-Accounts' -Increment 250 -Limit 10000 -InitialOffset 0 -Parameters $filterParams
  ```
- Use backtick line-continuation only when splatting isn't appropriate. Never end a line with `|` then a newline — put the `|` at the start of the next line, or split via splatting/variables.

## Comments

- Comment why, not what. The code shows what.
- Inline comments stay short and on the same line where possible.
- Block comments (`<# #>`) for sections explaining non-obvious decisions ("we paginate at 100 instead of 250 here because this endpoint times out at larger sizes").
- TODOs include a Jira ticket: `# TODO(IAM-1234): handle the case where source is in maintenance`.

## Destructive operations

Anything that deletes, revokes, or modifies access:

1. Supports `-WhatIf` via `[CmdletBinding(SupportsShouldProcess)]`.
2. Wraps the destructive call in `if ($PSCmdlet.ShouldProcess(...))`.
3. Defaults to dry-run mode if the script has no `-WhatIf` parameter (have a `-Apply` switch instead — explicit is safer than default-on).
4. Writes the planned changes to a file before executing, so there's a record.

```powershell
foreach ($id in $identitiesToDisable) {
    if ($PSCmdlet.ShouldProcess($id, 'Disable identity')) {
        try {
            Disable-Identity -Id $id
            Write-Information "Disabled $id"
        }
        catch {
            Write-Warning "Failed to disable ${id}: $($_.Exception.Message)"
        }
    }
}
```

## Testing

- Run new and refactored scripts against the sandbox tenant first. Always.
- For destructive operations, run with `-WhatIf` and review the output before running for real.
- For optimization work, run old and new versions side by side and diff the outputs:
  ```powershell
  $old = .\old-script.ps1 | Sort-Object Id
  $new = .\new-script.ps1 | Sort-Object Id
  Compare-Object $old $new -Property Id, Name, Status
  ```

## What to leave out

- No `#region` / `#endregion` blocks. They add noise and the editor handles folding fine.
- No author signatures inside function bodies. Use git blame.
- No commented-out code. Delete it; git remembers.
- No `Write-Host -ForegroundColor` rainbow output. It looks unprofessional and breaks redirection.
