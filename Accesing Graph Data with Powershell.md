# Accessing Microsoft Grap Data with Powershell

## *Accessing Microsoft Graph interactively*

This is a set of default methods using pre designed Powershell cmdlets. Requires at a minimum 'Microsoft.Graph.Authentication' module. I recommend to install only modules you are going to use in your scripts, rather than the whole SDK.

### *Using built-in SDK Cmdlets with delegated permissions*

This a preferred method of working with Microsoft Graph via Powershell but it has some disadvantages:

The advantages of using SDKI cmdlets is that SDK authors wrapped Microsoft API calls for you and created default output in a PSObject format, most of the time. 

The disadvantages of using all Powershell Graph SDK Cmdlets, you have to rely on SDK authors to fix bugs in inputs or outputs and in my experience SDL cmdlets do not handle paging well at all. In addition SDK V1 does not work with managed identity natively and requires a workaround. [SDKI v2 ,currently in public preview,](https://devblogs.microsoft.com/microsoft365dev/microsoft-graph-powershell-v2-is-now-in-public-preview-half-the-size-and-will-speed-up-your-automations/#:~:text=Speed%20up%20your%20automations%20%20%20Version%20of,MB%20%28-23.63%25%29%20%20%20651.31%20MB%20%28-23.89%25%29%20)  will work with Managed Identities directly. 

Generally I use cmdlets when I need to do a single 'write' task like configuration changes or a simple query that's expected to return no more than a 100 objects.

#### *Find Application with word 'Dev' in display name*

This is a simple example getting a list of users and requires 'Microsoft.Graph.Applications' module besides 'Microsoft.Graph.Authentication'. Scope must be specified in the initial connect cmdlet or Get-MgApllcations will return "Insufficient Permissions' error.

```powershell

Connect-MgGraph -Scopes 'Application.Read.All'
Get-MgApplication -ConsistencyLevel eventual -Search '"DisplayName:Test"'

```

More examples can be found in the [Powershell Graph SDK pages](https://learn.microsoft.com/en-us/powershell/module/microsoft.graph.applications/get-mgapplication?view=graph-powershell-1.0#examples)

#### *Find Application with word 'Dev' in display name using Microsooft Graph Beta*

In some cases you might want to use Microsoft Graph API Beta endpoint as they may contain more data or some of the Powershell Graph SDK cmdlets works only when 'beta' version is specified.

```powershell
Connect-MgGraph -Scopes 'Application.Read.All'
Select-MgProfile beta
Get-MgApplication -ConsistencyLevel eventual -Search '"DisplayName:Test"'

```

### *Using Microsoft Graph API direct call with Powershell Graph SDK and delegated permissions*

This method negates some of the disadvantages of using pure Powershell Graph SDKI cmdlets, while still abstracting authentication and authorization. However, because Microsoft Graph API Odata filters use both single and double quotes as well as characters like '$', you may have to work around pwoershell's text parsing when building complex filters.

#### *Find all registered applications and retrieve id and Display Name*

This code is useful when you want to get data quickly or test Graph URL abd Graph Explorer is not available.

```powershell
Connect-MgGraph -Scopes 'Application.Read.all'
$results = Invoke-MGGraphRequest -Method get -Uri 'https://graph.microsoft.com/v1.0/applications/?$select=id,displayName' -OutputType PSObject -Headers @{'ConsistencyLevel' = 'eventual' }
$results.value
```

For large data sets you can add this code to handle paging.

#### *Powershell Graph SDK loop to handle paging

 To avoid throttling loop is paused for 3 seconds

```powershell
if (!([string]::IsNullOrEmpty($results.'@odata.nextLink')))
 {
        
    do {
        $results = Invoke-MGGraphRequest -Method get -Uri $results.'@odata.nextLink'  -OutputType PSObject -Headers @{'ConsistencyLevel' = 'eventual'}
        $results.value
        Start-Sleep -Seconds 3
        } while (!([string]::IsNullOrEmpty($results.'@odata.nextLink')))
        
    }

```

## *Accessing Microsoft Graph for automated tasks*

Most examples below are targeted towards Azure serverless scenarios such as Automation Runbooks v5.1 and Azure Functions V2 Powershell v7.2 but can be adopted to run on VM as well.
For all scenarios listed you would need to set required Microsoft Graph permissions  

### *Using Managed Identity without Powershell Graph SDK*

With this method no additional Powershell SDK Modules are required and it works in any environment where Az.Accounts module is supported.
The downside is that data comes in json format only which may make it more difficult to parse, especially if paging is needed. This method can not be used for [advanced queries](https://learn.microsoft.com/en-us/graph/aad-advanced-queries?tabs=http), as it does not have an option to add headers to the request.

```powershell

Connect-AzAccount -Identity
$results = (Invoke-AzRestMethod -Uri 'https://graph.microsoft.com/v1.0/groups?$filter=startswith(displayName, ''GiveMeAccess'')&$select=id').Content | ConvertFrom-Json -Depth 99
$results.value

```

### *Using Managed Identity with Powershell Graph SDK*

This method uses a workaround to integrate Managed Identity with Powershell Graph SDK and allows to execute [advanced queries](https://learn.microsoft.com/en-us/graph/aad-advanced-queries?tabs=http) because of the ability to pass custom headers. However, with Azure Automation Runbooks, it only works with Powershell Version 5.1. This may change in the future.

```powershell

Connect-AzAccount -Identity -Environment 'AzureCloud'
$AccessToken = (Get-AzAccessToken -ResourceUrl "https://graph.microsoft.com").Token

$headers = @{
    'ConsistencyLevel'= 'Eventual'

}
Connect-MgGraph -AccessToken $AccessToken -Environment 'Global'
$results = Invoke-MGGraphRequest -Method get -Uri 'https://graph.microsoft.com/v1.0/applications/?$select=id,displayName&$count' -OutputType PSObject -Headers $headers
$results.value
```

Example to handle possible paging available above

### *Using Powershell Graph SDK with Certficate Based Authentication with Azure Automation Runbooks*

This method is supported natively by both Azure Automation and Powershell Graph SDK and confirmed to work in Azure Automation Runbook Powershell 5.1 runtime.

1. To use this method you would need to [register Azure AD application][1] and [grant it rights to Microsoft Graph][2] to execute task you would like to automate
2. Obtain a certificate, see example for [self-signed certificate you can use for testing][3]
3. [Upload certificate with private key to Azure Automation account][5]
4. [Upload certificate with public key to the Application Certificates and Secrets][4]

```powershell
Connect-AzAccount -Identity -Environment 'AzureCloud'
$certificate = Get-AutomationCertificate -Name "<insert name of saved certficate entry in Azure Automation>"
$headers = @{
    'ConsistencyLevel'= 'Eventual'

}
Connect-MgGraph -ClientId "<insert your app clinet id here>" -Certificate $certificate -Environment Global -TenantId "<insert your tenant id here>"

Invoke-MGGraphRequest -Method get -Uri 'https://graph.microsoft.com/v1.0/applications/?$select=id,displayName&$count' -OutputType PSObject -Headers $headers
#alternative option

Select-MgProfile beta
Get-MgApplication -ConsistencyLevel eventual -Property 'id','displayName'

```

### Using base powershell no Az or Powershell SDK Modules

This method allows for the most flexibility, since you are using built in Powershell modules, and can be used anywhere including Linux based containers. You are also less likely to run into problems with Az and Powreshell SDK modules. However you are also responsible for securely storing and retrieving credentials, error checking, addressing paging and if your task requires multiple calls and runs for more than a hour, you would need to add way to identify expired access token and then re-authenticare to obtain a new one. To use this method you need to perform following steps:

1. To use this method you would need to [register Azure AD application][1] and [grant it rights to Microsoft Graph][2] to execute task you would like to automate
2. [Generate and save application client secret][6]

```powershell

$uri = "https://login.microsoftonline.com/<insert tennat id>/oauth2/v2.0/token"
$clinet_id = <insert client id>
$client_secret = <insert client secret>
$queryURI = 'https://graph.microsoft.com/v1.0/applications/?$select=id,displayName&$count'
$scope = [System.Web.HTTPUtility]::UrlEncode("https://graph.microsoft.com/.default")

#Generating header values
$tokenRequestQueryHeaderss =@{
    ContentType = "application/x-www-form-urlencoded"
}

#Create body to pass when requesting access token
$body = "client_id=$($clinet_id)&scope=$($scope)&client_secret=$($client_secret)grant_type=client_credentials"

#Send a post request to obtain bearer token
$result = Invoke-RestMethod -Uri $uri -Body $body -Method Post -Headers $tokenRequestQueryHeaderss

#Generate Header for query by adding Access Token obtained earlier
$queryHeaders = @{
    Authorization = "Bearer $($result.access_token)"
}

#Send request 
$queryResult = (Invoke-RestMethod -Headers $queryHeaders -Body $body -Uri $queryURI  -Method Get).value

$queryResult

```

[1]:https://learn.microsoft.com/en-us/power-apps/developer/data-platform/walkthrough-register-app-azure-active-directory
[2]:https://learn.microsoft.com/en-us/graph/migrate-azure-ad-graph-configure-permissions?tabs=http%2Cupdatepermissions-azureadgraph-powershell
[3]:https://learn.microsoft.com/en-us/azure/active-directory/develop/howto-create-self-signed-certificate
[4]:https://learn.microsoft.com/en-us/azure/active-directory/develop/active-directory-certificate-credentials#uploading-the-certificate-
[5]:https://learn.microsoft.com/en-us/azure/automation/shared-resources/certificates?tabs=azure-powershell#create-a-new-certificate-with-the-azure-portal
[6]:https://learn.microsoft.com/en-us/azure/active-directory/develop/quickstart-register-app#add-credentials

