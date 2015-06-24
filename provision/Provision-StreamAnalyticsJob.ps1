[CmdletBinding()] 
Param( 

	[ValidateNotNullOrEmpty()]
	[Parameter (Mandatory = $True)]
	[string]$SubscriptionName,          

	[ValidateNotNullOrEmpty()]
	[Parameter (Mandatory = $False)]
	[String]$ResourceGroupPrefix = "fabrikam",

	[ValidateNotNullOrEmpty()]
	[Parameter (Mandatory = $False)]
	[String]$StreamAnalyticsSQLJobName = "WebJobstreamjob01",

	[ValidateNotNullOrEmpty()]
	[Parameter (Mandatory = $False)]
	[String]$StreamAnalyticsColdStorageJobName = "WebJobcoldstoragejob02",


	[ValidateNotNullOrEmpty()]
	[Parameter (Mandatory = $True)]
	[String]$ServiceBusNamespace,                                   
    
	[ValidateNotNullOrEmpty()]
	[Parameter (Mandatory = $False)]
    [ValidatePattern("^[A-Za-z0-9]$|^[A-Za-z0-9][\w-\.\/]*[A-Za-z0-9]$")] # needs to start with letter or number, and contain only letters, numbers, periods, hyphens, and underscores.
	[String]$EventHubName = "eventhub01",                  
    
	[ValidateNotNullOrEmpty()]
	[Parameter (Mandatory = $False)]
	[string]$SqlDatabaseName = "fabrikamdb01",

	[ValidateNotNullOrEmpty()]
	[Parameter (Mandatory = $True)]
	[string]$SqlDatabasePassword,

	[ValidateNotNullOrEmpty()]
	[Parameter (Mandatory = $True)]
	[string]$SqlServerName,

	[ValidateNotNullOrEmpty()]
	[Parameter (Mandatory = $False)]
	[string]$SqlDatabaseUser="fabrikamdbuser01",

	[ValidateNotNullOrEmpty()]
	[Parameter (Mandatory = $False)]
    [ValidatePattern("^[A-Za-z][-A-Za-z0-9]*[A-Za-z0-9]$")]      # needs to start with letter or number, and contain only letters, numbers, and hyphens.
	[String]$ConsumerGroupNameSQL= "consumergroupSQL01", 

	[ValidateNotNullOrEmpty()]
	[Parameter (Mandatory = $False)]
    [ValidatePattern("^[A-Za-z][-A-Za-z0-9]*[A-Za-z0-9]$")]      # needs to start with letter or number, and contain only letters, numbers, and hyphens.
	[String]$ConsumerGroupNameCold= "consumergroupCold01", 

	[ValidateNotNullOrEmpty()]
	[Parameter (Mandatory = $False)]
	[String]$EventHubSharedAccessPolicyName = "ManagePolicy",

    [ValidateNotNullOrEmpty()]
	[Parameter (Mandatory = $True)]
    [ValidateScript({
      # we need to use cmathch which is case sensitive, don't use match
      If ($_ -cmatch "^[a-z0-9]*$") {                         # needs contain only lower case letters and numbers.
        $True
      }else {
        Throw "`n---Storage account name can only contain lowercase letters and numbers!---"
      }
    })]
	[String]$StorageAccountName,   
       
	[ValidateNotNullOrEmpty()]
 	[Parameter (Mandatory = $False)]
	[string]$ContainerName = "container01",

	[ValidateNotNullOrEmpty()]
    [Parameter (Mandatory = $False)]
    [ValidatePattern("^[A-Za-z0-9]$|^[A-Za-z0-9][\w-\.\/]*[A-Za-z0-9]$")]
	[String]$JobDefinitionPathSQL = "StreamAnalyticsJobDefinitionSQL.json",       # optional default to C:\StreamAnalyticsJobDefinition.json

	[ValidateNotNullOrEmpty()]
    [Parameter (Mandatory = $False)]
    [ValidatePattern("^[A-Za-z0-9]$|^[A-Za-z0-9][\w-\.\/]*[A-Za-z0-9]$")]
	[String]$JobDefinitionPathCold = "StreamAnalyticsJobDefinitionColdStorage.json",       # optional default to C:\StreamAnalyticsJobDefinition.json

	[ValidateNotNullOrEmpty()]
    [Parameter (Mandatory = $False)]
	[String]$Location = "Central US"
)

function Upload-ReferenceData
{
    $key = Get-AzureStorageKey -StorageAccountName $StorageAccountName
    $context = New-AzureStorageContext -StorageAccountName $StorageAccountName -StorageAccountKey $key.Primary;
    Set-AzureStorageBlobContent -Blob fabrikam/buildingdevice.json -Container container01refdata -File .\fabrikam_buildingdevice.json -Context $context -Force
}

############################
##
## Script start up
##
############################  

.\Init.ps1
        
$VerbosePreference = "SilentlyContinue" 
Switch-AzureMode -Name AzureServiceManagement
$VerbosePreference = "Continue"

Assert-AzureModuleIsInstalled

Select-AzureSubscription -SubscriptionName $SubscriptionName

$ResourceGroupName = $ResourceGroupPrefix + "-" + $Location.Replace(" ","-")

Write-Verbose ("Resource Group Name: " + $ResourceGroupName)

#Add-AzureAccount

Select-AzureSubscription -SubscriptionName $SubscriptionName

try
{
    # WARNING: Make sure to reference the latest version of the \Microsoft.ServiceBus.dll 
    Write-Verbose "Adding the [Microsoft.ServiceBus.dll] assembly to the script..." 
    $scriptPath = Split-Path (Get-Variable MyInvocation -Scope 0).Value.MyCommand.Path
    $packagesFolder = (Split-Path $scriptPath -Parent) + "\src\packages"
    $assembly = Get-ChildItem $packagesFolder -Include "Microsoft.ServiceBus.dll" -Recurse
    Add-Type -Path $assembly.FullName

    Write-Verbose "The [Microsoft.ServiceBus.dll] assembly has been successfully added to the script." 
}
catch [System.Exception]
{
    Write-Error("Could not add the Microsoft.ServiceBus.dll assembly to the script. Make sure you build the solution before running the provisioning script.")
}

$sbr = Get-AzureSBAuthorizationRule -Namespace $ServiceBusNamespace
$NamespaceManager = [Microsoft.ServiceBus.NamespaceManager]::CreateFromConnectionString($sbr.ConnectionString); 
$EventHub = $NamespaceManager.GetEventHub($EventHubName);
$Rule = $null
if($EventHub.Authorization.TryGetSharedAccessAuthorizationRule($EventHubSharedAccessPolicyName, [ref]$Rule))
{
    $EventHubSharedAccessPolicyKey = $Rule.PrimaryKey
}
else
{
    Write-Verbose "Can not find the Shared Access Key for Manage in event hub"
}

# Get Storage Account Key
$storageAccountKey = Get-AzureStorageKey -StorageAccountName $StorageAccountName
$storageAccountKeyPrimary = $storageAccountKey.Primary
$RefdataContainerName = $ContainerName+"refdata"

# Create SQL Job Definition


$JobDefinitionText = (Get-Content -LiteralPath $JobDefinitionPathSQL).
                    Replace("_StreamAnalyticsJobName",$StreamAnalyticsSQLJobName).
                    Replace("_Location",$Location).
                    Replace("_ConsumerGroupName",$ConsumerGroupNameSQL).
                    Replace("_EventHubName",$EventHubName).
                    Replace("_ServiceBusNamespace",$ServiceBusNamespace).
                    Replace("_EventHubSharedAccessPolicyName",$EventHubSharedAccessPolicyName).
                    Replace("_EventHubSharedAccessPolicyKey",$EventHubSharedAccessPolicyKey).
                    Replace("_AccountName",$StorageAccountName).
                    Replace("_AccountKey",$storageAccountKeyPrimary).
                    Replace("_Container",$ContainerName).
                    Replace("_RefdataContainer",$RefdataContainerName).
                    Replace("_DBName",$SqlDatabaseName).
                    Replace("_DBPassword",$SqlDatabasePassword).
                    Replace("_DBServer",$SqlServerName).
                    Replace("_DBUser",$SqlDatabaseUser)

$TempFileName = [guid]::NewGuid().ToString() + ".json"

$JobDefinitionText > $TempFileName

$VerbosePreference = "SilentlyContinue" 
Switch-AzureMode AzureResourceManager
$VerbosePreference = "Continue" 

New-AzureResourceGroupIfNotExists -ResourceGroupName $ResourceGroupName -Location $Location

try
{
    New-AzureStreamAnalyticsJob -ResourceGroupName $ResourceGroupName  -File $TempFileName -Force
}
catch [Exception]
{
    Write-Verbose $_.Exception.Message
    throw
}
finally
{
    if (Test-Path $TempFileName) 
    {
        Write-Verbose "deleting the temp file ... "
        Clear-Content $TempFileName
        Remove-Item $TempFileName
    }
}

Write-Verbose "Completed created Azure Stream Analytics Job for SQL"
Write-Verbose "Create Azure Stream Analytics Job for Cold Storage"


$JobDefinitionText = (Get-Content -LiteralPath $JobDefinitionPathCold).
                    Replace("_StreamAnalyticsJobName",$StreamAnalyticsColdStorageJobName).
                    Replace("_Location",$Location).
                    Replace("_ConsumerGroupName",$ConsumerGroupNameCold).
                    Replace("_EventHubName",$EventHubName).
                    Replace("_ServiceBusNamespace",$ServiceBusNamespace).
                    Replace("_EventHubSharedAccessPolicyName",$EventHubSharedAccessPolicyName).
                    Replace("_EventHubSharedAccessPolicyKey",$EventHubSharedAccessPolicyKey).
                    Replace("_AccountName",$StorageAccountName).
                    Replace("_AccountKey",$storageAccountKeyPrimary).
                    Replace("_Container",$ContainerName).
                    Replace("_RefdataContainer",$RefdataContainerName).
                    Replace("_DBName",$SqlDatabaseName).
                    Replace("_DBPassword",$SqlDatabasePassword).
                    Replace("_DBServer",$SqlServerName).
                    Replace("_DBUser",$SqlDatabaseUser)

$TempFileName = [guid]::NewGuid().ToString() + ".json"

$JobDefinitionText > $TempFileName

$VerbosePreference = "SilentlyContinue" 
Switch-AzureMode AzureResourceManager
$VerbosePreference = "Continue" 

try
{
    New-AzureStreamAnalyticsJob -ResourceGroupName $ResourceGroupName  -File $TempFileName -Force
}
catch [Exception]
{
    Write-Verbose $_.Exception.Message
    throw
}
finally
{
    if (Test-Path $TempFileName) 
    {
        Write-Verbose "deleting the temp file ... "
        Clear-Content $TempFileName
        Remove-Item $TempFileName
    }
}

$VerbosePreference = "SilentlyContinue" 
Switch-AzureMode -Name AzureServiceManagement
$VerbosePreference = "Continue"

Upload-ReferenceData

Write-Verbose "Create Azure StreamAnalyticsJob Completed"