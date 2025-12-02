# Get the installation path of a Steam game by its AppID
# @Author: Khazul
param(
    [Parameter(Mandatory=$true)]
    [string]$AppID
)

$steamPath = Get-ItemPropertyValue -Path "HKCU:\Software\Valve\Steam" -Name "SteamPath"
$vdfPath = Join-Path -Path $steamPath -ChildPath "steamapps\libraryfolders.vdf"
if (-Not (Test-Path $vdfPath)) {
    exit
}

$libraries = @{}
$current = ""

foreach ($line in Get-Content $vdfPath) {
    if ($line -match '"(\d+)"\s*\{') { $current = $matches[1] }
    if ($line -match '"path"\s*"(.+)"') { $libraries[$current] = $matches[1] }
}

foreach ($lib in $libraries.Values) {
    $manifest = Join-Path "$lib\steamapps" "appmanifest_$AppID.acf"
    if (Test-Path $manifest) {
        $installdir = Select-String -Path $manifest -Pattern '"installdir"\s*"(.+)"' |
                      ForEach-Object { $_.Matches.Groups[1].Value }
        if ($installdir) {
            $installPath = Join-Path "$lib\steamapps\common" $installdir
            Write-Output "$installPath"
            exit
        }
    }
}
