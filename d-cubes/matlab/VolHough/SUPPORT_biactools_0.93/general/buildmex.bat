@echo off
REM Build BIAC MATLAB mex files for Windows
setlocal

REM Initialize variables to default values
set MATLABVER=6.5
set EXTERNPATH=\\Gall\Source\external\win32
set LIBXML2VER=2.5.10
set ICONVVER=1.9.1

REM Copy default values for usage message
set MATLABVERDEF=%MATLABVER%
set EXTERNPATHDEF=%EXTERNPATH%
set LIBXML2VERDEF=%LIBXML2VER%
set ICONVVERDEF=%ICONVVER%

REM Parse command line arguments
if {%1}=={?} goto usage
if {%1}=={/?} goto usage
if {%1}=={} goto doneWithArgs

:nextArg
if /i {%1}=={/M} set MATLABVER=%2& goto matchedSwitch
if /i {%1}=={/E} set EXTERNPATH=%2& goto matchedSwitch
if /i {%1}=={/X} set LIBXML2VER=%2& goto matchedSwitch
if /i {%1}=={/I} set ICONVVER=%2& goto matchedSwitch
echo Unknown option %1 & echo. & goto usage

:matchedSwitch
REM Make sure user specified an argument for the last switch
if {%2}=={} echo Missing argument for %1 switch. & echo. & goto usage

REM Make sure user didn't specify two switches in a row
set temp=%2
if {%temp:~0,1%}=={/} echo Missing argument for %1 switch. & echo. & goto usage

REM Remove the arguments we just processed (don't clobber %0)
shift /1 & shift /1
if not {%1}=={} goto nextarg
:doneWithArgs

REM Build functions with no additional includes
for %%f in (hcoords.c minmax.c scaled2rgb.c trilinear.c) do (
  echo Building %%f
  echo   mex.bat %%f
  call mex.bat %%f
  echo.
)

REM Build "private" functions
cd private
for %%f in (deleteonclose.c) do (
  echo Building private\%%f
  echo   mex.bat %%f
  call mex.bat %%f
  echo.
)
cd ..

echo Building cellfun2
if %MATLABVER% GEQ 6.5 (
  echo   mex.bat -output cellfun2LT cellfun2.c
  call mex.bat -output cellfun2LT cellfun2.c
) else (
  REM Need to built with no logical type support before MATLAB 6.5
  echo   mex.bat -DNO_LOGICAL_TYPE -output cellfun2NLT cellfun2.c
  call mex.bat -DNO_LOGICAL_TYPE -output cellfun2NLT cellfun2.c 
)
echo.

REM Build functions with library dependencies
set LIBXML2LIB=%EXTERNPATH%\libxml2-%LIBXML2VER%.win32\lib\libxml2.lib
set LIBXML2INC=%EXTERNPATH%\libxml2-%LIBXML2VER%.win32\include
set ICONVINC=%EXTERNPATH%\iconv-%ICONVVER%.win32\include

REM Only build readxml & writexml if dependencies exist
set BUILDXML=Yes
if not exist %LIBXML2LIB% echo Missing %LIBXML2LIB% & set BUILDXML=No
if not exist %LIBXML2INC% echo Missing %LIBXML2INC% & set BUILDXML=No
if not exist %ICONVINC% echo Missing %ICONVINC% & set BUILDXML=No

if {%BUILDXML%}=={No} (
  echo Cannot build readxml or writexml! & echo.
) else (
  echo Building readxml
  echo   mex.bat -I%LIBXML2INC% -I%ICONVINC% readxml.c %LIBXML2LIB%
  call mex.bat -I%LIBXML2INC% -I%ICONVINC% readxml.c %LIBXML2LIB%
  echo.

  echo Buildng writexml
  echo   mex.bat -I%LIBXML2INC% -I%ICONVINC% writexml.c %LIBXML2LIB%
  call mex.bat -I%LIBXML2INC% -I%ICONVINC% writexml.c %LIBXML2LIB%
  echo.
)

echo.
echo Done building mex files
goto :eof

REM Display help
:usage
echo %0: Build BIAC MATLAB MEX libraries
echo.
echo Usage:
echo   %0 [OPTIONS]
echo. 
echo Options:
echo   /E DIR
echo      Path to external libraries (libxml ^& iconv)
echo      default = %EXTERNPATHDEF%
echo   /M MATLAB_VERSION  (default = %MATLABVERDEF%)
echo   /X LIBXML2_VERSION (default = %LIBXML2VERDEF%)
echo   /I ICONV_VERSION   (default = %ICONVVERDEF%)
echo.
echo Required external libraries:
echo - libxml2 (readxml, writexml)
echo - iconv   (readxml, writexml)
echo.
echo Note: Assumes PC
goto :eof
