mkdir build

set "FORWARD_SLASHED_PREFIX=%PREFIX:\=/%"
set "FORWARD_SLASHED_LIBRARY_PREFIX=%LIBRARY_PREFIX:\=/%"
set "FORWARD_SLASHED_SRC_DIR=%SRC_DIR:\=/%"

for /f "delims=" %%A in ('%PREFIX%\python -c "import sys; print(sys.version_info.major)"') DO SET PY_MAJOR=%%A

git clone https://github.com/Itseez/opencv_contrib
cd opencv_contrib
git checkout tags/%PKG_VERSION%
cd ..
set "EXTRA=-DOPENCV_EXTRA_MODULES_PATH=%FORWARD_SLASHED_SRC_DIR%/opencv_contrib/modules"

IF %PY_MAJOR% EQU 3 (GOTO :PY3) else (GOTO :PY2)

:PY3
    REM Get python minor version by running a short script:
    for /f "delims=" %%A in ('%PREFIX%\python -c "import sys; print(sys.version_info.minor)"') DO SET PY_MINOR=%%A
    GOTO :NOTCPP11

:PY2
    REM Assume 2.7
    set PY_MINOR=7
    
    echo "Copying stdint.h for windows"
    copy "%LIBRARY_INC%\stdint.h" %SRC_DIR%\modules\calib3d\include\stdint.h
    copy "%LIBRARY_INC%\stdint.h" %SRC_DIR%\modules\videoio\include\stdint.h
    copy "%LIBRARY_INC%\stdint.h" %SRC_DIR%\modules\highgui\include\stdint.h
    
    GOTO :NOTCPP11
    
:NOTCPP11
    git apply --whitespace=fix -p0 "%RECIPE_DIR%\kcftracker.patch"
    git apply --whitespace=fix -p0 "%RECIPE_DIR%\ocr_beamsearch_decoder.patch"
    git apply --whitespace=fix -p0 "%RECIPE_DIR%\ocr_hmm_decoder.patch"

:PYTHON_SETUP

set PY_LIB=python%PY_MAJOR%%PY_MINOR%.lib

cd build

cmake -LAH -G "NMake Makefiles"^
 -DWITH_EIGEN=ON^
 -DWITH_CUDA=OFF^
 -DWITH_OPENCL=OFF^
 -DWITH_VTK=OFF^
 -DWITH_OPENNI=OFF^
 -DCMAKE_BUILD_TYPE=Release^
 -DBUILD_TESTS=OFF^
 -DBUILD_PERF_TESTS=OFF^
 -DBUILD_DOCS=OFF^
 -DCMAKE_INSTALL_PREFIX=%FORWARD_SLASHED_LIBRARY_PREFIX%^
 -DEXECUTABLE_OUTPUT_PATH=%FORWARD_SLASHED_LIBRARY_PREFIX%/bin^
 -DLIBRARY_OUTPUT_PATH=%FORWARD_SLASHED_LIBRARY_PREFIX%/lib^
 -DPYTHON%PY_MAJOR%_EXECUTABLE=%FORWARD_SLASHED_PREFIX%/python^
 -DPYTHON_INCLUDE_DIR=%FORWARD_SLASHED_PREFIX%/include^
 -DPYTHON_PACKAGES_PATH=%FORWARD_SLASHED_PREFIX%/Lib/site-packages/^
 -DPYTHON_LIBRARY=%FORWARD_SLASHED_PREFIX%/libs/%PY_LIB%^
 -DPYTHON%PY_MAJOR%_NUMPY_INCLUDE_DIRS=%FORWARD_SLASHED_PREFIX%/Lib/site-packages/numpy/core/include^
 -DCMAKE_INSTALL_PREFIX=%FORWARD_SLASHED_LIBRARY_PREFIX%^
 %EXTRA%^
 ..

if errorlevel 1 exit 1

for /F "tokens=1" %%A in ("%VSTRING%") do set VC_VER=%%A

cmake --build . --target INSTALL --config Release

if errorlevel 1 exit 1

if "%ARCH%" == "64" (
     robocopy %LIBRARY_PREFIX%\x64\vc%VC_VER%\ %LIBRARY_PREFIX%\ *.* /E
   ) else (
     robocopy %LIBRARY_PREFIX%\x86\vc%VC_VER%\ %LIBRARY_PREFIX%\ *.* /E
)
if %ERRORLEVEL% GEQ 8 exit 1

RD /S /Q "%LIBRARY_PREFIX%\bin\Release"
RD /S /Q "%LIBRARY_PREFIX%\bin\Debug"
RD /S /Q "%LIBRARY_PREFIX%\x64"
RD /S /Q "%LIBRARY_PREFIX%\x86"
RD /S /Q "%SRC_DIR%\opencv_contrib"
exit 0

