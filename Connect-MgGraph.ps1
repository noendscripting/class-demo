Connect-MgGraph -Scopes 'Application.Read.all'

$results = Invoke-MGGraphRequest -Method get -Uri 'https://graph.microsoft.com/v1.0/applications/?$select=id,displayName' -OutputType PSObject -Headers @{'ConsistencyLevel' = 'eventual' }
$results.value
if (!([string]::IsNullOrEmpty($results.'@odata.nextLink')))
 {
    
        
    do {
        $results = Invoke-MGGraphRequest -Method get -Uri $results.'@odata.nextLink'  -OutputType PSObject -Headers @{'ConsistencyLevel' = 'eventual'}
        $results.value
        Start-Sleep -Seconds 3
        } while (!([string]::IsNullOrEmpty($results.'@odata.nextLink')))
        
    }

