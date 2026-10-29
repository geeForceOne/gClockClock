# Installs or updates the gClockClock wallpaper for Lively Wallpaper (Windows).
#
#   powershell -ExecutionPolicy Bypass -File lively-setup.ps1
#   or: irm https://raw.githubusercontent.com/geeForceOne/gClockClock/main/lively-setup.ps1 | iex
#
# Already installed: replaces the package files in Lively's library with the latest version from
# GitHub (pictures you added to its images folder stay) and carries your Customize values over to
# the new settings file, so new settings appear with their defaults. Lively has to be closed for
# that; the script closes it and starts it again.
# Not installed yet: builds gClockClock-lively.zip in Downloads; drag it onto the Lively window
# once. Updates then go through this script.
#
# Options: -Source <folder> uses a local copy of the repo instead of downloading,
#          -Branch <name> downloads another branch, -Yes skips the question before closing Lively.
# Works with Windows PowerShell 5.1 and PowerShell 7.

param(
  [string]$Source,
  [string]$Branch = 'main',
  [switch]$Yes
)

$ErrorActionPreference = 'Stop'
$Repo = 'geeForceOne/gClockClock'
$Contact = "https://github.com/$Repo" # the Contact field in LivelyInfo.json marks our wallpaper
$Utf8 = New-Object System.Text.UTF8Encoding $false
Add-Type -AssemblyName System.IO.Compression.FileSystem

# ---- the package: wallpaper\ plus clock.html ----
$work = Join-Path ([IO.Path]::GetTempPath()) ("gclock-lively-" + [Guid]::NewGuid().ToString('N').Substring(0, 8))
New-Item -ItemType Directory $work | Out-Null
try {
  if ($Source) {
    $src = (Resolve-Path $Source).Path
    Write-Host "Using the local copy in $src"
  } else {
    $zip = Join-Path $work 'repo.zip'
    Write-Host "Downloading the latest version ($Branch) from GitHub..."
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    Invoke-WebRequest "https://github.com/$Repo/archive/refs/heads/$Branch.zip" -OutFile $zip -UseBasicParsing
    [IO.Compression.ZipFile]::ExtractToDirectory($zip, (Join-Path $work 'repo'))
    $src = (Get-ChildItem (Join-Path $work 'repo') -Directory | Select-Object -First 1).FullName
  }
  $package = Join-Path $work 'package'
  Copy-Item (Join-Path $src 'wallpaper') $package -Recurse
  Copy-Item (Join-Path $src 'clock.html') $package

  # ---- Lively's wallpaper libraries ----
  # Classic installer: %LocalAppData%\Lively Wallpaper. Microsoft Store version: the same under
  # its package's LocalCache\Local (Windows redirects it there). The library folder can be moved
  # in Lively's settings (WallpaperDir in Settings.json).
  $roots = @(Join-Path $env:LOCALAPPDATA 'Lively Wallpaper')
  $storeRoots = @(Get-ChildItem (Join-Path $env:LOCALAPPDATA 'Packages') -Directory -Filter '*LivelyWallpaper*' -ErrorAction SilentlyContinue |
    ForEach-Object { Join-Path $_.FullName 'LocalCache\Local\Lively Wallpaper' })
  $roots += $storeRoots
  $libraries = @()
  foreach ($root in $roots) {
    if (-not (Test-Path $root)) { continue }
    $dirs = @(Join-Path $root 'Library')
    $settingsFile = Join-Path $root 'Settings.json'
    if (Test-Path $settingsFile) {
      $dir = ([IO.File]::ReadAllText($settingsFile) | ConvertFrom-Json).WallpaperDir
      if ($dir) {
        $dirs += $dir
        # the Store version stores the path as the app sees it; on disk it's redirected
        if ($storeRoots -contains $root -and $dir.StartsWith($env:LOCALAPPDATA, 'OrdinalIgnoreCase')) {
          $dirs += (Split-Path $root -Parent) + $dir.Substring($env:LOCALAPPDATA.Length)
        }
      }
    }
    foreach ($d in $dirs) {
      if ((Test-Path (Join-Path $d 'wallpapers')) -and ($libraries -notcontains $d)) { $libraries += $d }
    }
  }

  $installed = @()
  foreach ($lib in $libraries) {
    foreach ($folder in Get-ChildItem (Join-Path $lib 'wallpapers') -Directory) {
      $info = Join-Path $folder.FullName 'LivelyInfo.json'
      if ((Test-Path $info) -and (([IO.File]::ReadAllText($info) | ConvertFrom-Json).Contact -eq $Contact)) {
        $installed += [pscustomobject]@{ Library = $lib; Folder = $folder.FullName; Name = $folder.Name }
      }
    }
  }

  # ---- not installed: a zip to drag onto Lively ----
  if ($installed.Count -eq 0) {
    $downloads = Join-Path $env:USERPROFILE 'Downloads'
    $out = Join-Path $downloads 'gClockClock-lively.zip'
    if (Test-Path $out) { Remove-Item $out }
    [IO.Compression.ZipFile]::CreateFromDirectory($package, $out)
    Write-Host ""
    Write-Host "gClockClock isn't installed in Lively yet. Created:"
    Write-Host "  $out"
    Write-Host "Drag that file onto the Lively window to install it. Run this script again for updates."
    Start-Process explorer.exe "/select,`"$out`""
    return
  }

  # ---- Lively has to be closed while its files change ----
  $lively = @(Get-Process Lively -ErrorAction SilentlyContinue)
  $restart = $null
  if ($lively.Count -gt 0) {
    if (-not $Yes) {
      $answer = Read-Host "Lively is running and has to be closed for the update; it starts again afterwards. Continue? [Y/n]"
      if ($answer -and $answer -notmatch '^[yYjJ]') { Write-Host "Nothing changed."; return }
    }
    $app = Get-AppxPackage '*LivelyWallpaper*' -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($app -and $lively[0].Path -like "$($app.InstallLocation)*") {
      $appId = @((Get-AppxPackageManifest $app).Package.Applications.Application)[0].Id
      $restart = "shell:AppsFolder\$($app.PackageFamilyName)!$appId"
    } else {
      $restart = $lively[0].Path
    }
    # Lively plus its helpers (Lively.Watchdog, Lively.Player.*), which show the wallpapers
    $all = @(Get-Process -Name 'Lively*' -ErrorAction SilentlyContinue)
    $all | Stop-Process -Force -ErrorAction SilentlyContinue
    $all | ForEach-Object { $_.WaitForExit(10000) | Out-Null }
  }

  # ---- update: package files, then the saved Customize values ----
  $newProps = [IO.File]::ReadAllText((Join-Path $package 'LivelyProperties.json'))
  # dropdown items renamed since older versions: old name -> new name (en dash as a char code, so
  # Windows PowerShell 5.1 reads this file right without a BOM)
  $dash = [char]0x2013
  $renamed = @{ 'Every 5 min' = "Every 10${dash}20 min"; 'Every hour' = "Every 40${dash}60 min" }
  foreach ($w in $installed) {
    Write-Host "Updating $($w.Folder)"
    Copy-Item (Join-Path $package '*') $w.Folder -Recurse -Force

    # Lively keeps the values you set in a copy of LivelyProperties.json per screen (and layout).
    # Start from the new file and take over every value whose setting still exists; dropdowns are
    # matched by item name, since items may have been added or reordered.
    $saved = Join-Path $w.Library "SaveData\wpdata\$($w.Name)"
    if (-not (Test-Path $saved)) { continue }
    foreach ($file in Get-ChildItem $saved -Recurse -Filter 'LivelyProperties.json') {
      $old = [IO.File]::ReadAllText($file.FullName) | ConvertFrom-Json
      $new = $newProps | ConvertFrom-Json
      foreach ($p in $new.PSObject.Properties) {
        $o = $old.PSObject.Properties[$p.Name]
        if (-not $o -or $o.Value.type -ne $p.Value.type) { continue }
        $n = $p.Value; $v = $o.Value
        switch ($n.type) {
          'label' { }
          'button' { }
          'dropdown' {
            $items = @($v.items)
            if ($v.value -ge 0 -and $v.value -lt $items.Count) {
              $name = $items[[int]$v.value]
              if ($renamed.ContainsKey($name)) { $name = $renamed[$name] }
              $i = [array]::IndexOf(@($n.items), $name)
              if ($i -ge 0) { $n.value = $i }
            }
          }
          'slider' { $n.value = [math]::Min([math]::Max($v.value, $n.min), $n.max) }
          default { $n.value = $v.value }
        }
      }
      Copy-Item $file.FullName ($file.FullName + '.bak') -Force
      [IO.File]::WriteAllText($file.FullName, ($new | ConvertTo-Json -Depth 5), $Utf8)
      Write-Host "  kept your settings in $($file.FullName)"
    }
  }

  if ($restart) {
    Write-Host "Starting Lively again..."
    Start-Process $restart
  }
  Write-Host "Done."
} finally {
  Remove-Item $work -Recurse -Force -ErrorAction SilentlyContinue
}
