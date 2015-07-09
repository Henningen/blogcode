import-module E:\ConfigMgr2012\AdminConsole\bin\ConfigurationManager.psd1
$smtpServer = "<ip_addr>"
$smtpFrom = "SCCM_noreply@<customerdomain>.no"
$smtpTo = "<customer>@<customerdomain>.no"
sl <sitename>:
$pendingRequests = ( Get-CMApprovalRequest | Where-Object { $_.CurrentState -eq 1 } )
$pendingRequestsLastHour = ( Get-CMApprovalRequest | Where-Object { $_.CurrentState -eq 1 } | where-object { ( (get-date) - $_.LastModifiedDate)  -lt (new-timespan -hours 1 -minutes 5) } )
if ($pendingRequestsLastHour.count -gt 0) {
    $body=@()
    $messageSubject = "SCCM Pending Application Requests. " + $pendingRequests.count + " requests are waiting approval in Configuration Manager."
    $body += '
    Please go under Software-Library->Overview->Application Management->Approval Requests and either Approve or Deny the following requests:
'
    $body += ($pendingRequests | fl Application, Comments ,User | Out-String)
    send-mailmessage -from "$smtpFrom" -to "$smtpTO" -subject "$messageSubject" -body "$body" -smtpServer "$smtpServer" -priority High
}