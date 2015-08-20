@echo off

echo "Copying stdint.h for windows"
cp "%LIBRARY_INC%\stdint.h" "modules\videoio\src\stdint.h"

mkdir build
cd build

if %ARCH%==32 (
  set CMAKE_CONFIG="Release"
  set OPENCV_ARCH=x86

  if %PY_VER% LSS 3 (
    set OPENCV_VC=vc9
    set CMAKE_GENERATOR="Visual Studio 9 2008"
  ) else (
    set OPENCV_VC=vc10
	set CMAKE_GENERATOR="Visual Studio 10"
  )
)
if %ARCH%==64 (
  set CMAKE_CONFIG="Release"
  set OPENCV_ARCH=x64

  if %PY_VER% LSS 3 (
    set OPENCV_VC=vc9
    set CMAKE_GENERATOR="Visual Studio 9 2008 Win64"
  ) else (
    set OPENCV_VC=vc10
	set CMAKE_GENERATOR="Visual Studio 10 Win64"
  )
)

set PY_VER_NO_DOT=%PY_VER:.=%
set PY_LIBRARY="%PREFIX%\libs\python%PY_VER_NO_DOT%.lib"
set PY_LIBRARY=%PY_LIBRARY:\=/%

set PY_INCLUDE_PATH="%PREFIX%\include"
set PY_INCLUDE_PATH=%PY_INCLUDE_PATH:\=/%

set PY_SP_DIR="%SP_DIR%"
set PY_SP_DIR=%PY_SP_DIR:\=/%

set PY_EXEC="%PYTHON%"
set PY_EXEC=%PY_EXEC:\=/%

if %PY3K%==1 (
  set OCV_PYTHON="-DBUILD_opencv_python3=1 -DPYTHON_EXECUTABLE=%PY_EXEC%"
) else (
  set OCV_PYTHON="-DBUILD_opencv_python2=1 -DPYTHON_EXECUTABLE=%PY_EXEC%"
)

rem wget the contrib package
"%LIBRARY_BIN%\wget.exe" -O contrib.tar.gz https://github.com/Itseez/opencv_contrib/archive/3.0.0.tar.gz --no-check-certificate
rem Copy a cached version for speed
rem copy ..\..\..\src_cache\contrib.tar.gz contrib.tar.gz
rem TODO: Check SHA256 of downloaded contrib package
rem if [ $(shasum -a 256 "contrib.tar.gz") != "8fa18564447a821318e890c7814a262506dd72aaf7721c5afcf733e413d2e12b" ]; then
rem     exit 1
rem fi
tar -xzf contrib.tar.gz

patch -p0 < %RECIPE_DIR%\binary_descriptor.patch
patch -p0 < %RECIPE_DIR%\bitops.patch
patch -p0 < %RECIPE_DIR%\daisy.patch
patch -p0 < %RECIPE_DIR%\lsddetector_pow.patch
patch -p0 < %RECIPE_DIR%\saliency.patch
patch -p0 < %RECIPE_DIR%\seeds.patch
patch -p0 < %RECIPE_DIR%\transientareassegmentationmodule.patch

cmake .. -G%CMAKE_GENERATOR%                                   ^
    -DWITH_EIGEN=1                                             ^
    -DBUILD_TESTS=0                                            ^
    -DBUILD_DOCS=0                                             ^
    -DBUILD_PERF_TESTS=0                                       ^
    -DBUILD_ZLIB=1                                             ^
    -DBUILD_TIFF=1                                             ^
    -DBUILD_PNG=1                                              ^
    -DBUILD_OPENEXR=1                                          ^
    -DBUILD_JASPER=1                                           ^
    -DBUILD_JPEG=1                                             ^
    -DWITH_CUDA=0                                              ^
    -DWITH_OPENCL=0                                            ^
    -DWITH_OPENNI=0                                            ^
    -DWITH_FFMPEG=0                                            ^
    %OCV_PYTHON%                                               ^
    -DOPENCV_EXTRA_MODULES_PATH="opencv_contrib-3.0.0\modules" ^
    -DCMAKE_INSTALL_PREFIX="%LIBRARY_PREFIX%"

cmake --build . --config %CMAKE_CONFIG% --target ALL_BUILD
cmake --build . --config %CMAKE_CONFIG% --target INSTALL

rem Let's just move the files around to a more sane structure (flat)
move "%LIBRARY_PREFIX%\%OPENCV_ARCH%\%OPENCV_VC%\bin\*.dll" "%LIBRARY_LIB%"
move "%LIBRARY_PREFIX%\%OPENCV_ARCH%\%OPENCV_VC%\bin\*.exe" "%LIBRARY_BIN%"
move "%LIBRARY_PREFIX%\%OPENCV_ARCH%\%OPENCV_VC%\lib\*.lib" "%LIBRARY_LIB%"
rmdir "%LIBRARY_PREFIX%\%OPENCV_ARCH%" /S /Q

rem By default cv.py is installed directly in site-packages
rem Therefore, we have to copy all of the dlls directly into it!
xcopy "%LIBRARY_LIB%\opencv*.dll" "%SP_DIR%"
