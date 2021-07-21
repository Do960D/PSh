#Before we start catch this
$Entombment = 'OU=RIP,DC=Dom,DC=local'
$HereWeHunt = 'OU=PROD,DC=Dom,DC=local'
$DecayDate = (Get-Date).addDays(-90) 
$PerceiveAsANewBorn = (Get-Date).addDays(-30)

#Fence the Hunting Grounds
$THG = Get-Aduser -f {(LastLogonDate -lt $DecayDate) -or -not (lastlogontimestamp -like '*') -and -not (iscriticalsystemobject -eq $true) -and (Created -lt $PerceiveAsANewBorn)} -Property * -SearchBase $HereWeHunt |
    Where {$_.DistinguishedName -notmatch 'Секретарь'}      |
    Where {$_.DistinguishedName -notmatch 'Системный*'}     |
    Select name
Search-ADAccount $THG -UsersOnly -SearchBase $HereWeHunt | move-ADObject -TargetPath $Entombment -WhatIf
