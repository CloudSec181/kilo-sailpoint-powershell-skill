# SDK vs. Direct REST: When to Use Which

The team uses both PSSailpoint SDK and direct `Invoke-RestMethod`. Each has a place. The wrong choice usually shows up as either (a) reinventing what the SDK already does, or (b) fighting the SDK when you need something it doesn't expose.

## Decision tree

```
Is there an SDK cmdlet that does what you need?
├── Yes → Use the SDK.
│   └── Exception: you need custom headers, non-standard body shape,
│       or fine control over retries → fall back to REST.
└── No → Use REST, but wrap it in a function named like an SDK cmdlet
        so the rest of the script doesn't know the difference.
```

## When the SDK wins

Use the SDK for these. Don't roll your own.

- **Authentication and token refresh** — the SDK handles OAuth2 client credentials, caches the bearer token, and refreshes it on expiry. Reimplementing this is fiddly and easy to get wrong.
- **Pagination** — `Invoke-Paginate` is correct by construction. Manual loops are the #1 source of paginated-list bugs.
- **Typed responses** — SDK cmdlets return typed objects with full property metadata. REST returns raw JSON that you then have to remember the shape of.
- **Standard CRUD on covered objects** — Identities, Accounts, Sources, Entitlements, Access Profiles, Roles, Certifications, Workflows, Transforms. All wrapped.
- **Search** — `Search-Post` against the Elasticsearch DSL endpoint.

## When direct REST wins

Drop to REST when the SDK genuinely can't cover the case:

- **A new endpoint** that shipped in Beta and isn't in the SDK yet.
- **An admin or internal endpoint** that the SDK never wrapped.
- **Custom headers** required (rare, but happens for some integrations).
- **Non-standard body shapes** — JSON Patch arrays the SDK serializes incorrectly, multipart uploads, etc.
- **Streaming or large file responses** where you need control over the HTTP client.

## How to write a REST helper that feels native

When you do drop to REST, make it look like the rest of the codebase. Three rules.

**Rule 1: name it like an SDK cmdlet.**

```powershell
function Get-IscFooBar { ... }      # not Invoke-FooBar or Call-FooBar
function Set-IscFooBar { ... }
function Remove-IscFooBar { ... }
function New-IscFooBar { ... }
```

This way the call site is indistinguishable from a real SDK call. When the SDK catches up, swapping in the native cmdlet is a one-line change.

**Rule 2: reuse SDK auth.**

```powershell
function Get-IscFooBar {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string] $FooId
    )

    $token   = Get-IscAccessToken    # from auth-and-config.md
    $baseUrl = $env:SAIL_BASE_URL
    $uri     = "$baseUrl/v3/foo-bars/$FooId"

    Invoke-RestMethod `
        -Uri     $uri `
        -Method  Get `
        -Headers @{ Authorization = "Bearer $token" } `
        -ErrorAction Stop
}
```

Don't reimplement the OAuth dance. Either use the SDK to get a token, or use the shared `Get-IscAccessToken` helper.

**Rule 3: handle errors the same way SDK cmdlets do.**

Use `-ErrorAction Stop` so non-terminating errors throw. Capture status code and response body in the catch. Wrap calls in `Invoke-IscWithRetry` for unattended scripts. See `references/patterns.md`.

## Translation table: SDK ↔ REST

Common operations side by side, so you can map between them quickly.

### List identities

```powershell
# SDK
$identities = Invoke-Paginate `
    -Function 'Get-Identities' `
    -Increment 250 `
    -Limit 5000 `
    -Parameters @{ Filters = 'attributes.department eq "Eng"' }

# REST
$uri = "$($env:SAIL_BASE_URL)/v3/identities?filters=$([uri]::EscapeDataString('attributes.department eq "Eng"'))&limit=250&offset=0"
$identities = Invoke-RestMethod -Uri $uri -Headers @{ Authorization = "Bearer $token" } -ErrorAction Stop
# (then loop for pagination — see patterns.md)
```

### Get a single account

```powershell
# SDK
$account = Get-Account -Id $accountId

# REST
$uri = "$($env:SAIL_BASE_URL)/v3/accounts/$accountId"
$account = Invoke-RestMethod -Uri $uri -Headers @{ Authorization = "Bearer $token" } -ErrorAction Stop
```

### Update an account (JSON Patch)

```powershell
# SDK
$patch = @(
    @{ op = 'replace'; path = '/attributes/department'; value = 'Engineering' }
)
$updated = Update-Account -Id $accountId -JsonPatchOperation $patch

# REST
$uri = "$($env:SAIL_BASE_URL)/v3/accounts/$accountId"
$body = ConvertTo-Json @(
    @{ op = 'replace'; path = '/attributes/department'; value = 'Engineering' }
) -Depth 10
$updated = Invoke-RestMethod `
    -Uri $uri -Method Patch -Body $body `
    -Headers @{ Authorization = "Bearer $token" } `
    -ContentType 'application/json-patch+json' `
    -ErrorAction Stop
```

Note the `application/json-patch+json` content type — this is a common REST mistake. PATCH against ISC uses JSON Patch, not merge patch.

### Search

```powershell
# SDK
$body = @{
    indices = @('identities')
    query   = @{ query = 'attributes.location:"Austin"' }
} | ConvertTo-Json -Depth 10
$results = Search-Post -Search $body

# REST
$uri = "$($env:SAIL_BASE_URL)/v3/search"
$results = Invoke-RestMethod `
    -Uri $uri -Method Post -Body $body `
    -Headers @{ Authorization = "Bearer $token" } `
    -ContentType 'application/json' `
    -ErrorAction Stop
```

## Anti-patterns to flag

- **Hand-rolled OAuth flow** when the SDK is loaded. Just import `PSSailpoint` and let it do the work.
- **Mixing SDK and REST in the same logical operation** — e.g., listing accounts with SDK but updating each one with REST. Pick one for the operation; consistency is worth more than micro-optimization.
- **REST with hardcoded API version paths** when the SDK module exists for that version (`PSSailpoint.V2024` etc.).
- **REST helpers that don't follow the `Verb-IscNoun` naming convention** — they become impossible to find when refactoring.
