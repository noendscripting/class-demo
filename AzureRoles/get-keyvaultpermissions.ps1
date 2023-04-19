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




$report = @()
$keyVaultList = Search-AzGraph -Query 'resources| where type == "microsoft.keyvault/vaults"' 


$keyVaultList | ForEach-Object {


$keyVaultname = $PSItem.name
$keyVaultSubscriptionId = $PSItem.subscriptionId
$keyVaultResourceGroupName = $PSItem.resourceGroup
    
    (Get-AzKeyVault -SubscriptionId $keyVaultSubscriptionId -VaultName $keyVaultName -ResourceGroupName $keyVaultResourceGroupName ).AccessPolicies | ForEach-Object {

        $policyObject = new-object psobject  -Property @{
            KeyVaultName                 = $keyVaultName
            ObjectId                     = $_.ObjectId
            DisplayName                  = $_.DisplayName
            ApplicationId                = $_.ApplicationId
            ApplicationIdDisplayName     = $_.ApplicationIdDisplayName
            PermissionsToCertificates    = $_.PermissionsToCertificates -join " "   
            PermissionsToCertificatesStr = $_.PermissionsToCertificatesStr -join " "
            PermissionsToKeys            = $_.PermissionsToKeys -join " "          
            PermissionsToKeysStr         = $_.PermissionsToKeysStr -join " "
            PermissionsToSecrets         = $_.PermissionsToSecrets -join " "
            PermissionsToSecretsStr      = $_.PermissionsToSecretsStr -join " "
            PermissionsToStorage         = $_.PermissionsToStorage -join " "
            PermissionsToStorageStr      = $_.PermissionsToStorageStr -join " "
            TenantId                     = $_.TenantId
            TenantName                   = $_.TenantName
        }
         
        $report += $policyObject
       
    }

    

}

$report

#optional export into csv
$report | Export-Csv -NoTypeInformation -Path .\TestDataFiles\keyvaultPolicy.csv
