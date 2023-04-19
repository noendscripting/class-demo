<#
.DESCRIPTION
  Script can be used with Azure Automation to create resource group for restore , run azure restore to recover disk and then create a VM in a separate VNET and set default Azure DNS.
  Post restore steps will remove it from Domain, rename VM and set DNS back to inherit from VNET
  DISCLAIMER
    THIS SAMPLE CODE AND ANY RELATED INFORMATION ARE PROVIDED "AS IS" WITHOUT WARRANTY OF ANY KIND, EITHER EXPRESSED OR IMPLIED,
    INCLUDING BUT NOT LIMITED TO THE IMPLIED WARRANTIES OF MERCHANTABILITY AND/OR FITNESS FOR A PARTICULAR PURPOSE.  
    We grant You a nonexclusive, royalty-free right to use and modify the Sample Code and to reproduce and distribute the object
    code form of the Sample Code, provided that You agree: (i) to not use Our name, logo, or trademarks to market Your software
    product in which the Sample Code is embedded; (ii) to include a valid copyright notice on Your software product in which the
    Sample Code is embedded; and (iii) to indemnify, hold harmless, and defend Us and Our suppliers from and against any claims
    or lawsuits, including attorneys’ fees, that arise or result from the use or distribution of the Sample Code.
    Please note: None of the conditions outlined in the disclaimer above will supersede the terms and conditions contained within
    the Premier Customer Services Description.
#>

[CmdletBinding()]
param()

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


Class AzureRole
{
    [string]$roleType
    [string]$scopeType
    [string]$scopeId
    [string]$principalType
    [string]$scopeDisplayname
    [string]$principalDisplayName
    [string]$principalObjectId
    [string]$roleDisplayName
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

    $AzureRoleData = [AzureRole]::new()
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