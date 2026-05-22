# Source: https://github.com/sailpoint-oss/powershell-sdk/blob/main/example/sdk.ps1
# Demonstrates: Basic Get-Accounts call with limit, offset, count, and filters

$Limit = 250
$Offset = 0
$Count = $true
$Filters = 'sourceId eq "f4e73766efdf4dc6acdeed179606d694"'

try {
    Get-Accounts -Limit $Limit -Offset $Offset -Count $Count -Filters $Filters
} catch {
    Write-Host ("Exception occurred when calling Get-Accounts: {0}" -f $_.ErrorDetails)
    Write-Host ("Response headers: {0}" -f $_.Exception.Response.Headers)
}
