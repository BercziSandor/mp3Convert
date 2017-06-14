@echo off
setlocal
set basedir=d:\temp
set indir=%basedir%\_in
set outdir=%basedir%\_out
set outdirbak=%outdir%
set mp3playerDir=e:\mtpmedia
if exist .\lame.exe set LIBDIR=%CD%
if exist .\lib\lame.exe set LIBDIR=%CD%\lib
if "%LIBDIR%" == "" (
@echo Lame not found.
goto error
)
set wait=%LIBDIR%\..\wait.com 0



if "%1" NEQ "" goto drop

rem cls
set s50=-–vbr-new -h      -q 0 -V 8
set s50=-–preset voice
set s51=-b 8  -B 128      -q 0 -V 8
set s52=--abr 16            -a --resample 11 --lowpass 5 --athtype 2 -X3
set s53=--alt-preset cbr 16 -a --resample 11 --lowpass 5                 -Z
set s54=-b 16               -a --resample 11 --lowpass 5 --athtype 2
set s55=--alt-preset cbr 24 -a --resample 22 --lowpass 7                 -Z
set s56=--alt-preset cbr 24 -a --resample 22 --lowpass 7                 -Z
set s57=-b 16               -a --resample 11 --lowpass 5 --athtype 2 -X3

@echo ***********************************************
@echo  mp3 converter by Bob ( bob.gray@freemail.hu )
@echo ***********************************************
@echo Input  directory: %indir%
@echo Output directory: %outdir%
@echo Destination: %mp3playerDir%
@echo  (The files will be copied at the end, if destination available)
@echo.
@echo.
@echo Predefined settings:

@echo 00  no recompress, only rename.
@echo m - Manual parameters
@echo 1 - Low:           96kbps, ABR, 32kHz
@echo 2 - Normal:       128kbps, ABR
@echo 3 - High:         160kbps, ABR
@echo 4 - Poor quality source digitalisation
@echo 42    Poor quality, ringtone
@echo     Speech:
@echo 51    		%s50%
@echo 51    		%s51%
@echo 52    		%s52%
@echo 53    		%s53%
@echo 54    		%s54%
@echo 55    Best40: %s55%
@echo 56    Best24: %s56%
@echo 57    Best16: %s57%

set /p answer="Quality?"

if %answer% EQU 00 (
	set renameOnly=yes
	goto choosen
) else (
	set renameOnly=no
)

if %answer% EQU m goto ans4

if %answer% EQU 1 (
	set OPTS=--resample 32 -q 3 --abr 96 -p
)

if %answer% EQU 2 (
	set OPTS=-q 1 --abr 128
)

if %answer% EQU 3 (
	set OPTS=-q 0 --abr 160
)

if %answer% EQU 4 (
set OPTS=--abr 64 -q 1
	)
if %answer% EQU 42 (
	set OPTS=--abr 40 -q 0 -a
	set OPTS=--abr 40 -q 0 -a
)

if %answer% EQU 50 (
	set OPTS=%s50%
)

if %answer% EQU 51 (
	set OPTS=%s51%
)

if %answer% EQU 52 (
	set OPTS=%s52%
)

if %answer% EQU 53 (
	set OPTS=%s53%
)else

if %answer% EQU 54 (
	set OPTS=%s54%
)

if %answer% EQU 55 (
	set OPTS=%s55%
)

if %answer% EQU 56 (
	set OPTS=%s56%
)

if %answer% EQU 57 (
rem 16kbps speech:
rem 16kbps speech:
	set OPTS=%s57%
)

goto choosen

:ans4
@echo.
@echo  Quality
@echo  -q 0:  Highest quality, very slow
@echo  -q 9:  Poor quality, but fast
set /p answer="Choosen quality?"
set OPTS=-q %answer%
@echo.
@echo Bitrate in kbps
@echo 32 40 48 56 64 80 96 112 128 160 192 224 256 320
set /p answer="Choosen bitrate?"
set OPTS=%OPTS% --abr %answer%


:choosen
set OPTS=%OPTS% --mp3input --priority 0

@echo.
set answer=""
set /p answer="Normalize?"
if "%answer%" == "1" set normalize=yes
if "%answer%" == "y" set normalize=yes
if "%answer%" == "i" set normalize=yes
if "%answer%" == "0" set normalize=no
if "%answer%" == "n" set normalize=no
if "%normalize%"=="" set normalize=no
@echo Normalize: %normalize%

set answer=""
set /p answer="Shutdown after processing?"
if "%answer%" == "1" set shutdown=yes
if "%answer%" == "y" set shutdown=yes
if "%answer%" == "i" set shutdown=yes
if "%answer%" == "0" set shutdown=no
if "%answer%" == "n" set shutdown=no
if "%shutdown%"==""  set shutdown=no

rem ..\CMDOW @ /MIN

rem set /P outdir=Output directory: %outdir%
rem set /P indir=Input directory: %indir%
rem set /P OPTS=%OPTS%

if not exist %outdir% mkdir %outdir%
set thecmd=%LIBDIR%\lame.exe %OPTS%

if not exist %indir% (
@echo %indir%\ not found
md %indir%
goto error
)

if "%1"== "" goto indir
if not exist %1 goto indir

:drop
@echo Drag and drop feature permamantly disbled, please copy files
@echo manualy to %outdir% and then start this process again.
exit

if exist %1 (
if "%~x1"=="" (
	@echo %~d1 %~p1 %~n1 %~x1
	rem 	xxcopy %1 "%indir%\%~n1" /s
	rem @echo	xcopy %1 "%indir%\%~n1" /d /v /e /h /z /y >m:\Programok\mp3\cooooo.bat
	exit
) else (
	xcopy %1 "%indir%" /d /v /e /h /z /y
)
shift
)
if exist %1 goto drop



rem ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
:indir
xcopy "%indir%" "%outdir%" /EXCLUDE:temp.tmp /s /i
del temp.tmp /q 2>nul

for /R %indir% %%a in (*.mp3) DO (
	@echo call :process "%%~da" "%%~pa" "%%~na" "%%~xa"
	call :process "%%~da" "%%~pa" "%%~na" "%%~xa"
)

rem ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
:kopi
rem if not exist %outdir%\*.mp3 goto end
rem cls
@echo.
@echo.
rem ..\CMDOW @ /RES /ACT /VIS

if not exist %mp3playerDir% (
REM @echo   
@echo   Waiting for connect device as %mp3playerDir%...
@echo   Press any key...

pause >nul
)
if not exist %mp3playerDir% (
	@echo.
	%wait% Drive not connected, exiting.
	:shutdown
	if "%shutdown%"=="yes" call ..\stop.cmd
	goto end
)

set dt=%date:.=%
md %mp3playerDir%\%dt%
if exist %mp3playerDir%\%dt% (
	cd /d %mp3playerDir%\
	cd /d %dt%
	start /B xcopy %outdirbak%\*.mp3 /y /d /s>nul
)
@echo 
goto end
rem ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::


:process

rem @echo :process: "%~1" "%~2" "%~3" "%~4"
set dp="%~1%~2"
set oname="%~3%~4%"
title Transcoding file: %oname%
set name=%oname%
set name=%name:_= %
set name=%name:'=%
set name=%name:-= - %
set name=%name:(=%
set name=%name:)=%
set name=%name:^&= and %

:remdsp
set name=%name:  = %
if %name% NEQ %name:  = % goto remdsp


set infname="%dp:"=%%oname:"=%"
set outdir=%dp:_in=_out%
set outfname="%outdir:"=%%name:"=%"
set dt=%date:.=%
rem set outfname="%outdir%%name%"

if not exist %outdir% md %outdir%
if not exist %outfname% (
	rem cls
	@echo.
	if "%normalize%"=="yes" (
		@echo Normalizing...
		@echo.
		%LIBDIR%\mp3gain.exe /p /s r /a %infname%
	)

	@echo.
	@echo Transcoding...
	@echo.

	if "%renameOnly%"=="yes" (
		copy /Y /V %infname% %outfname%
	) else (
		%thecmd% %infname% %outfname%
	)


	rem cls
	@echo.
	@echo Tag copy...
	@echo.
	%LIBDIR%\Tag.exe --fromfile %infname% --zeropad --commafix --spacefix %outfname% >nul
	rem %LIBDIR%\Tag.exe --fromfile %infname% --Caps --zeropad --stripextra --commafix --spacefix %outfname% >nul
	%wait%
	if exist "%mp3playerDir%" (
		if not exist %mp3playerDir%\%dt% md %mp3playerDir%\%dt%
		if exist %mp3playerDir%\%dt% (
			cd /d %mp3playerDir%\%dt%
		 	start /B xcopy %outdirbak%\*.mp3 /y /d /s>nul
		)
	) else (
	%wait% if exist "%mp3playerDir%": false...
	)
	%wait% zarizo
)
) else (
	@echo
	%wait% File already exists, skipped - %outfname%
)
goto end


:error
REM @echo  
@echo Abnormal termination.
%wait%

:end
endlocal
goto :eof