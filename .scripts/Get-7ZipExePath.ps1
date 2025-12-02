# Get the installation path of 7-Zip from the registry and return the full path to 7z.exe
# @Author: Khazul
$path = Get-ItemPropertyValue -Path "HKCU:\Software\7-Zip" -Name "Path"
$exePath = Join-Path -Path $path -ChildPath "7z.exe"
if (Test-Path $exePath) {
    Write-Output "$exePath"
}
