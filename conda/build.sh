#!/bin/bash
mkdir build
cd build

CMAKE_GENERATOR="Unix Makefiles"
CMAKE_ARCH="-m"$ARCH
SHORT_OS_STR=$(uname -s)

if [ "${SHORT_OS_STR:0:5}" == "Linux" ]; then
    DYNAMIC_EXT="so"
    TBB=""
    OPENMP="-DWITH_OPENMP=1"
    IS_OSX=0
    # There's a bug with CMake at the moment whereby it can't download
    # using HTTPS - so we use curl to download the IPP library
    mkdir -p $SRC_DIR/3rdparty/ippicv/downloads/linux-808b791a6eac9ed78d32a7666804320e
    curl -L https://raw.githubusercontent.com/Itseez/opencv_3rdparty/81a676001ca8075ada498583e4166079e5744668/ippicv/ippicv_linux_20151201.tgz -o $SRC_DIR/3rdparty/ippicv/downloads/linux-808b791a6eac9ed78d32a7666804320e/ippicv_linux_20151201.tgz
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

git clone https://github.com/Itseez/opencv_contrib
cd opencv_contrib
git checkout tags/$PKG_VERSION
cd ..

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
    -DWITH_VTK=0                                                         \
    -DINSTALL_C_EXAMPLES=0                                               \
    -DOPENCV_EXTRA_MODULES_PATH="opencv_contrib/modules"                 \
    -DCMAKE_SKIP_RPATH:bool=ON                                           \
    -DCMAKE_INSTALL_PREFIX=$PREFIX
make -j${CPU_COUNT}
make install

