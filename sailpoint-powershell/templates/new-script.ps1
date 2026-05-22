<#
.SYNOPSIS
    <Brief one-line description of what this script does.>

.DESCRIPTION
    <Longer description: which ISC objects are read or modified, side effects,
    preconditions, intended runtime environment.>

.PARAMETER TenantUrl
    The ISC tenant URL. Defaults to $env:SAIL_BASE_URL.

.PARAMETER OutputPath
    Where to write the result file. Defaults to the current directory.

.EXAMPLE
    .\script-name.ps1 -Verbose

.EXAMPLE
    .\script-name.ps1 -WhatIf

.NOTES
    Author:   <name>
    Version:  1.0
    Requires: PSSailpoint, PSSailpoint.V3
#>

#Requires -Version 7.0
#Requires -Modules PSSailpoint

[CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'Medium')]
param(
    [Parameter()]
    [ValidateNotNullOrEmpty()]
    [string] $TenantUrl = $env:SAIL_BASE_URL,

    [Parameter()]
    [ValidateNotNullOrEmpty()]
    [string] $OutputPath = (Join-Path $PWD 'output.csv')
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

function Assert-IscAuth {
    <#
    .SYNOPSIS Verify auth before doing anything destructive.
    #>
    [CmdletBinding()]
    param()

    foreach ($var in 'SAIL_BASE_URL','SAIL_CLIENT_ID','SAIL_CLIENT_SECRET') {
        if (-not (Get-Item "env:$var" -ErrorAction SilentlyContinue).Value) {
            throw "Required environment variable '$var' is not set. See references/auth-and-config.md."
        }
    }

    try {
        $null = Get-PublicIdentitiesConfig -ErrorAction Stop
        Write-Verbose 'Sailpoint authentication confirmed.'
    }
    catch {
        throw "Sailpoint authentication check failed: $($_.Exception.Message)"
    }
}

function Invoke-IscWithRetry {
    <#
    .SYNOPSIS Retry transient API failures (429, 5xx) with exponential backoff.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] [scriptblock] $ScriptBlock,
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
            if (-not $isTransient -or $attempt -ge $MaxAttempts) { throw }

            $retryAfter = $null
            try { $retryAfter = [int]$_.Exception.Response.Headers['Retry-After'] } catch { }
            $sleep = if ($retryAfter) { $retryAfter } else { $delay }

            Write-Warning "Attempt $attempt of $MaxAttempts failed (HTTP $statusCode). Retrying in $sleep s."
            Start-Sleep -Seconds $sleep
            $delay = [Math]::Min($delay * 2, 60)
        }
    }
}

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

try {
    Assert-IscAuth
    $sw = [System.Diagnostics.Stopwatch]::StartNew()

    # Example: paginated list with retry-aware wrapper
    $accounts = Invoke-IscWithRetry {
        Invoke-Paginate `
            -Function      'Get-Accounts' `
            -Increment     250 `
            -Limit         10000 `
            -InitialOffset 0 `
            -Parameters    @{ Filters = 'disabled eq false' }
    }

    Write-Verbose "Retrieved $($accounts.Count) accounts in $($sw.Elapsed.TotalSeconds)s"

    # Example: process and shape output
    $report = $accounts | ForEach-Object {
        [pscustomobject]@{
            Id         = $_.id
            Name       = $_.name
            SourceName = $_.sourceName
            Disabled   = $_.disabled
            Created    = $_.created
        }
    }

    # Example: gated destructive step (replace with real work)
    if ($PSCmdlet.ShouldProcess($OutputPath, 'Write report')) {
        $report | Export-Csv -Path $OutputPath -NoTypeInformation -Encoding UTF8
        Write-Information "Wrote $($report.Count) rows to $OutputPath" -InformationAction Continue
    }
}
catch {
    Write-Error "Script failed: $($_.Exception.Message)"
    Write-Verbose $_.ScriptStackTrace
    throw
}
finally {
    if ($sw) { $sw.Stop() }
}
