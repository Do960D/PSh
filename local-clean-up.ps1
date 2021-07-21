$DayX = (Get-Date).addDays(-200)   #Set date of rancid
Get-CimInstance Win32_userprofile |#get all profiles
? lastusetime 		          |#get readeble date format
select lastusetime, localpath 	  |#choose the right one 
where localpath -like 'C:\Users\*'|#select non special profiles
Where lastusetime -lt $DayX  	  |#select rancided profiles
Sort-Object -Property lastusetime  #sort by time