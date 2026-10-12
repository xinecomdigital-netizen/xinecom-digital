# XineCom Diagnostic FREE v1.0.1
# Diagnostico local de solo lectura para Windows 10/11.
# No envia informacion por Internet ni cambia configuraciones.

$ErrorActionPreference = 'Stop'

function Get-SafeValue {
    param([scriptblock]$Action, [string]$Fallback = 'No disponible')
    try {
        $value = & $Action
        if ($null -eq $value -or "$value".Trim() -eq '') { return $Fallback }
        return $value
    } catch { return $Fallback }
}

function Format-GB {
    param([double]$Bytes)
    return ('{0:N1} GB' -f ($Bytes / 1GB))
}

$lines = New-Object System.Collections.Generic.List[string]
$lines.Add('=================================================')
$lines.Add('         XineCom Diagnostic FREE v1.0.1')
$lines.Add('         Tu tecnologia. Mas simple.')
$lines.Add('=================================================')
$lines.Add(('Fecha: {0}' -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss')))
$lines.Add('')

$lines.Add('[ SISTEMA OPERATIVO ]')
$os = Get-SafeValue { Get-CimInstance Win32_OperatingSystem }
if ($os -is [string]) {
    $lines.Add('Sistema: No disponible')
} else {
    $lines.Add(('Sistema: {0}' -f $os.Caption))
    $lines.Add(('Version: {0}' -f $os.Version))
    $lines.Add(('Compilacion: {0}' -f $os.BuildNumber))
}
$lines.Add('')

$lines.Add('[ PROCESADOR ]')
$cpus = Get-SafeValue { @(Get-CimInstance Win32_Processor) }
if ($cpus -is [string]) {
    $lines.Add('Procesador: No disponible')
} else {
    foreach ($cpu in $cpus) {
        $lines.Add(('Modelo: {0}' -f $cpu.Name.Trim()))
        $lines.Add(('Nucleos: {0} | Procesadores logicos: {1}' -f $cpu.NumberOfCores, $cpu.NumberOfLogicalProcessors))
    }
}
$lines.Add('')

$lines.Add('[ MEMORIA RAM ]')
$memory = Get-SafeValue { Get-CimInstance Win32_ComputerSystem }
if ($memory -is [string]) {
    $lines.Add('RAM instalada: No disponible')
} else {
    $lines.Add(('RAM instalada: {0}' -f (Format-GB $memory.TotalPhysicalMemory)))
}
$lines.Add('')

$lines.Add('[ ALMACENAMIENTO ]')
$drives = Get-SafeValue { @(Get-CimInstance Win32_LogicalDisk -Filter 'DriveType=3') }
if ($drives -is [string] -or @($drives).Count -eq 0) {
    $lines.Add('Unidades: No disponible')
} else {
    foreach ($drive in $drives) {
        if ($null -eq $drive.Size -or $drive.Size -le 0) { continue }
        $freePct = [math]::Round(($drive.FreeSpace / $drive.Size) * 100, 1)
        $lines.Add(('Unidad {0} - Total {1} | Libre {2} ({3}%)' -f $drive.DeviceID, (Format-GB $drive.Size), (Format-GB $drive.FreeSpace), $freePct))
        if ($freePct -lt 15) {
            $lines.Add('  Aviso: menos de 15% de espacio libre. Revisar almacenamiento.')
        }
    }
}
$lines.Add('')

$lines.Add('[ RED - RESUMEN SIN DATOS PERSONALES ]')
$adapters = Get-SafeValue { @(Get-CimInstance Win32_NetworkAdapter -Filter 'PhysicalAdapter=True' | Where-Object { $_.NetEnabled -eq $true }) }
if ($adapters -is [string]) {
    $lines.Add('Adaptadores activos: No disponible')
} else {
    $lines.Add(('Adaptadores fisicos activos: {0}' -f @($adapters).Count))
    $lines.Add('No se incluyen direcciones IP, MAC, DNS ni nombres de redes.')
}
$lines.Add('')
$lines.Add('Este informe es orientativo y no reemplaza un diagnostico tecnico completo.')
$lines.Add('XineCom Digital | Tu tecnologia. Mas simple.')

try {
    $desktop = [Environment]::GetFolderPath('Desktop')
    if ([string]::IsNullOrWhiteSpace($desktop) -or -not (Test-Path -LiteralPath $desktop)) {
        $desktop = [Environment]::GetFolderPath('MyDocuments')
    }
    $file = Join-Path $desktop ('XineCom-Diagnostic-{0}.txt' -f (Get-Date -Format 'yyyyMMdd-HHmmss'))
    $lines | Out-File -LiteralPath $file -Encoding UTF8
    $lines | ForEach-Object { Write-Host $_ }
    Write-Host ''
    Write-Host ('Informe guardado en: {0}' -f $file) -ForegroundColor Green
} catch {
    Write-Host 'No se pudo guardar el informe. Revisa los permisos de la carpeta de destino.' -ForegroundColor Yellow
    $lines | ForEach-Object { Write-Host $_ }
}
