#Before we start catch this
    $Entombment = 'DC=RIP,DC=local'
    $HereWeHunt = 'DC=DOM,DC=local'
    $DecayDate = (Get-Date).addDays(-90) 
    $PerceiveAsANewBorn = (Get-Date).addDays(-30)
    
#Burie the dead
    Search-ADAccount -AccountDisabled -UsersOnly -SearchBase $HereWeHunt | Move-ADObject -TargetPath $Entombment
       
#Fence the Hunting Grounds
    Get-Aduser -f {(LastLogonDate -lt $DecayDate) -or -not (lastlogontimestamp -like '*') -and -not (iscriticalsystemobject -eq $true) -and (Created -lt $PerceiveAsANewBorn)} -Property * -SearchBase $HereWeHunt |
        Where DistinguishedName -notmatch 'Секретарь'      |
        Where DistinguishedName -notmatch 'Системный*'      |

#Exile The Undead
        Move-ADObject -TargetPath $Entombment 
                     
#Rest In Peace
     Get-ADUser -Filter * -SearchBase $Entombment | Disable-ADAccount
