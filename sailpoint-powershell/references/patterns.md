# Common Patterns

The four patterns that show up in nearly every SailPoint PowerShell script: pagination, error handling, retries, and search. Get these right and the rest of the script is straightforward.

## Pagination

ISC list endpoints return a maximum of **250 records per request**. Any script that could plausibly hit more than 250 records — and most do — must paginate. The SDK provides `Invoke-Paginate` for this.

### SDK pagination (preferred)

```powershell
$parameters = @{
    Filters = 'name co "Andrew"'
}

try {
    $accounts = Invoke-Paginate `
        -Function      'Get-Accounts' `
        -Increment     250 `
        -Limit         10000 `
        -InitialOffset 0 `
        -Parameters    $parameters
}
catch {
    Write-Error "Get-Accounts failed: $($_.Exception.Message)"
    throw
}
```

Parameters:
- `-Function` — name of the SDK list cmdlet (`Get-Accounts`, `Get-Identities`, `Get-Sources`, etc.). Must be a list endpoint.
- `-Increment` — page size, max 250. Don't drop below 250 unless there's a reason; smaller pages mean more requests and more rate-limit risk.
- `-Limit` — total ceiling. Set this to a realistic upper bound; an unbounded loop on a misbehaving filter can pull millions of records.
- `-InitialOffset` — where to start, almost always 0.
- `-Parameters` — hashtable of additional query parameters (`Filters`, `Sorters`, etc.).

### REST pagination (when not using the SDK)

Pattern: loop while the API returns a full page. Stop when a page comes back smaller than `limit`.

```powershell
function Get-IscAccountsRest {
    [CmdletBinding()]
    param(
        [string] $Filter,
        [int]    $PageSize = 250,
        [int]    $MaxRecords = 10000
    )

    $token   = Get-IscAccessToken
    $baseUrl = $env:SAIL_BASE_URL
    $offset  = 0
    $results = New-Object System.Collections.Generic.List[object]

    do {
        $query  = "limit=$PageSize&offset=$offset&count=true"
        if ($Filter) { $query += "&filters=$([uri]::EscapeDataString($Filter))" }
        $uri    = "$baseUrl/v3/accounts?$query"

        $page = Invoke-RestMethod -Uri $uri -Method Get -Headers @{ Authorization = "Bearer $token" }
        if ($null -eq $page -or $page.Count -eq 0) { break }

        $results.AddRange($page)
        $offset += $PageSize

        if ($results.Count -ge $MaxRecords) {
            Write-Warning "Reached MaxRecords limit of $MaxRecords. Result set may be truncated."
            break
        }
    } while ($page.Count -eq $PageSize)

    return $results
}
```

Two things to never get wrong:
- Stop when the page is smaller than `$PageSize`, not when it's empty. The last page is usually partial.
- Always set a `MaxRecords` ceiling. An unbounded loop on a runaway filter will eat your rate limit and not come back for hours.

## Error handling

The minimum bar for any API-calling function:

```powershell
try {
    $result = Get-Accounts -Limit 250 -ErrorAction Stop
}
catch {
    $statusCode = $_.Exception.Response.StatusCode.value__
    $errorBody  = $null
    try { $errorBody = $_.ErrorDetails.Message | ConvertFrom-Json } catch { }

    Write-Error "Get-Accounts failed (HTTP $statusCode): $($errorBody.detailCode ?? $_.Exception.Message)"
    Write-Verbose ($_.Exception.Response.Headers | ConvertTo-Json -Depth 4)
    throw
}
```

Key points:
- `-ErrorAction Stop` on the cmdlet forces non-terminating errors into the catch block. Without it, `try/catch` does nothing.
- Capture the HTTP status code separately. `401`, `403`, `429`, and `5xx` need different responses.
- Capture the response body — ISC returns structured error details (`detailCode`, `messages`, `causes`) that are far more useful than `$_.Exception.Message` alone.
- Log the response headers in verbose mode. `X-RateLimit-Remaining` and `Retry-After` are diagnostic gold.

## Retries with exponential backoff

Transient failures (429, 502, 503, 504) should retry. Permanent failures (400, 401, 403, 404) should not. Hard-coded sleeps are not retries — backoff matters.

```powershell
function Invoke-IscWithRetry {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [scriptblock] $ScriptBlock,

        [int] $MaxAttempts = 5,
        [int] $InitialDelaySeconds = 2
    )

    $attempt = 0
    $delay   = $InitialDelaySeconds

    while ($true) {
        $attempt++
        try {
            return & $ScriptBlock
        }
        catch {
            $statusCode = $null
            try { $statusCode = $_.Exception.Response.StatusCode.value__ } catch { }

            $isTransient = $statusCode -in 429, 502, 503, 504

            if (-not $isTransient -or $attempt -ge $MaxAttempts) {
                throw
            }

            # Honor Retry-After if the server provided it (common for 429)
            $retryAfter = $null
            try { $retryAfter = [int]$_.Exception.Response.Headers['Retry-After'] } catch { }
            $sleep = if ($retryAfter) { $retryAfter } else { $delay }

            Write-Warning "Attempt $attempt of $MaxAttempts failed (HTTP $statusCode). Retrying in $sleep s."
            Start-Sleep -Seconds $sleep

            $delay = [Math]::Min($delay * 2, 60)  # cap at 60s
        }
    }
}

# Usage:
$identities = Invoke-IscWithRetry { Get-Identities -Limit 250 }
```

Why exponential and not constant: a rate-limited tenant returns 429s in bursts. Constant retries pile on. Doubling each attempt gives the tenant time to recover. The 60s cap prevents the delay growing absurdly long.

Why honor `Retry-After`: ISC's gateway tells you exactly how long to wait. Ignoring this header is the fastest way to extend the rate-limit window.

## Search (Elasticsearch DSL)

For complex queries — multi-field filters, fuzzy matching, aggregations — ISC's `/search` endpoint is far more powerful than list endpoints with `filters`. It accepts Elasticsearch query DSL.

```powershell
$searchBody = @{
    indices = @('identities')
    query = @{
        query = 'attributes.department:"Engineering" AND attributes.location:"Austin"'
    }
    sort = @('name')
} | ConvertTo-Json -Depth 10

$identities = Search-Post -Search $searchBody
```

Use `/search` when:
- Filtering across multiple object types (identities + accounts).
- Needing free-text or fuzzy matching.
- Needing aggregations (counts by department, etc.).

Stick with list endpoints (`Get-Identities`, `Get-Accounts`) when:
- Filtering on a single indexed field with exact match.
- Working with small, well-known result sets.

Search results paginate the same way — use `Invoke-Paginate` against `Search-Post`.

## Batch operations

Several ISC endpoints accept arrays so you don't have to call once per item:

- Identity refresh: bulk endpoint accepts a list of identity IDs.
- Entitlement updates: bulk endpoint accepts a list of changes.
- Account updates: PATCH supports JSON Patch arrays.

When optimizing a script that loops calling a single-item endpoint N times, check whether a bulk endpoint exists. The performance difference is usually 10-50x because each call has a fixed network and auth overhead.

## Filter syntax reference

ISC uses a SCIM-like filter syntax for list endpoints:

| Operator | Meaning             | Example                               |
| -------- | ------------------- | ------------------------------------- |
| `eq`     | equals              | `name eq "Andrew"`                    |
| `ne`     | not equals          | `status ne "DISABLED"`                |
| `co`     | contains            | `name co "smith"`                     |
| `sw`     | starts with         | `email sw "admin"`                    |
| `ew`     | ends with           | `email ew "@example.com"`             |
| `gt/ge`  | greater than / eq   | `created ge "2025-01-01T00:00:00Z"`   |
| `lt/le`  | less than / eq      | `modified lt "2025-06-01T00:00:00Z"`  |
| `and`    | logical and         | `name co "smith" and status eq "ACTIVE"` |
| `or`     | logical or          | `status eq "A" or status eq "P"`      |
| `in`     | value in list       | `id in ("a","b","c")`                 |

Always URL-encode the filter when building REST URLs directly. The SDK handles this for you.
