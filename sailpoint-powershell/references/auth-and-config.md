# Authentication and Configuration

ISC uses OAuth2 client credentials backed by a Personal Access Token (PAT). The SDK handles the token exchange and refresh for you. Direct REST callers must do it themselves.

## Get a PAT

1. In ISC, go to Admin → Global → Security Settings → API Management → Personal Access Tokens.
2. Create a new PAT with the scopes your scripts need (start with minimum, expand as needed — least privilege).
3. Capture `Client ID` and `Client Secret` immediately. The secret is shown once.
4. Store them as described below — never in source control.

The base URL follows the pattern `https://[tenant].api.identitynow.com`. The tenant name is the subdomain of your ISC UI URL.

## Three storage options, ranked

### 1. Environment variables (preferred for CI/CD and personal dev)

```powershell
$env:SAIL_BASE_URL      = 'https://[tenant].api.identitynow.com'
$env:SAIL_CLIENT_ID     = '<client-id>'
$env:SAIL_CLIENT_SECRET = '<client-secret>'
```

To persist across PowerShell sessions on Windows:

```powershell
[System.Environment]::SetEnvironmentVariable('SAIL_BASE_URL',      'https://[tenant].api.identitynow.com', 'User')
[System.Environment]::SetEnvironmentVariable('SAIL_CLIENT_ID',     '<client-id>',     'User')
[System.Environment]::SetEnvironmentVariable('SAIL_CLIENT_SECRET', '<client-secret>', 'User')
```

The SDK picks these up automatically. Nothing else to wire.

### 2. `config.json` file (when env vars are not practical)

Create `config.json` next to your script:

```json
{
  "ClientId":     "<client-id>",
  "ClientSecret": "<client-secret>",
  "BaseURL":      "https://[tenant].api.identitynow.com"
}
```

Add it to `.gitignore` immediately. The SDK will load it from the working directory.

### 3. Secret store (preferred for production / shared service accounts)

Use Microsoft.PowerShell.SecretManagement with a vault (Azure Key Vault, CredentialManager, or KeePass). Pattern:

```powershell
$clientId     = Get-Secret -Name 'Sailpoint-ClientId'     -AsPlainText
$clientSecret = Get-Secret -Name 'Sailpoint-ClientSecret' -AsPlainText
$env:SAIL_BASE_URL      = Get-Secret -Name 'Sailpoint-BaseUrl' -AsPlainText
$env:SAIL_CLIENT_ID     = $clientId
$env:SAIL_CLIENT_SECRET = $clientSecret
```

Set the env vars at the start of the script so the SDK can find them, then clear them at the end if running in a shared session.

## Verifying auth works before running anything destructive

Every script should make a cheap, read-only call as the first thing after loading credentials. This catches bad credentials before any destructive work runs:

```powershell
try {
    $null = Get-PublicIdentitiesConfig -ErrorAction Stop
    Write-Verbose 'Sailpoint authentication confirmed.'
} catch {
    throw "Sailpoint authentication failed. Check SAIL_CLIENT_ID / SAIL_CLIENT_SECRET / SAIL_BASE_URL. Underlying error: $($_.Exception.Message)"
}
```

## If you must call REST directly

When using `Invoke-RestMethod`, get a token first:

```powershell
function Get-IscAccessToken {
    [CmdletBinding()]
    param()

    $baseUrl      = $env:SAIL_BASE_URL
    $clientId     = $env:SAIL_CLIENT_ID
    $clientSecret = $env:SAIL_CLIENT_SECRET

    foreach ($var in 'SAIL_BASE_URL','SAIL_CLIENT_ID','SAIL_CLIENT_SECRET') {
        if (-not (Get-Item "env:$var" -ErrorAction SilentlyContinue).Value) {
            throw "Environment variable $var is not set."
        }
    }

    $tokenUrl = "$baseUrl/oauth/token"
    $body = @{
        grant_type    = 'client_credentials'
        client_id     = $clientId
        client_secret = $clientSecret
    }

    $response = Invoke-RestMethod -Uri $tokenUrl -Method Post -Body $body -ContentType 'application/x-www-form-urlencoded'
    return $response.access_token
}
```

Tokens are typically valid for ~12 hours. For long-running scripts, refresh proactively at ~10 hours rather than waiting for a 401. The SDK handles this internally — another reason to prefer it.

## What never to do

- Commit `config.json` or any file containing a client secret.
- Pass the secret as a script parameter (it ends up in command history, transcript logs, and process listings).
- Echo the secret to console for debugging — use `Write-Verbose "Token length: $($token.Length)"` instead.
- Share a single PAT across the team. Each automation context (CI pipeline, scheduled job, individual dev) gets its own PAT so revocation is surgical.
