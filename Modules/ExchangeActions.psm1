function Disable-UserActiveSync($u){Ensure-EXO;Set-CASMailbox $u -ActiveSyncEnabled $false}
function Convert-ToShared($u){Ensure-EXO;Set-Mailbox $u -Type Shared}
function Hide-FromGAL($u){Ensure-EXO;Set-Mailbox $u -HiddenFromAddressListsEnabled $true}
function Disable-AutoReply($u){Ensure-EXO;Set-MailboxAutoReplyConfiguration $u -AutoReplyState Disabled}
function Remove-MobilePartnerships($u){Ensure-EXO;Get-MobileDevice -Mailbox $u|Remove-MobileDevice -Confirm:$false}
function Remove-InboxRules($u){Ensure-EXO;Get-InboxRule -Mailbox $u|Remove-InboxRule -Confirm:$false}
Export-ModuleMember -Function *
