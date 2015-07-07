import-module ActiveDirectory
#List of our exclusive groups
$Groups=@(
"Department1",
"Department2",
"Department3",
"Department4",
"Department5",
"Department6"
)

#Our OU containing user objects
$userOU="dc=int,dc=customer,dc=com"

#To store hashtables to do member user lookup.
$groupHTs=@()

#To store aduser objects who are NOT member of exactly 1 of the groups.
$duplicateusers=@()

#Populate group hashtables with members recursivly
ForEach-Object ($group in $groups){
	$members = get-ADGroupMember $group -Recursive
	$groupht = @{}
	ForEach-Object ($member in $members){
		$groupht.add($member.samaccountname, $group)
	}
	$groupHTs += $groupht
}
#Get all relevant enabled users from AD and use hashtables to count number of groups they are member of.
$users = (Get-ADUser -filter * -searchbase $userou |
Where-Object { $_.enabled -eq $true })
ForEach-Object ($user in $users){
	$groupmemberships=@()
	ForEach-Object ($groupht in $groupHTs){
		if ($groupht.Containskey($user.samaccountname)) {
			$groupmemberships += $groupht.Get_Item($user.samaccountname)
		}
	}
	#If 0 or more than 1 group memberships, add metainfo and store users for report
	if ($groupmemberships.count -eq 0 -or $groupmemberships.count -gt 1){
		$report = [ordered]@{}
		$report.count = $count
		$report.samaccountname = $user.samaccountname 	
		$report.groupmemberships = ($groupmemberships -join ",")
		$reportobject = New-Object -TypeName PSObject -prop $report
		$duplicateusers += $reportobject
	}	
}
$duplicateusers | 
Sort-Object -property @{Expression="count";Descending=$true},@{Expression="samaccountname";Descending=$false}  |
Export-Csv -Encoding UTF8 -NoTypeInformation -Delimiter ";" -Path "DepDup.csv"
