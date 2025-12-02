@echo on
@rem Batch script to package mod, deploy mod, and run Enshrouded or emm.exe
@rem @Author: Khazul

@set deployZip=false
@set steamAppId=1203620

@set %action=%1
if "%action%"=="" set action=export

@rem Get the mod name from the parent folder
for /f "delims=" %%a in ('powershell -Command "(get-item '%~f0').Directory.Parent.Name"') do @set name=%%a
@rem Get the mod version from the mod.json file
for /f "delims=" %%a in ('powershell -Command "$file='%~dp0\..\mod.json'; $json = (Get-Content $file -Raw) | ConvertFrom-Json; $json.version;"') do @set version=%%a

@rem Prepare output folder
rmdir /S /Q "%~dp0\..\.output"
mkdir "%~dp0\..\.output\%name%"

@rem Copy necessary files to output folder
xcopy /E /I /Y /Q "%~dp0\..\src\*" "%~dp0\..\.output\%name%\src"
copy /Y "%~dp0\..\mod.json" "%~dp0\..\.output\%name%\mod.json"
copy /Y "%~dp0\..\README.MD" "%~dp0\..\.output\%name%\README.MD"

@rem Create the zip file if 7zip is available
@rem Get the path to 7-Zip executable
del /F /Q "%~dp0\..\.output\%name%-%version%.zip"
for /f "delims=" %%a in ('powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0\Get-7ZipExePath.ps1"') do @set "sevenZipExePath=%%a"
if "%sevenZipExePath%"=="" (
    @echo "7-Zip executable not found. Please ensure 7-Zip is installed."
) else (
    @rem uses 7zip as works with factorio whereas compress does not
    "%sevenZipExePath%" a -tzip -bb0 -bso0 -bsp0 -y -aoa -o"%~dp0\..\.output" "%~dp0\..\.output\%name%-%version%.zip" "%~dp0\..\.output\%name%\*"
    @set deployZip=true
)

@rem Get mod capabilities
for /f "delims=" %%A in ('powershell -NoProfile -Command "$j = Get-Content '%~dp0\..\mod.json' | ConvertFrom-Json; $c = $j.capabilities; if ($null -eq $c) { '' } else { ($c | Sort-Object) -join ' ' }"') do set "modCapabilities=%%A"

@rem Deploy to game mods folder
@rem Get the Steam game path
for /f "delims=" %%a in ('powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0\Get-SteamGamePath.ps1" -AppID %steamAppId%') do @set "steamGamePath=%%a"
rmdir /S /Q "%steamGamePath%\Mods\%name%"
del /F /Q "%steamGamePath%\Mods\%name%-*.zip"

if "%deployZip%" == "true" (
    @rem Deploy the zip file
    copy /Y "%~dp0\..\.output\%name%-%version%.zip" "%steamGamePath%\Mods"
) else (
    @rem Deploy the unzipped mod folder
    xcopy /E /I /Y "%~dp0\..\.output\%name%" "%steamGamePath%\Mods\%name%"
)

@rem Run command - start enshroud with mod
if "%action%"=="run" (
    for /f "delims=" %%a in ('powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0\Get-SteamExePath.ps1"') do @set "steamExePath=%%a"
    @echo start "" "%steamExePath%" -applaunch %steamAppId%
    goto :eof
)
@rem export and patching commands - run emm.exe
set "emm=%~dp0\emm.exe"
set "emmexports=%~dp0\..\.exports"
if "%action%"=="export" (
    rmdir /S /Q "%emmexports%"
    mkdir "%emmexports%"
    "%emm%" run -e -g "%steamGamePath%" --export-directory "%emmexports%" --file-name "enshrouded"
    rmdir /S /Q "%steamGamePath%\Mods\%name%"
    del /F /Q "%steamGamePath%\Mods\%name%-*.zip"
    goto :eof
)
if "%action%"=="patch" (
    "%emm%" run -p -g "%steamGamePath%" --export-directory "%emmexports%" --file-name "enshrouded"
    rmdir /S /Q "%steamGamePath%\Mods\%name%"
    del /F /Q "%steamGamePath%\Mods\%name%-*.zip"
    goto :eof
)
