$ErrorActionPreference = 'Stop'

$packageArgs = @{
  packageName    = $env:ChocolateyPackageName
  fileType       = 'msi'
  url64bit       = 'https://github.com/xtermium/xtermium/releases/download/v0.10.0/xtermium_0.10.0_x64_en-US.msi'
  checksum64     = '6153fa018d2a29e3b0e1d9205e64998ce203c9ebeceac8451a7804a94dc84403'
  checksumType64 = 'sha256'
  silentArgs     = "/qn /norestart /l*v `"$($env:TEMP)\$($env:ChocolateyPackageName).$($env:ChocolateyPackageVersion).MsiInstall.log`""
  validExitCodes = @(0, 3010, 1641)
}

Install-ChocolateyPackage @packageArgs
