<#
.SYNOPSIS
  Choose and record how this machine talks to Perplexity. Windows equivalent of
  pplx-setup.sh, for machines with no bash.

.EXAMPLE
  .\pplx-setup.ps1                  # report what is available here, change nothing
  .\pplx-setup.ps1 -Path browser    # record the browser path
  .\pplx-setup.ps1 -Doctor          # check the recorded path

.NOTES
  On Windows and Linux the browser path is the only one that works: the desktop
  path drives the macOS app through the macOS accessibility API. Nothing here
  needs an API key, and nothing here can spend money.

  Works on Windows PowerShell 5.1 (the one shipped with Windows) as well as
  PowerShell 7+: the $IsWindows/$IsMacOS variables do not exist on 5.1, so the
  checks fall back to $env:OS, and the config is written without a byte-order
  mark so the bash scripts can read the same file.
#>
[CmdletBinding()]
param(
  [ValidateSet('app', 'browser')]
  [string]$Path,
  [switch]$Doctor
)

$ErrorActionPreference = 'Stop'

# Same location the bash script uses, so both agree on one machine. The bash
# scripts honour XDG_CONFIG_HOME, so this must too: on a Linux or WSL box that
# sets it, writing to $HOME/.config would leave a config the bash side never reads.
$ConfigBase = if ($env:XDG_CONFIG_HOME) { $env:XDG_CONFIG_HOME } else { Join-Path $HOME '.config' }
$ConfigDir = Join-Path $ConfigBase 'perplexity-research-skill'
$ConfigFile = Join-Path $ConfigDir 'config'

function Get-RecordedPath {
  if (Test-Path $ConfigFile) {
    $line = Select-String -Path $ConfigFile -Pattern '^path=' -ErrorAction SilentlyContinue
    if ($line) { return ($line.Line -replace '^path=', '') }
  }
  return $null
}

function Write-Report {
  $os = if ($IsWindows -or $env:OS -eq 'Windows_NT') { 'Windows' }
        elseif ($IsMacOS) { 'macOS' }
        elseif ($IsLinux) { 'Linux' }
        else { 'unrecognised' }

  Write-Host "Platform:        $os"
  if ($os -eq 'macOS') {
    Write-Host "Paths:           app and browser both available"
    Write-Host "Recommended:     app  (use pplx-setup.sh on macOS, it can install the helper)"
  } else {
    Write-Host "Paths:           browser only - the app path drives the macOS desktop app"
    Write-Host "Recommended:     browser  (the only path here; say so rather than asking)"
  }

  $recorded = Get-RecordedPath
  if ($recorded) { Write-Host "Recorded path:   $recorded" }
  else { Write-Host "Recorded path:   none yet - run with -Path browser" }
}

function Write-Config([string]$Choice) {
  if (-not (Test-Path $ConfigDir)) { New-Item -ItemType Directory -Path $ConfigDir -Force | Out-Null }
  # Write LF, not CRLF: the bash scripts read this same file, and a trailing
  # carriage return would make 'browser' parse as 'browser<CR>' and match nothing.
  $text = "# written by pplx-setup.ps1 - safe to edit or delete`npath=$Choice`n"
  [System.IO.File]::WriteAllText($ConfigFile, $text, (New-Object System.Text.ASCIIEncoding))
  Write-Host "Recorded: path=$Choice  ->  $ConfigFile"
}

if ($Doctor) {
  Write-Report
  Write-Host ''
  $recorded = Get-RecordedPath
  if ($recorded -eq 'browser') {
    Write-Host 'INFO  browser path: this script cannot test it, because the browser is driven'
    Write-Host '      by the agent''s own automation. Check it by opening perplexity.ai in a new'
    Write-Host '      tab and confirming the composer is in Search mode before the first ask.'
  } elseif ($recorded -eq 'app') {
    Write-Host 'FAIL  the app path is recorded but cannot run off macOS. Re-run with -Path browser.'
    exit 1
  } else {
    Write-Host 'INFO  no path recorded yet - run with -Path browser'
  }
  exit 0
}

if ($Path) {
  if ($Path -eq 'app' -and -not $IsMacOS) {
    Write-Host 'The app path cannot run on this platform: it drives the macOS desktop app'
    Write-Host 'through the macOS accessibility API. Use: .\pplx-setup.ps1 -Path browser'
    exit 1
  }
  Write-Config $Path
  exit 0
}

Write-Report
