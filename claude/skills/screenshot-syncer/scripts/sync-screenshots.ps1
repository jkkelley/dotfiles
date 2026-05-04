#requires -Version 5.1
<#
.SYNOPSIS
    Copy Windows screenshots into a WSL directory with filtering.

.DESCRIPTION
    Selects matching files in a Windows source directory, then invokes
    `wsl.exe` to copy them from /mnt/c/... into the target WSL path. The
    actual cp executes inside the Linux filesystem to avoid the slower
    and occasionally unreliable \\wsl$\ UNC path.

    Configuration is read from environment variables (see -Source / -Distro /
    -Dest defaults) and any value can be overridden via CLI flags.

.PARAMETER Today
    Match files modified today (local time).

.PARAMETER All
    Match every file in the source directory.

.PARAMETER Name
    Match files whose name contains the substring (case-insensitive).

.PARAMETER Date
    Single date "YYYY-MM-DD" or inclusive range "YYYY-MM-DD..YYYY-MM-DD".

.PARAMETER Since
    Recency window: "<N><unit>" where unit is s, m, h, or d.
    Example: 30m, 2h, 1d.

.PARAMETER Source
    Windows source directory. Defaults to $env:SCREENSHOT_SYNC_SRC, then to
    $env:USERPROFILE\Pictures\Screenshots.

.PARAMETER Distro
    WSL distro name. Defaults to $env:SCREENSHOT_SYNC_DISTRO, then to the
    first distro returned by `wsl -l -q`.

.PARAMETER Dest
    WSL destination path. Defaults to $env:SCREENSHOT_SYNC_DEST. Required.

.PARAMETER DryRun
    Print what would be copied without actually copying.

.EXAMPLE
    .\sync-screenshots.ps1 -Today

.EXAMPLE
    .\sync-screenshots.ps1 -Date 2026-05-01..2026-05-03 -DryRun

.EXAMPLE
    .\sync-screenshots.ps1 -Name diagram
#>
[CmdletBinding(DefaultParameterSetName = 'Today')]
param(
    [Parameter(ParameterSetName = 'Today')]
    [switch]$Today,

    [Parameter(ParameterSetName = 'All')]
    [switch]$All,

    [Parameter(ParameterSetName = 'Name', Mandatory)]
    [string]$Name,

    [Parameter(ParameterSetName = 'Date', Mandatory)]
    [string]$Date,

    [Parameter(ParameterSetName = 'Since', Mandatory)]
    [string]$Since,

    [string]$Source,
    [string]$Distro,
    [string]$Dest,
    [switch]$DryRun
)

$ErrorActionPreference = 'Stop'

if (-not $Source) {
    $Source = if ($env:SCREENSHOT_SYNC_SRC) {
        $env:SCREENSHOT_SYNC_SRC
    } else {
        Join-Path $env:USERPROFILE 'Pictures\Screenshots'
    }
}
if (-not $Distro) { $Distro = $env:SCREENSHOT_SYNC_DISTRO }
if (-not $Dest)   { $Dest   = $env:SCREENSHOT_SYNC_DEST }

if (-not $Dest) {
    throw "Destination not set. Pass -Dest or set SCREENSHOT_SYNC_DEST (e.g. /home/<your-wsl-user>/<dest-dir>)."
}
if (-not (Test-Path -LiteralPath $Source)) {
    throw "Source directory not found: $Source"
}

function Resolve-Distro {
    param([string]$Hint)
    if ($Hint) { return $Hint }
    $raw = & wsl.exe -l -q 2>$null
    if ($LASTEXITCODE -ne 0) {
        throw "Failed to query WSL distros. Is WSL installed?"
    }
    $clean = ($raw -replace "`0", '').Trim() -split "`r?`n" | Where-Object { $_ }
    if (-not $clean) {
        throw "No WSL distros found. Install one or set SCREENSHOT_SYNC_DISTRO."
    }
    return $clean[0]
}

function Convert-ToWslPath {
    param([string]$WinPath)
    $full = (Resolve-Path -LiteralPath $WinPath).Path
    $drive = $full.Substring(0, 1).ToLower()
    $rest = $full.Substring(2) -replace '\\', '/'
    return "/mnt/$drive$rest"
}

$resolvedDistro = Resolve-Distro -Hint $Distro

$now = Get-Date
$startOfToday = (Get-Date).Date

$files = switch ($PSCmdlet.ParameterSetName) {
    'Today' {
        Get-ChildItem -LiteralPath $Source -File |
            Where-Object { $_.LastWriteTime -ge $startOfToday }
    }
    'All' {
        Get-ChildItem -LiteralPath $Source -File
    }
    'Name' {
        $needle = $Name.ToLowerInvariant()
        Get-ChildItem -LiteralPath $Source -File |
            Where-Object { $_.Name.ToLowerInvariant().Contains($needle) }
    }
    'Date' {
        if ($Date -match '^\s*(\d{4}-\d{2}-\d{2})\s*\.\.\s*(\d{4}-\d{2}-\d{2})\s*$') {
            $from = [datetime]::ParseExact($Matches[1], 'yyyy-MM-dd', $null)
            $to   = [datetime]::ParseExact($Matches[2], 'yyyy-MM-dd', $null).AddDays(1)
        } elseif ($Date -match '^\s*(\d{4}-\d{2}-\d{2})\s*$') {
            $from = [datetime]::ParseExact($Matches[1], 'yyyy-MM-dd', $null)
            $to   = $from.AddDays(1)
        } else {
            throw "Invalid -Date. Use YYYY-MM-DD or YYYY-MM-DD..YYYY-MM-DD."
        }
        Get-ChildItem -LiteralPath $Source -File |
            Where-Object { $_.LastWriteTime -ge $from -and $_.LastWriteTime -lt $to }
    }
    'Since' {
        if ($Since -notmatch '^\s*(\d+)\s*([smhdSMHD])\s*$') {
            throw "Invalid -Since. Use durations like 30m, 2h, 1d."
        }
        $n = [int]$Matches[1]
        $cutoff = switch ($Matches[2].ToLower()) {
            's' { $now.AddSeconds(-$n) }
            'm' { $now.AddMinutes(-$n) }
            'h' { $now.AddHours(-$n)   }
            'd' { $now.AddDays(-$n)    }
        }
        Get-ChildItem -LiteralPath $Source -File |
            Where-Object { $_.LastWriteTime -ge $cutoff }
    }
}

$files = @($files | Sort-Object Name)

if (-not $files -or $files.Count -eq 0) {
    Write-Host "No files matched in $Source." -ForegroundColor Yellow
    return
}

if ($DryRun) {
    Write-Host ("[dry-run] {0} file(s) would copy to {1}:{2}" -f $files.Count, $resolvedDistro, $Dest) -ForegroundColor Cyan
    foreach ($f in $files) {
        Write-Host "  $($f.Name)  ($([math]::Round($f.Length / 1KB)) KB, $($f.LastWriteTime))"
    }
    return
}

# Ensure destination exists inside WSL
& wsl.exe -d $resolvedDistro -- mkdir -p -- "$Dest" | Out-Null
if ($LASTEXITCODE -ne 0) {
    throw "Failed to create destination $Dest in distro $resolvedDistro."
}

# Build the source list as WSL paths and copy in a single cp call
$wslSources = @($files | ForEach-Object { Convert-ToWslPath $_.FullName })
$cpArgs = @('-d', $resolvedDistro, '--', 'cp', '-f', '--') + $wslSources + @("$Dest/")

& wsl.exe @cpArgs
if ($LASTEXITCODE -ne 0) {
    throw "cp failed with exit code $LASTEXITCODE."
}

Write-Host ("Synced {0} file(s) to {1}:{2}" -f $files.Count, $resolvedDistro, $Dest) -ForegroundColor Green
