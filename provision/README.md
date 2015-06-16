![Microsoft patterns & practices](http://pnp.azurewebsites.net/images/pnp-logo.png)

# Steps

> Note: These steps are a brief overview. For detailed instructions on building and provisioning the sample solution, see ![Building and Running the IoT Sample Solution](building-and-deploying-the-sample-solution.md)

1. Build the solution to download the Nuget package. The build process will report that the file mysettings.config is missing. It's created in the next step.

1. Run `Provision-All` using Azure PowerShell.  It will generate a mysettings.config file with the used settings. Except for accounts used by the Unit Test.  

1. In the Azure portal, open the Stream Analytics job `fabrikamstreamjob01`, and test the connections for `input01`, `input02`, `output01`, and `output02`.

1. Upload `fabrikam_buildingdevice.json` to the `container01refdata` of the storage account and rename it as as `fabrikam/buildingdevice.json`.

1. Rebuild the system it should pick up the new mysettings.config file.

1. Select "Start up Projects" from the Solution.  And set both of the ConsoleHost Applications to start. 

1. Start the Solution.

1. In the Cold Storage ConsoleHost Window. Select item 2 to provision the Cold Storage Blob. You only have to do this once.   

1. Start the Stream Analytics job.

1. In the Simulator ConsoleHost Window.  Select either scenario to start the Simulator. The Simulator runs until you stop it. 

1. In the Cold Storage ConsoleHost Window. Select item 1 to start the Cold Storage Service.  


Notes:

- All passwords require an uppercase letter, lowercase letter, a number and a special character. The password for the HDInsight cluster must be at least 10 characters long.

- Check to make sure you have sufficient resources to create the Hadoop cluster.

- Set all blob containers to be publicly accessible by the Hadoop cluster. 
