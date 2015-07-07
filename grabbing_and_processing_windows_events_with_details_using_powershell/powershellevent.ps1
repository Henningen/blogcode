param($EventRecordID, $eventsource, $eventid, $EventData, $EventChannel)
$event = get-winevent -LogName $eventChannel -FilterXPath "<QueryList><Query Id='0' Path='$eventChannel'><Select Path='$eventChannel'>*[System[(EventRecordID=$eventRecordID)]]</Select></Query></QueryList>"
@Mail{
	From = 'backupreports@int.company.com'
	To = 'itsupport@int.company.com'
	SMTPServer = 'smtp.int.company.com'
	Subject = "Eventid $eventid from source $eventsource triggged on $($env:computername)"
	Body = "Eventid $eventid from source $eventsource triggged on $($env:computername):`n`r$($event.message)"
}
if ($eventsource -eq "Microsoft-Windows-Backup){
	switch ($eventid) {
		1 { $mail.Set_Item("Subject", ( "(Backup Started)" + $mail.Get_Item("Subject") ) }
		4 { $mail.Set_Item("Subject", ( "(Backup Success)" + $mail.Get_Item("Subject") ) }
		default { $mail.Set_Item("Subject", ( "(Backup Other)" + $mail.Get_Item("Subject") ) } 
	}
}
send-mailmessage @Mail
