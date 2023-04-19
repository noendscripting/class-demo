[CmdletBinding()]
param()
. "$($PSScriptRoot)\roleClass.ps1"
Function get-resourceData {
    param(
        [string]$resourceId
    )
    #fixing resourceID mismatch for Azure Fileshares between AzureRoles API and Azure Files API
    If ($resourceId -match "(?=.*?(Microsoft.Storage\/storageAccounts))(?=.*?(fileServices))") {
        $resourceArray = $resourceId.Split("/")
        $resourceArray[11] = 'shares'
        $resourceId = $resourceArray -join "/"
    } 

    return Get-AzResource -ResourceId $resourceId

}
function Get-RoleType {
    param (
        $name
    )

    switch ((Get-AzRoleDefinition -Name $name).IsCustom) {
        $true {
            return "CustomRole"
        }
        $false {
            return "BuiltInRole"
        }
        
    }
    
}

function Get-ServicePrincipalType {
    param(
        $type,
        $objectId
    )

    if ($type -ne 'ServicePrincipal') {
        return $type
    }
    return ((Invoke-AzRestMethod -uri "https://graph.microsoft.com/v1.0/servicePrincipals/$($objectId)").Content | ConvertFrom-Json -Depth 99).servicePrincipalType

}

$Output = @()
Get-AzRoleAssignment -PipelineVariable Role | ForEach-Object {

    Switch (($role.Scope.Split('/')).Count) {
        0 {
            $script:scopeDisplayname = "NOT FOUND"
            $script:scopeType = "NOT FOUND"
        }
        1 {
            $script:scopeDisplayname = "NOT FOUND"
            $script:scopeType = "NOT FOUND"
        }
        2 {
            $script:scopeDisplayname = "Root ManagementGroup"
            $script:scopeType = "ManagementGroup"
        }
        3 {
            $script:scopeDisplayname = (Get-AzSubscription -SubscriptionId $role.Scope.Split('/')[2]).Name
            $script:scopeType = "Subscription"
        }
        5 {
            if ($role.Scope.split('/')[2] -match '.Management') {
                $script:scopeDisplayname = (Get-AzManagementGroup -GroupName $role.Scope.Split('/')[-1]).DisplayName
                $script:scopeType = "ManagementGroup"
            }
            else {
                $script:scopeDisplayname = (Get-AzResourceGroup -Id $role.Scope).Name
                $script:scopeType = "ResourceGroup"
            }

        }

        Default {
            if (!([string]::IsNullOrEmpty($role.Scope))) {
                $resourceData = get-resourceData -resourceId $role.Scope
                $script:scopeDisplayname = $resourceData.Name
                $script:scopeType = $resourceData.ResourceType
            }
        }
        else {
            $script:scopeDisplayname = "NOT FOUND"
            $script:scopeType = "NOT FOUND"
            
        }
    }

    $AzureRoleData = New-Object AzureRole
    $AzureRoleData.principalType = Get-ServicePrincipalType -objectId $role.ObjectId -type $role.ObjectType
    $AzureRoleData.principalDisplayName = $role.DisplayName
    $AzureRoleData.principalObjectId = $role.ObjectId
    $AzureRoleData.roleDisplayName = $role.RoleDefinitionName
    $AzureRoleData.scopeDisplayname = $script:scopeDisplayname
    $AzureRoleData.scopeId = $role.Scope
    $AzureRoleData.scopeType = $script:scopeType
    $AzureRoleData.roleType = Get-RoleType -name $role.RoleDefinitionName
 
    $Output += $AzureRoleData

    Clear-Variable role, scopeDisplayname, scopeType

}

$Output
#$output | export-csv -Path .\TestDataFiles\roles.csv