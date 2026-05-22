# Source: https://github.com/sailpoint-oss/powershell-sdk/blob/main/example/paginateAccounts.ps1
# Demonstrates: Invoke-Paginate with Get-Accounts and server-side filter

$Parameters = @{
    "Filters" = 'name co "Andrew"'
}

try {
    Invoke-Paginate -Function "Get-Accounts" -Increment 250 -Limit 1000 -InitialOffset 0 -Parameters $Parameters
} catch {
    Write-Host ("Exception occurred when calling Invoke-Paginate: {0}" -f $_.ErrorDetails)
    Write-Host ("Response headers: {0}" -f $_.Exception.Response.Headers)
}
