# Examples

These examples are sourced from the [official SailPoint PowerShell SDK](https://github.com/sailpoint-oss/powershell-sdk/tree/main/example). They demonstrate the canonical SDK calling patterns — correct cmdlet usage, parameter shapes, and pagination mechanics.

Use these as the authoritative reference for **how to call the SDK**. For production script structure (parameter blocks, error handling, retries, `-WhatIf` support), combine these patterns with the conventions in `templates/new-script.ps1` and `references/coding-standards.md`.

## Files

| File | Demonstrates |
|------|-------------|
| `paginate-search.ps1` | Paginated search using `Invoke-PaginateSearch` with Elasticsearch DSL |
| `paginate-accounts.ps1` | Paginated list using `Invoke-Paginate` with server-side filters |
| `patch-entitlement.ps1` | JSON Patch update using the Beta API |
| `get-accounts.ps1` | Basic list call with limit, offset, count, and filters |
| `search.ps1` | Search endpoint with proxy configuration |
| `create-transform.ps1` | Creating a lookup transform from JSON |

## Source

All examples are from [`sailpoint-oss/powershell-sdk/example/`](https://github.com/sailpoint-oss/powershell-sdk/tree/main/example) and are reproduced under the SDK's license. They represent the SDK team's intended usage patterns.
