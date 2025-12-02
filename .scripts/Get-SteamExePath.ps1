# Get the installation path of Steam from the registry and return the full path to steam.exe
# @Author: Khazul
$path = Get-ItemPropertyValue -Path "HKCU:\Software\Valve\Steam" -Name "SteamPath"
$exePath = Join-Path -Path $path -ChildPath "steam.exe"
if (Test-Path $exePath) {
    Write-Output "$exePath"
}
