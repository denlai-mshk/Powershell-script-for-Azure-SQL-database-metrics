# https://learn.microsoft.com/en-us/azure/azure-monitor/reference/supported-metrics/microsoft-sql-managedinstances-metrics
# https://learn.microsoft.com/en-us/azure/azure-monitor/reference/supported-metrics/microsoft-sql-servers-databases-metrics
# https://learn.microsoft.com/en-us/azure/azure-monitor/reference/supported-metrics/microsoft-sql-servers-elasticpools-metrics
# Ensure the required modules are imported
if (-not (Get-Module -ListAvailable -Name Az.Accounts)) {
    Install-Module -Name Az.Accounts -AllowClobber -Force
}
Import-Module Az.Accounts

if (-not (Get-Module -ListAvailable -Name Az.Sql)) {
    Install-Module -Name Az.Sql -AllowClobber -Force
}
Import-Module Az.Sql

if (-not (Get-Module -ListAvailable -Name Az.Compute)) {
    Install-Module -Name Az.Compute -AllowClobber -Force
}
Import-Module Az.Compute


# Ensure proper login

$TenantId = "9fd8775f-acbf-40a6-aab5-4e44a19fa41c"
try {
    Connect-AzAccount -TenantId $TenantId -ErrorAction Stop
} catch {
    Write-Output "Failed to authenticate. Please ensure you are logged in with the correct account."
    exit
}

# Import the list of subscriptions from sublist.txt
$subscriptions = Import-Csv -Path "sublist.txt" -Delimiter ',' -Header "SubscriptionName", "SubscriptionId", "TenantId" | Select-Object -Skip 1

# Initialize the output files
$outputFile = "sqlstoragemetrics.csv"
if (Test-Path $outputFile) {
    Remove-Item $outputFile
}
New-Item -Path $outputFile -ItemType File


# Function to log discovery details
function LogDiscovery {
    param (
        [string]$SqlType,
        [string]$LicenseType,
        [string]$Status,
        [string]$vCores,
        [string]$UsedinGB,
        [string]$AllocatedInGB,
        [string]$StorageinGB,
        [string]$SubscriptionName,
        [string]$Region,
        [string]$ResourceGroup,
        [string]$SqlName,
        [string]$ResourceId
    )
    $logEntry = "$SqlType, $LicenseType, $Status, $vCores, $UsedinGB, $AllocatedInGB, $StorageinGB, $SubscriptionName, $Region, $ResourceGroup, $SqlName, $ResourceId"
    Add-Content -Path $outputFile -Value $logEntry
}

LogDiscovery -SqlType "SqlType" -LicenseType "LicenseType" -Status "Status" -vCores "vCores" -UsedinGB "UsedinGB" -AllocatedinGB "AllocatedinGB" -StorageinGB "StorageinGB" -SubscriptionName "SubscriptionName" -Region "Region" -ResourceGroup "ResourceGroup" -SqlName "SqlName" -ResourceId "ResourceId"

Write-Output "$(Get-Date -Format HH:mm:ss) Job started"
# Loop through each subscription
foreach ($subscription in $subscriptions) {
    Write-Output "$(Get-Date -Format HH:mm:ss) Processing subscriptions: $($subscription.SubscriptionName)"
    $SubscriptionId = $subscription.SubscriptionId
    $SubscriptionName = $subscription.SubscriptionName
    $TenantId = $subscription.TenantId

    # Check if SubscriptionId or SubscriptionName is empty
    if ([string]::IsNullOrEmpty($SubscriptionId) -or [string]::IsNullOrEmpty($SubscriptionName)) {
        Write-Output "Error: Missing SubscriptionId or SubscriptionName"
        break
    }

    try {
        # Debug output to check the subscription details
        Write-Output "Setting context for Tenant: $TenantId"
        Write-Output "Setting context for Subscription: $SubscriptionName ($SubscriptionId)"

        # Set the current subscription context
        Set-AzContext -TenantId $TenantId -SubscriptionName $SubscriptionName -ErrorAction Stop

        # Discover SQL Servers
        Write-Output "$(Get-Date -Format HH:mm:ss) Processing Get-AzSqlServer"
        $sqlServers = Get-AzSqlServer
        foreach ($server in $sqlServers) {
            # Discover SQL Databases for each server
            $sqlDatabases = Get-AzSqlDatabase -ResourceGroupName $server.ResourceGroupName -ServerName $server.ServerName
            foreach ($db in $sqlDatabases) {
                # Exclude master database
                if ($db.DatabaseName -eq "master"){
                    continue
                }

                $vCores = $db.Capacity
                $storageInGB = [math]::Round($db.MaxSizeBytes / 1GB, 4)
                $status = $db.Status
                # Get the database metrics
                # Database used space
                $db_metric_storage = $db | Get-AzMetric -MetricName 'storage'
                $db_UsedSpace = [Int64]$db_metric_storage.Data[0].Maximum
                $usedInGB = [math]::Round($db_UsedSpace / 1GB, 4)
                
                # Database allocated space
                $db_metric_allocated_data_storage = $db | Get-AzMetric -MetricName 'allocated_data_storage'
                $db_AllocatedSpace = [Int64]$db_metric_allocated_data_storage.Data[0].Average
                $allocatedInGB = [math]::Round($db_AllocatedSpace / 1GB, 4) 

                if (-not $db.ElasticPoolName) {
                    LogDiscovery -SqlType "sqldb" -LicenseType "N/A" -Status $status -vCores $vCores -UsedinGB $usedInGB -AllocatedInGB $allocatedInGB -StorageinGB $storageInGB -SubscriptionName $SubscriptionName -Region $db.Location -ResourceGroup $db.ResourceGroupName -SqlName $db.DatabaseName -ResourceId $server.ServerName
                }else {
                    LogDiscovery -SqlType "sqlpooldb" -LicenseType "N/A" -Status $status -vCores $vCores -UsedinGB $usedInGB -AllocatedInGB $allocatedInGB -StorageinGB $storageInGB -SubscriptionName $SubscriptionName -Region $db.Location -ResourceGroup $db.ResourceGroupName -SqlName $db.DatabaseName -ResourceId $db.ElasticPoolName
                }
                
            }
            # Discover SQL Elastic Pools
            Write-Output "$(Get-Date -Format HH:mm:ss) Processing Get-AzSqlElasticPool"
            $sqlElasticPools = Get-AzSqlElasticPool -ResourceGroupName $server.ResourceGroupName -ServerName $server.ServerName
            foreach ($pool in $sqlElasticPools) {
                $vCores = $pool.Capacity
                $storageInGB = [math]::Round($pool.MaxSizeBytes / 1GB, 4)
                $status = $pool.State
                # Get the database metrics
                # Database used space
                $poolresourceId = $pool.ResourceId
                $db_metric_storage = Get-AzMetric -ResourceId $poolresourceId -MetricName 'storage_used'
                $db_UsedSpace = [Int64]$db_metric_storage.Data[0].Average
                $usedInGB = [math]::Round($db_UsedSpace / 1GB, 4)
                
                # Database allocated space
                $db_metric_allocated_data_storage = Get-AzMetric -ResourceId $poolresourceId -MetricName 'allocated_data_storage'
                $db_AllocatedSpace = [Int64]$db_metric_allocated_data_storage.Data[0].Average
                $allocatedInGB = [math]::Round($db_AllocatedSpace / 1GB, 4)      

                LogDiscovery -SqlType "sqlpool" -LicenseType $pool.LicenseType -Status $status -vCores $vCores -UsedinGB $usedInGB -AllocatedInGB $allocatedInGB -StorageinGB $storageInGB -SubscriptionName $SubscriptionName -Region $pool.Location -ResourceGroup $pool.ResourceGroupName -SqlName $pool.ElasticPoolName -ResourceId $pool.ResourceId
            }
        }


        # Discover SQL Instance Pools
        Write-Output "$(Get-Date -Format HH:mm:ss) Processing Get-AzSqlInstancePool"
        $sqlInstancePools = Get-AzSqlInstancePool
        foreach ($pool in $sqlInstancePools) {
            if ([string]::IsNullOrEmpty($pool.LicenseType)) {
                continue
            }
            $vCores = $pool.VCores
            $storageInGB = "N/A" # no storage attributes in instance pools object
            $usedInGB = "N/A" # no storage attributes in instance pools object
            $allocatedInGB = "N/A" # no storage attributes in instance pools object
            $status = "N/A"
            LogDiscovery -SqlType "sqlmipool" -LicenseType $pool.LicenseType -Status $status -vCores $vCores -UsedinGB $usedInGB -AllocatedInGB $allocatedInGB -StorageinGB $storageInGB -SubscriptionName $SubscriptionName -Region $pool.Location -ResourceGroup $pool.ResourceGroupName -SqlName $pool.InstancePoolName -ResourceId $pool.Id
        }

        # Discover SQL Managed Instances
        Write-Output "$(Get-Date -Format HH:mm:ss) Processing Get-AzSqlInstance"
        $sqlManagedInstances = Get-AzSqlInstance
        foreach ($mi in $sqlManagedInstances) {
            if ([string]::IsNullOrEmpty($mi.LicenseType)) {
                continue
            }
            # Check if the managed instance is affiliated with any pool instance using $mi attributes
            if ($mi.InstancePoolName) {
                continue
            }
            $vCores = $mi.VCores
            $storageInGB = $mi.StorageSizeInGB
            $status = "N/A"

            # Get the database metrics
            # Database used space
            
            $miresourceId = $mi.Id
            $db_metric_storage = Get-AzMetric -ResourceId $miresourceId -MetricName 'storage_space_used_mb'
            $db_UsedSpace = [Int64]$db_metric_storage.Data[0].Average
            $usedInGB = [math]::Round($db_UsedSpace / 1024, 4)

            $allocatedInGB = 0

            LogDiscovery -SqlType "sqlmi" -LicenseType $mi.LicenseType -Status $status -vCores $vCores -UsedinGB $usedInGB -AllocatedInGB $allocatedInGB -StorageinGB $storageInGB -SubscriptionName $SubscriptionName -Region $mi.Location -ResourceGroup $mi.ResourceGroupName -SqlName $mi.ManagedInstanceName -ResourceId $mi.Id
        }




        # Discover SQL Virtual Machines
        Write-Output "$(Get-Date -Format HH:mm:ss) Processing SQL Virtual Machines"
        $sqlVms = Get-AzResource -ResourceType "Microsoft.SqlVirtualMachine/sqlVirtualMachines" -ExpandProperties
        foreach ($sqlVm in $sqlVms) {
            $sqlVmProperties = $sqlVm.Properties
            $licenseType = $sqlVmProperties.sqlServerLicenseType
            $sqlImageSku = $sqlVmProperties.sqlImageSku
            $status = $sqlVmProperties.Status


            $vCores = "N/A" # vCores might not be directly available
            $storageInGB = "N/A" # Storage details can be complex to extract
            $usedInGB = "N/A"
            $allocatedInGB = "N/A" # no storage attributes in instance pools object
            $status = $sqlImageSku # use this field to store SKU

            LogDiscovery -SqlType "sqlvm" -LicenseType $licenseType -Status $status -vCores $vCores -UsedinGB $usedInGB -AllocatedInGB $allocatedInGB -StorageinGB $storageInGB -SubscriptionName $SubscriptionName -Region $sqlVm.Location -ResourceGroup $sqlVm.ResourceGroupName -SqlName $sqlVm.Name -ResourceId $sqlVm.Id

            
        }


    } catch {
        Write-Output "Failed to set context for subscription $SubscriptionId. Error: $_"
    }
}

Write-Output "$(Get-Date -Format HH:mm:ss) SQL storage metrics is collected. Check the sqlstoragemetrics.csv for details."