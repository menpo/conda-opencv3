#!/bin/bash
mkdir build
cd build

CMAKE_GENERATOR="Unix Makefiles"
CMAKE_ARCH="-m"$ARCH
SHORT_OS_STR=$(uname -s)

if [ "${SHORT_OS_STR:0:5}" == "Linux" ]; then
    export CFLAGS="$CFLAGS $CMAKE_ARCH"
    export LDFLAGS="$LDFLAGS $CMAKE_ARCH"
    DYNAMIC_EXT="so"
    TBB=""
    OPENMP="-DWITH_OPENMP=1"
    IS_OSX=0
fi
if [ "${SHORT_OS_STR}" == "Darwin" ]; then
    IS_OSX=1
    DYNAMIC_EXT="dylib"
    OPENMP=""
    TBB="-DWITH_TBB=1 -DTBB_LIB_DIR=$PREFIX/lib -DTBB_INCLUDE_DIRS=$PREFIX/include -DTBB_STDDEF_PATH=$PREFIX/include/tbb/tbb_stddef.h"

    # Apparently there is a bug in pthreads that is specific to the case of
    # building something with a deployment target of 10.6 but with an SDK
    # that is higher than 10.6. At the moment, on my laptop, I don't have the 10.6
    # SDK, so I hack around this here by moving the deployment target to 10.7
    # See here for the bug I'm seeing, which is specific to pthreads, not OpenCV
    # http://lists.gnu.org/archive/html/bug-gnulib/2013-05/msg00040.html
    export MACOSX_DEPLOYMENT_TARGET="10.7"
fi

if [ $PY3K -eq 1 ]; then
    PY_VER_M="${PY_VER}m"
    OCV_PYTHON="-DBUILD_opencv_python3=1 -DPYTHON3_EXECUTABLE=$PYTHON -DPYTHON3_INCLUDE_DIR=$PREFIX/include/python${PY_VER_M} -DPYTHON3_LIBRARY=${PREFIX}/lib/libpython${PY_VER_M}.${DYNAMIC_EXT}"
else
    OCV_PYTHON="-DBUILD_opencv_python2=1 -DPYTHON2_EXECUTABLE=$PYTHON -DPYTHON2_INCLUDE_DIR=$PREFIX/include/python${PY_VER} -DPYTHON2_LIBRARY=${PREFIX}/lib/libpython${PY_VER}.${DYNAMIC_EXT} -DPYTHON_INCLUDE_DIR2=$PREFIX/include/python${PY_VER}"
fi

export CFLAGS="-I$PREFIX/include -fPIC $CFLAGS"
export LDFLAGS="-L$PREFIX/lib $LDFLAGS"

# wget the contrib package
wget -O contrib.tar.gz https://github.com/Itseez/opencv_contrib/archive/3.0.0.tar.gz
# Copy a cached version for speed
#cp ../../../src_cache/contrib.tar.gz contrib.tar.gz
if [ $(shasum -a 256 "contrib.tar.gz") != "8fa18564447a821318e890c7814a262506dd72aaf7721c5afcf733e413d2e12b" ]; then
    exit 1
fi
tar -xzf contrib.tar.gz
# Seems to be some error with a pow overload - so I just patch it here.
patch -p0 < $RECIPE_DIR/lsddetector_pow.patch

cmake .. -G"$CMAKE_GENERATOR"                                            \
    $TBB                                                                 \
    $OPENMP                                                              \
    $OCV_PYTHON                                                          \
    -DWITH_EIGEN=1                                                       \
    -DBUILD_TESTS=0                                                      \
    -DBUILD_DOCS=0                                                       \
    -DBUILD_PERF_TESTS=0                                                 \
    -DBUILD_ZLIB=1                                                       \
    -DBUILD_TIFF=1                                                       \
    -DBUILD_PNG=1                                                        \
    -DBUILD_OPENEXR=1                                                    \
    -DBUILD_JASPER=1                                                     \
    -DBUILD_JPEG=1                                                       \
    -DWITH_CUDA=0                                                        \
    -DWITH_OPENCL=0                                                      \
    -DWITH_OPENNI=0                                                      \
    -DWITH_FFMPEG=0                                                      \
    -DOPENCV_EXTRA_MODULES_PATH="opencv_contrib-3.0.0/modules"           \
    -DCMAKE_INSTALL_PREFIX=$PREFIX
make -j${CPU_COUNT}
make install


if [ $IS_OSX -eq 1 ]; then
    # Fix the lib prefix for the libraries
    # Borrowed from
    # http://answers.opencv.org/question/4134/cmake-install_name_tool-absolute-path-for-library-on-mac-osx/
    CV_LIB_PATH=$PREFIX/lib
    find ${CV_LIB_PATH} -type f -name "libopencv*.dylib" -print0 | while IFS="" read -r -d "" dylibpath; do
        echo install_name_tool -id "$dylibpath" "$dylibpath"
        install_name_tool -id "$dylibpath" "$dylibpath"
        otool -L $dylibpath | grep libopencv | tr -d ':' | while read -a libs ; do
            [ "${file}" != "${libs[0]}" ] && install_name_tool -change ${libs[0]} `basename ${libs[0]}` $dylibpath
        done
    done

    # Fix the lib prefix for the cv2.so
    # Borrowed from
    # http://answers.opencv.org/question/4134/cmake-install_name_tool-absolute-path-for-library-on-mac-osx/
    find ${SP_DIR} -type f -name "cv2*.so" -print0 | while IFS="" read -r -d "" dylibpath; do
    echo install_name_tool -id "$dylibpath" "$dylibpath"
        install_name_tool -id "$dylibpath" "$dylibpath"
        otool -L $dylibpath | grep libopencv | tr -d ':' | while read -a libs ; do
            [ "${file}" != "${libs[0]}" ] && install_name_tool -change ${libs[0]} `basename ${libs[0]}` $dylibpath
        done
    done

    # Fix the lib prefix for the binaries
    # Borrowed from
    # http://answers.opencv.org/question/4134/cmake-install_name_tool-absolute-path-for-library-on-mac-osx/
    CV_BIN_PATH=$PREFIX/bin
    find ${CV_BIN_PATH} -type f -name "opencv*" -print0 | while IFS="" read -r -d "" dylibpath; do
        echo install_name_tool -id "$dylibpath" "$dylibpath"
        install_name_tool -id "$dylibpath" "$dylibpath"
        otool -L $dylibpath | grep libopencv | tr -d ':' | while read -a libs ; do
            [ "${file}" != "${libs[0]}" ] && install_name_tool -change ${libs[0]} `basename ${libs[0]}` $dylibpath
        done
    done
fi
