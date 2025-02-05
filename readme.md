# Batch get SQL database metrics across multiple subscription
This Powershell scripts is designed for retrieving the storage usage metrics of all SQL Servers deloyed across multiple subscriptions. It supports **Azure SQL Database**, **Azure SQL Elastic Pool**, **Azure SQL Managed Instance** except **Azure SQL Managed Instance Pool** and **Azure SQL on VM** are not supported by Azure monitor metrics.


##  Step 1: Install the Azure PowerShell Module
If you haven't install the following Azure PowerShell module, please send these commands:
```
    Install-Module -Name Az.Accounts -AllowClobber -Force
    Install-Module -Name Az.Sql -AllowClobber -Force
    Install-Module -Name Az.Compute -AllowClobber -Force
```

##  Step 2: Verify the Installation
Verify the modules are installed completely by sending these commands:
```
    Get-Module -ListAvailable -Name Az.Sql
    Get-Module -ListAvailable -Name Az.Accounts
    Get-Module -ListAvailable -Name Az.Compute
```   

##  Step 3: Single sign-on with your Azure account
Send "Connect-AzAccount" command to sign on with your browser, you may need to have Azure Subscription Reader role or corresponding role privilege above.

```
Connect-AzAccount -TenantId "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxx"
``` 

##  Step 4: Modify the sublist.txt
Edit the **sublist.txt** and place your subscription name and id after the 1st header row "SubscriptionName", "SubscriptionId"
```
"SubscriptionName", "SubscriptionId"
your-sub-name1, xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxx
your-sub-name2, xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxx
```  

##  Step 5: Execute the checksqlstorage.ps1
Open powershell, locate to the script folder, execute  [checksqlstorage](checksqlstorage.ps1)
``` 
.\checksqlstorage.ps1
``` 

Getting metrics may takes 1-2 minutues for each SQL Server approximately. Please be patient if your subscriptions have a lot of SQL databases.

After you see "SQL storage metrics is collected", you can check the **sqlstoragemetrics.csv** for result.    

## References
[sql-managedinstances-metrics](https://learn.microsoft.com/en-us/azure/azure-monitor/reference/supported-metrics/microsoft-sql-managedinstances-metrics)

[sql-servers-databases-metrics](https://learn.microsoft.com/en-us/azure/azure-monitor/reference/supported-metrics/microsoft-sql-servers-databases-metrics)

[sql-servers-elasticpools-metrics](https://learn.microsoft.com/en-us/azure/azure-monitor/reference/supported-metrics/microsoft-sql-servers-elasticpools-metrics)
