# Source: https://github.com/sailpoint-oss/powershell-sdk/blob/main/example/patchEntitlement.ps1
# Demonstrates: JSON Patch operation against Beta API entitlement

$ENT = @(
    @{
        op = "replace"
        path = "/privileged"
        value = $false
    }
)

try {
    Update-BetaEntitlement -Id "2c9180848366cdc701837b78f5ce58be" -JsonPatchOperation $ENT
} catch {
    Write-Host ("Exception occurred when calling Update-BetaEntitlement: {0}" -f $_.ErrorDetails)
    Write-Host ("Response headers: {0}" -f $_.Exception.Response.Headers)
}
