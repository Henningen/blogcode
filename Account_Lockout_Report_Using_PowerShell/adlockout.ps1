param($EventRecordID, $eventsource, $eventid, $EventData, $EventChannel)
Import-Module ActiveDirectory

$event = get-winevent -LogName $eventChannel -FilterXPath "<QueryList><Query Id='0' Path='$eventChannel'><Select Path='$eventChannel'>*[System[(EventRecordID=$eventRecordID)]]</Select></Query></QueryList>"
$eventXML = [xml]$Event.ToXml()
$eventXMLData= $eventXML.Event.EventData.Data

$FailedUser=$eventXMLData[0].'#text'
$FailedComputer=$eventXMLData[1].'#text'
$FailedDomain=$eventXMLData[5].'#text'

$Mail=@{
	From = 'accountlockouts@int.company.com'
	Cc = 'ADTeam@int.company.com'
	SMTPServer = 'smtp.int.company.com'
	Subject = "AD Account lockout: User $($FailedDomain)\$($FailedUser) locked out from computer $($FailedComputer)"
}
$mailto = ((Get-ADUser -Identity $FailedUser -Properties mail).mail)
$mail.Add("To", $mailto)
$body=@"
<h1>Account Locked Out</h1>

<p>The account <strong>$($FailedDomain)\$($FailedUser)</strong> has been locked out. The lock out happened due to a failed login attempt at  computer <strong>$($FailedComputer)</strong>.</p>

<p>If you're aware of the incident, you can ignore this email. If this is <strong>not</strong> known, you should contact the IT Department to make sure noone is trying to abuse your company account.</p>

<p>Usual causes for account lockouts are:</p>

<ul>
<li>Events close to a planned change of the password where

<ul>
<li>User forgot to update password on an external device (typical cellular phone/smartphone). The computer mentioned above will in such cases be the company e-mail server.</li>
<li>Automatic logins/saved credentials in f.ex. outlook or other software. The password might be saved under control panel-&gt;credential manager of computer and trying to login with old credentials.</li>
<li>User enters wrong password multiple times (switch before the weekend, and forgot?)</li>
</ul>
</li>
</ul>

<p>Brgds,<br>
IT Department</p>

<p><em>This is a auto-generated email, and the reply address is not staffed</em></p>
"@
$mail.Add("Body", "$body")
Send-MailMessage @mail -BodyAsHTML

