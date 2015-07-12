Function global:New-VMFromDatastoreVMX { 
<#

            .SYNOPSIS

            This Cmdlet scans a datastore for vmx files, and adds them to ESXi/vCenter inventory. 

            .DESCRIPTION

            This Cmdlet scans a datastore for vmx files, and adds them to ESXi/vCenter inventory. 

            .EXAMPLE

            Get-Datastore "datastore1" | New-VMFromDatastoreVMX -Verbose -WhatIf

	    Scans the datastore named "datastore1" for vmx files and simulates adding them to inventory.
	    With the -whatif switch no adding will be performed.
            The verbose switch produces detailed information about what is going on.
 

            .EXAMPLE

             New-VMFromDatastoreVMX -datastores (Get-Datastore) -excludeVMs (Get-VM @("VM01", "VM02")

	    Scans all datastores and add all found .vmx files to inventory, except for the excluded VMS, VM01 and VM02 (needs to exist in ESXi).

            .EXAMPLE

	    Get-Datastore | Where-Object { $_.Extensiondata.Summary.MultipleHostAccess -eq $true } |  New-VMFromDatastoreVMX
	    
	    Add all .vmx from all datastores that qualifies as shared storage (SAN, NFS, iSCSI). 
	    WARNING: MultipleHostAccess only works with vCenter connection, not ESXi.


            .EXAMPLE
	  
	    Get-Datastore | Where-Object { $_.name -match '^SATA' } | New-VMFromDatastoreVMX
 		
	    Get all Datastore whose name begins with SATA, scan them for vmx files and add those to inventory.

	   .EXAMPLE

	   Get-Datastore | New-VMFromDatastoreVMX -excludeVMs (Get-VM)

	   Add all vmx files from all datastore, but exclude those virtual machines already in inventory.	
	    
            .COMPONENT

            Requires vSphere PowerCLI to work.
	    Need to have a single active Connect-VIserver connection while running.

            .LINK

            https://henningervik.wordpress.com/2015/07/10/register-vmx-files-on-datastore/

	    .PARAMETER Datastores

	    One or more datastore objects as returned by Get-Datastore.
	    Datastores will be scanned for .vmx files.

	    .PARAMETER excludeVMs

	    One or more Virtual Machines objets as returned by Get-VM.
	    The virtual machines will be excluded so they aren't imported even though they are eligable.
	    Typical usage is to exclude virtual machines already in inventory.
#>
	[CmdletBinding(
		SupportsShouldProcess,
		ConfirmImpact="Medium"
	)]
	param(
		[Parameter(
		Position=0,
		Mandatory,
		ValueFromPipeline=$True,
		ValueFromPipeLineByPropertyName=$True)]
		[ValidateNotNullOrEmpty()]  
		[VMware.VimAutomation.ViCore.Impl.V1.DatastoreManagement.VmfsDatastoreImpl[]] $Datastores,

		[Parameter(
		ValueFromPipeLineByPropertyName=$True)] 
		[VMware.VimAutomation.ViCore.Impl.V1.Inventory.VirtualMachineImpl[]] $excludeVMs
	)
	begin{
		Write-Progress -Activity "$($MyInvocation.MyCommand)" -percentComplete 5
		Write-Verbose "Initializing..."
		$vmxfiles=@()	
		$excludeVMXFiles=@() 
		$excludeVMXFiles = $excludeVMS.Extensiondata.config.files.vmpathname
	}
	process{
		$total=$datastores.count
		$count=1
		Write-Progress -Activity "$($MyInvocation.MyCommand)" -percentComplete 10
		write-progress -id 1 -activity "Scanning Datastores for VMX files" -percentcomplete 0
		foreach ($datastore in $datastores){
			write-progress -id 1 -activity "Scanning Datastore $count/$total for VMX files" -percentcomplete ($count*100/$total)
			write-verbose "Processing datastore $datastore"
			$count++;
			# We use a temp variable so that we can loop it and produce nice verbose output and per datastore count.
			$vmxtemp = @()
			Get-Childitem $($datastore.DatastoreBrowserPath) -Include *.vmx -recurse | Foreach-Object {
				$vmxtemp += $_
				Write-Verbose "Found $($_.name)"
			}
			$vmxfiles += $vmxtemp
			write-verbose "Finished processing datastore $datastore. Found $($vmxtemp.count) VMX files."		
		}
		Write-Verbose "Finished processing all datastores. Found $($vmxfiles.count) VMX files."
		Write-Progress -Activity "$($MyInvocation.MyCommand)" -percentComplete 50

		#Time to add vmx-files to our host
		$total=$vmxfiles.count
		$count=1
		foreach ($vmxfile in $vmxfiles){
			write-progress -id 1 -activity "Processing VMX Files ($count/$total)" -percentcomplete ($count*100/$total)
			#COMMENTOUT The below is a testing delay for seeing progress messages, they are very rapid when excluding etc. Comment out for production.
			#Start-Sleep -Seconds 1
			$count++
			#Check if excluded by -excludeVMs
			if ($excludeVMXFiles -contains $vmxfile.DatastoreFullPath){
				write-verbose "Excluded VMX because it was part of -excludeVMs: $($vmxfile.DatastoreFullPath)"
				#Use continue to force script to go to next item of ForEach-Object loop if excluded
				continue
			}	
			#Check if Lock Files (.LCK) Exist in same folder as VMX, if yes, skip registering. Lock files means the Virtual Machine is probably booted by other host.
			if ((Get-Childitem "$($vmxfile.PSParentPath)\*.lck").count -gt 0){
					write-verbose "Excluded VMX because it had a .lck (lock) file next to the .vmx file: $($vmxfile.DatastoreFullPath)"
					#Use continue to force script to go to next item of ForEach-Object loop if excluded
					continue
			}
			#Check if the vmware.log in the .vmx folder hasn't been updated for a very long time and write a warning if not (60 days)
			if ( (Get-Childitem "$($vmxfile.PSParentPath)\vmware.log" | New-Timespan).days -gt 60){
				Write-Warning "$($vmxfile.DatastoreFullPath) has an vmware.log that hasn't been updated in the last 60 days (Last update was: $((Get-Childitem "$($vmxfile.PSParentPath)\vmware.log" | New-Timespan).days) days ago). Could indicate orphan VM (or just very long since previous boot)."
			} 		
			#if not excluded by either, register it with New-VM (but check -confirm and -whatif first)
			if ($PSCmdlet.ShouldProcess("Item: $($vmxfile.DatastoreFullPath)", 'Register VMX')){
				Write-Verbose "Registering $($vmxfile.DatastoreFullPath) with ESXi/vCenter."
				New-VM -VMFilePath $vmxfile.DatastoreFullPath 	
			}	
		}
	}
	end{
		Write-Progress -Activity "$($MyInvocation.MyCommand)" -percentComplete 100
	}
}