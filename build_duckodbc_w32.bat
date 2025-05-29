@echo off
setlocal EnableDelayedExpansion

REM SET __DEBUGECHO=ECHO
IF NOT DEFINED __DEBUGECHO (SET __DEBUGECHO=REM)

set "arg1="
call set "arg1=%%1"
set bit=64
set "ARCH=amd64"
set "CLARG="

REM setup Visual Studio
CALL :fn_ConfigVisualStudio

REM report the compiler architecture as a check
CALL :fn_GetCompilerArch

if defined arg1 (
    goto :arg_exists
) else (
    REM default for no argument is build
    goto :switch-case-N-build
)
    
:arg_exists

REM now choose debug/release/install/clean
:switch-case-example
goto :switch-case-N-%arg1% 2>nul || (
    echo %arg1% is not a valid command
    goto :switch-case-end
)
goto :switch-case-end

:switch-case-N-build
	if not exist ".\build" ( mkdir ".\build")
	cd .\build
    REM cmake -S ..\.. -B . -G Ninja ^
    cmake -S ..\ -B . -DCMAKE_GENERATOR_PLATFORM=x64 
    cd ..
    goto :switch-case-end
    
:switch-case-N-clean
    echo clean
    rmdir /S /Q .\build 2>NUL
    goto :switch-case-end

REM ***************************************************
:switch-case-N-install
    REM I think duckdb installer does admin correctly, but just in case we run in PS
    REM copy to system drive as admin cannot install from mapped drive
    set REL_PATH=.\build\release
    set ABS_PATH=
    pushd %REL_PATH%
    set ABS_PATH=%CD%
    popd    
    if exist ".\build\release" (
        echo installing as admin from .\build\release to %appdata%\duckdb
        if exist %appdata%\duckdb (rmdir /S /Q %appdata%\duckdb)
        mkdir %appdata%\duckdb
        REM build from release
        call COPY .\build\release\tools\odbc\bin\* %appdata%\duckdb > NUL
        REM pause to ensure copy finishes
        timeout /t 1 > NUL
        REM uninstall and then install to ensure pointing to file we 
        REM just copied to folder and not somewhere else...
        REM silent version
        Powershell Start cmd.exe -ArgumentList "/c","cd",%appdata%\duckdb,"'&'","odbc_install.exe","/CI", "/Uninstall","'&'","odbc_install.exe","/CI","/Install" -Verb Runas -Wait
        REM non-silent version
        REM Powershell Start cmd.exe -ArgumentList "/c","cd",%appdata%\duckdb,"'&'","odbc_install.exe","/Uninstall","'&'","odbc_install.exe","/Install" -Verb Runas -Wait
    ) else (
        echo You need to build release first before installing.
    )
    goto :switch-case-end

:switch-case-end

GOTO :exit

REM ***************************************************
:fn_ConfigVisualStudio
    REM
    REM Visual Studio 2017 / 2019 / 2022 / future versions (hopefully)...
    REM
    CALL :fn_TryUseVsWhereExe
    IF NOT DEFINED VSWHEREINSTALLDIR GOTO skip_detectVisualStudio2017
    SET VSVARS32=%VSWHEREINSTALLDIR%\Common7\Tools\VsDevCmd.bat
    IF EXIST "%VSVARS32%" (
            ECHO Using Visual Studio 2017 / 2019 / 2022...
            set CLARG=-arch=%ARCH%
            %__DEBUGECHO% VSVARS32="%VSVARS32%" %CLARG%
            GOTO skip_detectVisualStudio
    )
    :skip_detectVisualStudio2017

    REM
    REM Visual Studio 2015
    REM
    IF NOT DEFINED VS140COMNTOOLS GOTO skip_detectVisualStudio2015
    SET VSVARS32=%VS140COMNTOOLS%..\..\VC\vcvarsall.bat
    IF EXIST "%VSVARS32%" (
        ECHO Using Visual Studio 2015...
        if %bit%==64 (
            set CLARG=x86_%ARCH% 
        ) else (
            SET CLARG=%ARCH% 
        )
        %__DEBUGECHO% VSVARS32="%VSVARS32%" %ARCH%
        GOTO skip_detectVisualStudio
    )
    :skip_detectVisualStudio2015

    REM
    REM Visual Studio 2013
    REM
    IF NOT DEFINED VS120COMNTOOLS GOTO skip_detectVisualStudio2013
    SET VSVARS32=%VS120COMNTOOLS%..\..\VC\vcvarsall.bat
    IF EXIST "%VSVARS32%" (
        ECHO Using Visual Studio 2013...
        if %bit%==64 (
            set CLARG=x86_%ARCH% 
        ) else (
            SET CLARG=%ARCH% 
        )
        %__DEBUGECHO% VSVARS32="%VSVARS32%" %ARCH%
        GOTO skip_detectVisualStudio
    )
    :skip_detectVisualStudio2013

    REM
    REM Visual Studio 2012
    REM
    IF NOT DEFINED VS110COMNTOOLS GOTO skip_detectVisualStudio2012
    SET VSVARS32=%VS140COMNTOOLS%..\..\VC\vcvarsall.bat
    IF EXIST "%VSVARS32%" (
        ECHO Using Visual Studio 2012...
        if %bit%==64 (
            set CLARG=x86_%ARCH% 
        ) else (
            SET CLARG=%ARCH% 
        )
        %__DEBUGECHO% VSVARS32="%VSVARS32%" %ARCH%
        GOTO skip_detectVisualStudio
    )
    :skip_detectVisualStudio2012

    REM
    REM Visual Studio 2010
    REM
    IF NOT DEFINED VS100COMNTOOLS GOTO skip_detectVisualStudio2010
    SET VSVARS32=%VS100COMNTOOLS%..\..\VC\vcvarsall.bat
    IF EXIST "%VSVARS32%" (
        ECHO Using Visual Studio 2010...
        if %bit%==64 (
            set CLARG=x86_%ARCH% 
        ) else (
            SET CLARG=%ARCH% 
        )
        %__DEBUGECHO% VSVARS32="%VSVARS32%" %ARCH%
        GOTO skip_detectVisualStudio
    )
    :skip_detectVisualStudio2010

    REM
    REM NOTE: At this point, the appropriate Visual Studio version should be
    REM       selected.
    REM
    :skip_detectVisualStudio

    SET VSVARS32=%VSVARS32:\\=\%
    %__DEBUGECHO% "%VSVARS32%" %CLARG%
    CALL "%VSVARS32%" %CLARG% 1>nul
    GOTO :EOF

REM ***************************************************
:fn_GetCompilerArch
    set "cl_arch="
    SET _cmd=cl /? 
    FOR /F "delims=" %%G IN ('%_cmd% 2^>^&1 ^| findstr /C:"Version"') DO (
        for %%A in (%%G) do (
            set cl_arch=%%A
        )
    )
    echo cl.exe compiler architectue is %cl_arch%
    GOTO :EOF

REM ***************************************************
:fn_TryUseVsWhereExe
    IF DEFINED VSWHERE_EXE GOTO skip_setVsWhereExe
    SET VSWHERE_EXE=%ProgramFiles(x86)%\Microsoft Visual Studio\Installer\vswhere.exe
    IF NOT EXIST "%VSWHERE_EXE%" SET VSWHERE_EXE=%ProgramFiles%\Microsoft Visual Studio\Installer\vswhere.exe
    :skip_setVsWhereExe

    IF NOT EXIST "%VSWHERE_EXE%" (
        ECHO The "VsWhere" tool does not appear to be installed.
        GOTO :EOF
    ) ELSE (
        %__DEBUGECHO% VSWHERE_EXE="%VSWHERE_EXE%"
    )
    SET VS_WHEREIS_CMD="%VSWHERE_EXE%" -products * -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -property installationPath -latest
    %__DEBUGECHO% VS_WHEREIS_CMD=%VS_WHEREIS_CMD%

    FOR /F "delims=" %%D IN ('%VS_WHEREIS_CMD%') DO (SET VSWHEREINSTALLDIR=%%D)

    IF NOT DEFINED VSWHEREINSTALLDIR (
        ECHO Visual Studio 2017 / 2019 / 2022 is not installed.
    GOTO :EOF
    )
    %__DEBUGECHO% Visual Studio 2017 / 2019 / 2022 is installed.
    %__DEBUGECHO% VsWhereInstallDir = '%VSWHEREINSTALLDIR%'
    GOTO :EOF

REM ***************************************************
:exit

