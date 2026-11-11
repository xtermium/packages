$ErrorActionPreference = 'Stop'

$packageArgs = @{
  packageName    = $env:ChocolateyPackageName
  fileType       = 'msi'
  url64bit       = 'https://github.com/xtermium/xtermium/releases/download/v0.9.0/xtermium_0.9.0_x64_en-US.msi'
  checksum64     = '95a2c786bf25b5944fd1d90f34a2208d8b16f7cc2036cd87973165e8ea97275d'
  checksumType64 = 'sha256'
  silentArgs     = "/qn /norestart /l*v `"$($env:TEMP)\$($env:ChocolateyPackageName).$($env:ChocolateyPackageVersion).MsiInstall.log`""
  validExitCodes = @(0, 3010, 1641)
}

Install-ChocolateyPackage @packageArgs
