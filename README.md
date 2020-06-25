# class-demo

## Repository for demo files and instructions

### Preparing environment

- Clone github repository Class Demo</li> 
- Create a resource group in your azure subscription and note the name and location settings
- Deploy template 'class-vnet-demo.json' using [Azure CLI](https://docs.microsoft.com/en-us/cli/azure/deployment/group?view=azure-cli-latest#az-deployment-group-create) or [Powershell](https://docs.microsoft.com/en-us/powershell/module/az.resources/new-azresourcegroupdeployment?view=azps-4.3.0).[^1]

> KeyVault and Backup vault must have unique name DO NOT reuse ones from template

### Template will deploy following components

- Hub VNET
  - Azure Firewall Public IP
  - Azure Firewall Subnet
  - Azure Firewall
  - Azure Bastion Public IP
  - Azure Bastion Subnet
  - Azure Bastion
  - Shared Subnet

- Spoke VNET
  - Load Balancer Public IP for VMSS
  - Default subnet
  - Load Balancer for VMMS
  - VM Virtual Scale set 
- VNET peering between Hub VNET and Spoke VNET
- Azure Key Vault with set policies for the "Backup Management Service"
- Azure Key Vault secret with password for VM
- Azure Back Up Vault 

#### Set variables for the demo

In your bash console set following variables:
>
        rgName='Demo-RG'
        vnetName='hub-vnet' 
        subnetName='SharedSubnet'
        location='southcentralus'
        keyvaultName='demo-sc-keyvault'
        backupVaultname='demo-bkup-vault'
        nsgName='NSG-Shared-Hub'
        loganalyticsName='demo-LA-wksp'

#### Explanation

**rgName** - name of the resource group you create in preparation step  
**vnetName** - name of the HUB VNET, must match hub-vnet name in the template  
**subnetName** - name of the shared subnet in HUB VNET - must match name in the template  
**location** - name of the location where created resource group  
**keyvaultName**  - name of the Azure KeyVault you created in the template - must be unique  
**backupVaultname** - name of the Azure Backup Vault you created in the template - must be unique  
**nsgName** - name of the Network Security Group Can be anything will use later  
**loganalyticsName** -  name of the Network Security Group Can be anything will use later  

## Create Route Table

>In the Azure portal navigate to MainFirewall and make a note of the internal IP address.
Go to the add new and search for Route Table. Create route table in the reosucre group you created at the start and use the same location as the resource group.
>
>After Route Table was created you can add new route with target of 0.0.0.0/0 and last hop "Virtual Applicance" and IP address of the interall IP of MainFirewall. Assign Route Table to the SharedSubnet in the HuB VNET

## Create NSG and Add Rules

### Create NSG

>       az network nsg create -g $rgName -n $nsgName

### Add NSG Rules

Add Rule Inbound - Block All from Azure Virtual Networks

>       az network nsg rule create -g $rgName  -n  'inc-deny-all-vnet' --nsg-name $nsgName  --direction Inbound --source-address-prefix VirtualNetwork --destination-address-prefix VirtualNetwork --destination-port-ranges '*' --access Deny --protocol '*' --priority 4095 

Add Rule Inbound - Allow HTTPs from Azure Virtual Network 

 >      az network nsg rule create -g $rgName  -n 'inc-http-only' --nsg-name $nsgName  --direction Inbound --source-address-prefix VirtualNetwork --destination-address-prefix VirtualNetwork --destination-port-ranges 443 --access Allow --protocol Tcp --priority 100

Add Rule Inbound - Allow RDP from VNET 

>       az network nsg rule create -g $rgName  -n 'inc-RDP-only' --nsg-name $nsgName  --direction Inbound --source-address-prefix VirtualNetwork --destination-address-prefix VirtualNetwork --destination-port-ranges 3389 --access Allow --protocol Tcp --priority 200

Link NSG to Subnet

>       az network vnet subnet update -g $rgName --vnet-name $vnetName -n $subnetName --network-security-group $nsgName

### Send NSG diagnostic logs to Log Analytics

Create Log Analytics Workspace

>       az monitor log-analytics workspace create -g rgName -n $loganalyticsName

Get resource id for the NSG

>       nsgId=$(az network nsg show --name $nsgName --resource-group rgName  --query id --output tsv)

Set NSG diagnostics to send logs to Log Analytics Workspace

>       az monitor diagnostic-settings create --name SharedNSGDiags --resource $nsgId --logs '[ { "category": "NetworkSecurityGroupEvent", "enabled": true, "retentionPolicy": { "days": 30, "enabled": true } }, { "category": "NetworkSecurityGroupRuleCounter", "enabled": true, "retentionPolicy": { "days": 30, "enabled": true } } ]' --workspace $loganalyticsName --resource-group $rgName

### Encryption AND Backup

- Deploy VM with backup and encryotion via class-vm-demo.json template. 

>This will create VM in SharedSubnet of the Hub Vnet and VM will be subject to NSG and Route Tables

Check Encryption status

>       az vm encryption show --name "ProtectedVM" --resource-group  $rgName

Start backup

>       az backup protection backup-now --resource-group $rgName  --vault-name $backupVaultname --container-name 'ProtectedVM' --item-name  'ProtectedVM' --retain-until 01-07-2020 --backup-management-type AzureIaasVM

Monitor Backup

>       az backup job list --resource-group $rgName --query "[?properties.operation=='Backup'].{name:properties.entityFriendlyName, status:properties.status, duration:properties.duration}" -v $backupVaultname -o table

### AutoScaling

- Open cloud shell and switch to PowerShell

Set variable with name of Resource Group you created in the beginning.

>       $RGName = 'Demo-RG'

Get VM Scaleset and save it as object

>       $myvmss = Get-AZvmss -ResourceGroupName $RGName

Get address of the PublicIpAddress for the LoadBlancer in front of the Vm Scale set 

>       (Get-AzPublicIpAddress -ResourceGroupName demo-rg |where name -match $myvmss.name).IPAddress

- Copy IP address you see as a result of running this command

- Connecting to First VM In the scale set

#### Open command prompt and type

>       mstsc /v <IPAddress from perviouse command>:50001
>Example: mstsc /v 1.2.3.4:50001

- Use credentials from the template to login to the VM

- Open Admin Powershell console inside the VM

- In the PowerShell console run following commands 

Download CPU Stress utility from Sysinternals

>       Invoke-Webrequest -uri http://download.sysinternals.com/files/CPUSTRES.zip -outfile  C:\CPUSTRES.zip

Unzip tools into C: drive

>       Expand-Archive -Path C:\CPUSTRES.zip -DestinationPath c:\

Launch CPU stress utility

>       C:\CPUSTRES64.EXE

Configure CPU stress utility

Right click on the top process and set Activity Level to Maximum

![CPU Stress picture](/images/cpustress.png)

Right click on the second process and set Activity Level to Maximum and then click Activate

### Monitor VM scale set state

Go back to browser with cloud shell and run following command

>       while (1) {Get-AzVMssVM -ResourceGroupName Demo-RG -VMScaleSetName $myvmss.name ;sleep 10}

Note how autoscale starts adding new instances.

### Set CPU back to normal

- Go back to RDO session in VM , select CPU Stress GUI, right click on both active processes and select de-activate

- Back at Cloud Shell monitor how number of instances if going down in size

- Close Cloud shell to stop exercise 

### Clean Up Resources

Remove Azure Backup Vault

>Because Azure Backup Vault by default has a soft-delete feature where all back ups are persevered for 14 days after deletion we can not remove Azure Back Vault by deleting Resource Group
 
Disable soft-delete feature

>       az backup vault backup-properties set --soft-delete-feature-state Disable -g $rgName -n $backupVaultname

Find name of the backup container in the vault

>       containerName=$(az backup container list --backup-management-type AzureIaasVM -g $rgName -v $backupVaultname --query '[].name' -o tsv)

Find name of the protected item in the container

>       itemName=$(az backup item list -c $containerName -g $rgName -v $backupVaultname --query '[].name' -o tsv)

Disable backup and delete all data

>       az backup protection disable --container-name $containerName --item-name $itemName -g $rgName  -v $backupVaultname --delete-backup-data true -y

Remove resource group and all resources

>       az group delete -g $rgName -y

## [Optional] Create keyvault and configure it for use with Azure Backup to back up encrypted VMs

>       az keyvault create --name $keyvaultName --resource-group $rgName --location $location --enabled-for-disk-encryption --enabled-for-template-deployment
Create secret to use to provision VMs
>       az keyvault secret set --vault-name $keyvaultName  --name "VMPassword" --value "Test@2016"

Create backup Vault
>       az backup vault create --resource-group $rgName  --name $backupVaultname --location $location

Get the app id for backup 
>       backupAppId=$(az ad sp list --query "[?appDisplayName=='Backup Management Service'].{id:appId}" -o tsv --all)
Set key vault policy to allow read secrets 
>       az keyvault set-policy --name  $keyvaultName  --spn $backupAppId --secret-permissions get,list,backup

[^1] Use [reference documentation](https://docs.microsoft.com/en-us/azure/azure-resource-manager/templates/overview) to understand Azuer Templates better
