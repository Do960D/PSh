﻿GCI -file C:\users\ -force -Recurse -ErrorAction SilentlyContinue | Where-Object directory -match "Temp" | Remove-Item