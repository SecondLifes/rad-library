<#
.SYNOPSIS
  Registers this kit in the machine-wide .rad registry so other kits can
  resolve it by name instead of by hardcoded path.

.DESCRIPTION
  Writes this kit's real location into the shared registry at
  %ProgramData%\rad\registry.json. Another kit that declares

      "references": [ { "kit": "<this kit's name>", "paths": [ ... ] } ]

  in its own settings.json resolves that name through this registry and
  reads the CURRENT content — no copies, no drift.

  Deliberately standalone: it duplicates a little logic from the
  workspace's tools/rad.ps1 on purpose, because a kit is cloned into
  arbitrary projects where that workspace does not exist. This script must
  work with nothing but the kit itself.

  No elevation required. The first run creates %ProgramData%\rad and grants
  BUILTIN\Users:Modify on it — whoever creates the folder owns it via
  CREATOR OWNER inheritance, and that includes the right to set the ACL.
  Without that grant, ProgramData's default permissions let user A create
  registry.json and then silently deny user B write access to it.

.PARAMETER Name
  Registry name for this kit. Defaults to the kit folder's own name.

.PARAMETER Unregister
  Remove this kit's entry instead of adding it.

.EXAMPLE
  pwsh tools/rad-register.ps1
  pwsh tools/rad-register.ps1 -Name erp-muhasebe-temel
  pwsh tools/rad-register.ps1 -Unregister
#>
param(
    [string]$Name,
    [switch]$Unregister
)

$ErrorActionPreference = 'Stop'

$KitRoot = Split-Path -Parent $PSScriptRoot
if (-not $Name) { $Name = Split-Path -Leaf $KitRoot }

$SystemRoot = if ($IsWindows -or $env:OS -eq 'Windows_NT') {
    Join-Path $env:ProgramData 'rad'
} else {
    '/usr/local/share/rad'
}
$RegistryFile = Join-Path $SystemRoot 'registry.json'

function Grant-SharedAccess {
    param([string]$Path)
    if (-not ($IsWindows -or $env:OS -eq 'Windows_NT')) { return }
    try {
        # Well-known SID, not the literal name "BUILTIN\Users" — the display
        # name is localized and would not match on a non-English Windows.
        $usersSid = [System.Security.Principal.SecurityIdentifier]::new(
            [System.Security.Principal.WellKnownSidType]::BuiltinUsersSid, $null)
        $acl = Get-Acl -Path $Path
        $rule = [System.Security.AccessControl.FileSystemAccessRule]::new(
            $usersSid,
            [System.Security.AccessControl.FileSystemRights]::Modify,
            ([System.Security.AccessControl.InheritanceFlags]::ContainerInherit -bor
             [System.Security.AccessControl.InheritanceFlags]::ObjectInherit),
            [System.Security.AccessControl.PropagationFlags]::None,
            [System.Security.AccessControl.AccessControlType]::Allow)
        $acl.AddAccessRule($rule)
        Set-Acl -Path $Path -AclObject $acl
    } catch {
        Write-Warning "could not set shared ACL on $Path — other users may not be able to write here. ($($_.Exception.Message))"
    }
}

if (-not (Test-Path $SystemRoot)) {
    if ($Unregister) {
        Write-Host "System root does not exist ($SystemRoot) — nothing to unregister." -ForegroundColor Yellow
        return
    }
    New-Item -ItemType Directory -Force $SystemRoot | Out-Null
    Grant-SharedAccess $SystemRoot
    Write-Host "Created system root: $SystemRoot" -ForegroundColor Green
}

# Serialized read-modify-write. Without the lock, two kits registering at
# the same moment both read the old registry and the slower writer silently
# drops the faster one's entry.
$lockPath = "$RegistryFile.lock"
$deadline = (Get-Date).AddSeconds(15)
$lock = $null
while (-not $lock) {
    try {
        $lock = [System.IO.File]::Open($lockPath, 'OpenOrCreate', 'ReadWrite', 'None')
    } catch {
        if ((Get-Date) -gt $deadline) {
            throw "registry lock timed out ($lockPath). If no other rad process is running, delete that file."
        }
        Start-Sleep -Milliseconds 200
    }
}

try {
    $reg = if (Test-Path $RegistryFile) {
        Get-Content $RegistryFile -Raw | ConvertFrom-Json -AsHashtable
    } else {
        @{ schema_version = 1; shared = @{}; workspaces = @{}; kits = @{} }
    }
    if (-not $reg['kits']) { $reg['kits'] = @{} }

    if ($Unregister) {
        if ($reg['kits'].ContainsKey($Name)) {
            $reg['kits'].Remove($Name)
            Write-Host "Unregistered: $Name" -ForegroundColor Yellow
        } else {
            Write-Host "Not registered, nothing to do: $Name" -ForegroundColor DarkGray
        }
    } else {
        $previous = if ($reg['kits'].ContainsKey($Name)) { $reg['kits'][$Name].path } else { $null }
        if ($previous -and $previous -ne $KitRoot) {
            Write-Host "Re-pointing '$Name':" -ForegroundColor Yellow
            Write-Host "  was: $previous" -ForegroundColor DarkGray
            Write-Host "  now: $KitRoot" -ForegroundColor Green
        }
        $reg['kits'][$Name] = @{
            path          = $KitRoot
            registered_at = (Get-Date -Format 'yyyy-MM-dd HH:mm')
            registered_by = $env:USERNAME
            machine       = $env:COMPUTERNAME
        }
        Write-Host "Registered: $Name -> $KitRoot" -ForegroundColor Green
    }

    $reg['schema_version'] = 1
    $reg['updated']    = (Get-Date -Format 'yyyy-MM-dd HH:mm')
    $reg['updated_by'] = "$env:USERNAME@$env:COMPUTERNAME"

    # temp + rename: atomic on NTFS, so a concurrent reader never sees a
    # half-written file and a crash leaves the previous version intact.
    $tmp = "$RegistryFile.tmp.$PID"
    ($reg | ConvertTo-Json -Depth 10) | Set-Content -Path $tmp -Encoding UTF8
    Move-Item -Path $tmp -Destination $RegistryFile -Force
} finally {
    $lock.Close()
    Remove-Item $lockPath -Force -ErrorAction SilentlyContinue
}

Write-Host ""
Write-Host "Registry: $RegistryFile" -ForegroundColor Cyan
$final = Get-Content $RegistryFile -Raw | ConvertFrom-Json
Write-Host "Kits now registered: $(($final.kits.PSObject.Properties.Name) -join ', ')" -ForegroundColor Cyan
