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
    [parameter(Mandatory=$true)]$objectId
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

function Get-GraphCall {
    param(
        [Parameter(Mandatory)]
        $apiUri
    )
    return Invoke-RestMethod -Uri https://graph.microsoft.com/beta/$apiUri -Headers $authToken -Method GET
}

#################################################################################################
########################################### Start ###############################################
#################################################################################################

$global:authToken = Get-AuthHeader -tenantId $tenantId -clientId $clientId -clientSecret $clientSecret

Write-Host "Getting $type with the Object id: $objectId"

try{
    switch ($type) {
        config-profile {
            $object = Get-GraphCall -apiUri "/deviceManagement/deviceConfigurations/$objectId"            
        }compliance-policy{
            $object = Get-GraphCall -apiUri "/deviceManagement/deviceCompliancePolicies/$objectId"
        }script{
            $object = Get-GraphCall -apiUri "/deviceManagement/deviceManagementScripts/$objectId"
        }remediation-script{
            $object = Get-GraphCall -apiUri "/deviceManagement/deviceHealthScripts/$objectId"
        }filter{
            $object = Get-GraphCall -apiUri "/deviceManagement/assignmentFilters/$objectId"
        }
        Default {}
    }
}catch{
    $ex = $_.Exception
    Write-Error "Something went wrong by getting the object from Intune: $ex"
    return $false
}

if($object.id){
    $object | ConvertTo-Json -Depth 5 | Out-File -FilePath intuneObject.json
    dir
    return $true
}
return $false

