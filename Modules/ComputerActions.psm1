function Get-HybridComputer($n){Ensure-AD;Ensure-Graph;$a=$null;try{$a=Get-ADComputer $n -Properties * -EA Stop}catch{};$s=$n.Replace("'","''");[pscustomobject]@{AD=$a;Entra=@(Get-MgDevice -Filter "displayName eq '$s'" -All)}}
function Remove-EntraComputers($x){$x|%{Remove-MgDevice -DeviceId $_.Id -Confirm:$false}}
function Remove-ADComputerRecursive($x){Remove-ADObject $x.DistinguishedName -Recursive -Confirm:$false}
Export-ModuleMember -Function *
