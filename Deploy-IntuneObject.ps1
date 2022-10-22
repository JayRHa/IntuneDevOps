<#
Version: 1.0
Author: Jannik Reinhard (jannikreinhard.com)
Script: Get-IntuneObjectId
Description:
Check If an object exist in intune
Release notes:
Version 1.0: Init
#> 

param (
    [parameter(Mandatory=$true)]$tenantId,
    [parameter(Mandatory=$true)]$clientId,
    [parameter(Mandatory=$true)]$clientSecret,
    [parameter(Mandatory=$true)]$type,
    [parameter(Mandatory=$true)]$path
)


function Get-AuthHeader{
    param (
        [parameter(Mandatory=$true)]$tenantId,
        [parameter(Mandatory=$true)]$clientId,
        [parameter(Mandatory=$true)]$clientSecret
       )
    
    $authBody=@{
        client_id=$clientId
        client_secret=$clientSecret
        scope="https://graph.microsoft.com/.default"
        grant_type="client_credentials"
    }

    $uri="https://login.microsoftonline.com/$tenantId/oauth2/v2.0/token"
    $accessToken=Invoke-WebRequest -Uri $uri -ContentType "application/x-www-form-urlencoded" -Body $authBody -Method Post -ErrorAction Stop -UseBasicParsing
    $accessToken=$accessToken.content | ConvertFrom-Json

    $authHeader = @{
        'Content-Type'='application/json'
        'Authorization'="Bearer " + $accessToken.access_token
        'ExpiresOn'=$accessToken.expires_in
    }
    
    return $authHeader
}

function Run-GraphCall {
    param(
        [Parameter(Mandatory)] $apiUri
        ,[Parameter(Mandatory)] $body
    )
    return Invoke-RestMethod -Uri https://graph.microsoft.com/beta/$apiUri -ContentType "application/json" -Headers $authToken -Method POST -Body $body
}

function Add-ScheduledActionsForRule{
    param(
        [Parameter(Mandatory)] $object
    )
    $scheduledActionsForRule = '"scheduledActionsForRule":  [
        {
            "ruleName": null,
            "scheduledActionConfigurations":  [
                {
                    "actionType":   "block"
                    }
                ]
            }
        ]'  
    $object = $object | ConvertTo-Json -Depth 5
    return $object.trimend("}") + "," + "`r`n" + $scheduledActionsForRule + "`r`n" + "}"
}

#################################################################################################
########################################### Start ###############################################
#################################################################################################

$object = Get-Content -Path $path | ConvertFrom-Json
$object = $object | Select-Object -Property * -ExcludeProperty 'id','version','topicIdentifier','certificate','createdDateTime','lastModifiedDateTime','isDefault','deployedAppCount','isAssigned','@odata.context','scheduledActionConfigurations@odata.context','scheduledActionsForRule@odata.context','sourceId','supportsScopeTags','companyCodes','isGlobalScript','highestAvailableVersion','token','lastSyncDateTime','isReadOnly','secretReferenceValueId','isEncrypted', 'payloads'
Write-Host "Getting $type with the Name: $($object.displayName)"

$global:authToken = Get-AuthHeader -tenantId $tenantId -clientId $clientId -clientSecret $clientSecret

try{
    switch ($type) {
        config-profile {
            Run-GraphCall -apiUri '/deviceManagement/deviceConfigurations' -body ($object | ConvertTo-Json -Depth 5)            
        }compliance-policy{
            Run-GraphCall -apiUri '/deviceManagement/deviceCompliancePolicies' -body (Add-ScheduledActionsForRule -object $object)
        }script{
            Run-GraphCall -apiUri '/deviceManagement/deviceManagementScripts' -body ($object | ConvertTo-Json -Depth 5)
        }remediation-script{
            Run-GraphCall -apiUri '/deviceManagement/deviceHealthScripts' -body ($object | ConvertTo-Json -Depth 5)
        }filter{
            Run-GraphCall -apiUri '/deviceManagement/assignmentFilters' -body ($object | ConvertTo-Json -Depth 5)
        }
        Default {}
    }
}catch{
    $ex = $_.Exception
    Write-Error "Something went wrong by getting the object from Intune: $ex"
    return $false
}

return $true

