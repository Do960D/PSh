$VerbosePreference = "SilentlyContinue"

# Задержка
$pauseDuration = 5

# Получаем описание служб
function Get-ServiceCommandLine {
    param (
        [string]$executableName
    )

    $result = @()

    # Перебирает службы, пока не найдет ту, что указана в аргументах как executableName
    $services = Get-WmiObject Win32_Service | Where-Object {$_.PathName -like "*$executableName*"}
    foreach ($service in $services) {
        $serviceInfo = @{
            ServiceName = $service.Name
            PathToExecutable = $service.PathName
            ServiceParameters = $service.StartName
        }
        $result += New-Object PSObject -Property $serviceInfo
    }

    return $result
}

# Выделяем из строки нужный фрагмент
function Get-StringFragment {
    param (
        [string]$inputString,
        [string]$regularExpression
    )

    $dValue = [regex]::Match($inputString, $regularExpression).Groups[1].Value
    return $dValue
}

# Останавливаем экземпляр службы по имени
function Stop-Services {
    param (
        [string]$serviceName,
        [boolean]$force = $false
    )
    
    try {
        Get-Service -Name $serviceName | Stop-Service
    }
    catch {
        Write-Host "error: $_"
        exit
    }
}

# Стартуем службы
function Start-Services {
    param (
        [string]$serviceName
    )
    Get-Service -Name $serviceName | Start-Service   
}

# Внутри folderPath ищем папки подходящие по имени target, в них защищаем файлы кроме exception - потом все пустые подкаталоги удаляем
function Clear-Folder {
    param([string] $folderPath,
          [string] $target,
          [string] $exception=@(".lst") # это массив, можно аля так @(".lst", ".ini", ...)
    ) 

    Write-Host "Clear folder: $folderPath\*\$target"

    Get-ChildItem -Path $folderPath -Recurse -Filter $target | ForEach-Object {
        Get-ChildItem -File -Path $_.FullName -Recurse | Where-Object { $_.Extension -notin $exception } | ForEach-Object {
            Remove-Item -Path $_.FullName -Recurse -Force
            Write-Host " - delete file: $_"
        }
        # Удаление пустых подкаталогов
        DeleteFolderIfWithoutFiles $_.FullName
    }
}

function DeleteFolderIfWithoutFiles {
    param(
        [string] $folderPath
    ) 

    # Удаление пустых подкаталогов
    if ((Get-ChildItem -Path $folderPath -Recurse -File | Measure-Object).Count -eq 0) {
        Remove-Item -Path $folderPath -Force -Recurse
        Write-Host " - delete empty folder: $folderPath"
    }
    else {
        Write-Host " - folder has files: $folderPath"
    }
}

# ------------------------------------------------------------------------------------
# - ОСНОВНОЙ СКРИПТ ------------------------------------------------------------------
# ------------------------------------------------------------------------------------

# Запрос порта с таймаутом
$port = $null
$timeout = 15
$timer = [System.Diagnostics.Stopwatch]::StartNew()

Write-Host "Введите порт (или нажмите Enter для продолжения):"
$inputTask = Start-Job -ScriptBlock {
    $portInput = Read-Host "Введите порт"
    return $portInput
}

while ($timer.Elapsed.TotalSeconds -lt $timeout) {
    if ($inputTask.HasExited) {
        $port = $inputTask.Receive()
        Stop-Job $inputTask
        break
    }
    Start-Sleep -Milliseconds 500
}

if ($port -eq $null) {
    Write-Host "Ввод не получен, продолжаем выполнение скрипта без изменения портов."
} else {
    Write-Host "Выбранный порт: $port"
}

$serviceRAS = Get-ServiceCommandLine -executableName "ras.exe"
foreach ($service in $serviceRAS) {
    $serviceName = $service.ServiceName
    Stop-Services -serviceName $serviceName
    Start-Sleep -Seconds $pauseDuration
}

$service1C = Get-ServiceCommandLine -executableName "ragent.exe"
foreach ($service in $service1C) {
    $serviceName = $service.ServiceName
    Stop-Services -serviceName $serviceName
    Start-Sleep -Seconds $pauseDuration
}

foreach ($service in $service1C) {
    $serviceWorkFolder = Get-StringFragment -inputString $service.PathToExecutable -regularExpression '-d "(.*?)"'

    # Чистим сеансовые данные служб 1С
    try {
        Clear-Folder -folderPath $serviceWorkFolder -target "snccntx*"
    }
    catch {
        Write-Host "error: $_"
        exit
    }

    # Чистим журнал
    try {
        Clear-Folder -folderPath $serviceWorkFolder -target "1Cv8Log"
    }
    catch {
        Write-Host "error: $_"
        exit
    }

    # Чистим журнал
    try {
        Clear-Folder -folderPath $serviceWorkFolder -target "1Cv8FTxt*"
    }
    catch {
        Write-Host "error: $_"
        exit
    }

    # Найдем каталоги по маске guid и зачистим если они пустые
    $guidPattern = '^[{(]?[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}[)}]?$'
    Get-ChildItem -Path $serviceWorkFolder -Directory -Recurse | Where-Object { $_.Name -match $guidPattern } | ForEach-Object {
        DeleteFolderIfWithoutFiles $_.FullName
    }
}

# Стартуем службы 1С
foreach ($service in $service1C) {
    $serviceName = $service.ServiceName
    Start-Services -serviceName $serviceName
    Start-Sleep -Seconds $pauseDuration
}

# Стартуем службы ras
foreach ($service in $serviceRAS) {
    $serviceName = $service.ServiceName
    Start-Services -serviceName $serviceName
}
