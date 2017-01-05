SHORT_OS_STR=$(uname -s)

if [ "${SHORT_OS_STR:0:5}" == "Linux" ]; then
    DYNAMIC_EXT="so"
    OPENMP="-DWITH_OPENMP=1"
    # There's a bug with CMake at the moment whereby it can't download
    # using HTTPS - so we use curl to download the IPP library
    mkdir -p $SRC_DIR/3rdparty/ippicv/downloads/linux-808b791a6eac9ed78d32a7666804320e
    curl -L https://raw.githubusercontent.com/opencv/opencv_3rdparty/81a676001ca8075ada498583e4166079e5744668/ippicv/ippicv_linux_20151201.tgz -o $SRC_DIR/3rdparty/ippicv/downloads/linux-808b791a6eac9ed78d32a7666804320e/ippicv_linux_20151201.tgz
fi
if [ "${SHORT_OS_STR}" == "Darwin" ]; then
    DYNAMIC_EXT="dylib"
    OPENMP=""
fi

curl -L -O "https://github.com/opencv/opencv_contrib/archive/$PKG_VERSION.tar.gz"
test `openssl sha256 $PKG_VERSION.tar.gz | awk '{print $2}'` = "1e2bb6c9a41c602904cc7df3f8fb8f98363a88ea564f2a087240483426bf8cbe"
tar -zxf $PKG_VERSION.tar.gz

# Contrib has patches that need to be applied
# https://github.com/opencv/opencv_contrib/issues/919
git apply -p0 $RECIPE_DIR/opencv_contrib_freetype.patch

mkdir build
cd build

# For some reason OpenCV just won't see hdf5.h without updating the CFLAGS
export CFLAGS="$CFLAGS -I$PREFIX/include"
export CXXFLAGS="$CXXFLAGS -I$PREFIX/include"

cmake .. -LAH                                                             \
    $OPENMP                                                               \
    -DWITH_EIGEN=1                                                        \
    -DBUILD_TESTS=0                                                       \
    -DBUILD_DOCS=0                                                        \
    -DBUILD_PERF_TESTS=0                                                  \
    -DBUILD_ZLIB=0                                                        \
    -DFREETYPE_INCLUDE_DIRS=$PREFIX/include/freetype2                     \
    -DFREETYPE_LIBRARIES=$PREFIX/lib/libfreetype.$DYNAMIC_EXT             \
    -DPNG_LIBRARY_RELEASE=$PREFIX/lib/libpng.$DYNAMIC_EXT                 \
    -DPNG_INCLUDE_DIRS=$PREFIX/include                                    \
    -DJPEG_INCLUDE_DIR=$PREFIX/include                                    \
    -DJPEG_LIBRARY=$PREFIX/lib/libjpeg.$DYNAMIC_EXT                       \
    -DTIFF_INCLUDE_DIR=$PREFIX/include                                    \
    -DTIFF_LIBRARY=$PREFIX/lib/libtiff.$DYNAMIC_EXT                       \
    -DJASPER_INCLUDE_DIR=$PREFIX/include                                  \
    -DJASPER_LIBRARY_RELEASE=$PREFIX/lib/libjasper.$DYNAMIC_EXT           \
    -DWEBP_INCLUDE_DIR=$PREFIX/include                                    \
    -DWEBP_LIBRARY=$PREFIX/lib/libwebp.$DYNAMIC_EXT                       \
    -DHARFBUZZ_LIBRARIES=$PREFIX/lib/libharfbuzz.$DYNAMIC_EXT             \
    -DZLIB_LIBRARY_RELEASE=$PREFIX/lib/libz.$DYNAMIC_EXT                  \
    -DZLIB_INCLUDE_DIR=$PREFIX/include                                    \
    -DHDF5_z_LIBRARY_RELEASE=$PREFIX/lib/libz.$DYNAMIC_EXT                \
    -DBUILD_TIFF=0                                                        \
    -DBUILD_PNG=0                                                         \
    -DBUILD_OPENEXR=1                                                     \
    -DBUILD_JASPER=0                                                      \
    -DBUILD_JPEG=0                                                        \
    -DWITH_CUDA=0                                                         \
    -DWITH_OPENCL=0                                                       \
    -DWITH_OPENNI=0                                                       \
    -DWITH_FFMPEG=0                                                       \
    -DWITH_MATLAB=0                                                       \
    -DWITH_VTK=0                                                          \
    -DWITH_GPHOTO2=0                                                      \
    -DINSTALL_C_EXAMPLES=0                                                \
    -DOPENCV_EXTRA_MODULES_PATH="../opencv_contrib-$PKG_VERSION/modules"  \
    -DCMAKE_BUILD_TYPE="Release"                                          \
    -DCMAKE_SKIP_RPATH:bool=ON                                            \
    -DCMAKE_INSTALL_PREFIX=$PREFIX                                        \
    -DBUILD_opencv_python2=0                                              \
    -DPYTHON2_EXECUTABLE=""                                               \
    -DPYTHON2_INCLUDE_DIR=""                                              \
    -DPYTHON2_NUMPY_INCLUDE_DIRS=""                                       \
    -DPYTHON2_LIBRARY=""                                                  \
    -DPYTHON_INCLUDE_DIR2=""                                              \
    -DPYTHON2_PACKAGES_PATH=""                                            \
    -DBUILD_opencv_python3=0                                              \
    -DPYTHON3_EXECUTABLE=""                                               \
    -DPYTHON3_NUMPY_INCLUDE_DIRS=""                                       \
    -DPYTHON3_INCLUDE_DIR=""                                              \
    -DPYTHON3_LIBRARY=""                                                  \
    -DPYTHON3_PACKAGES_PATH=""


IFS='.' read -ra PY_VER_ARR <<< "${PY_VER}"
PY_MAJOR="${PY_VER_ARR[0]}"

if [ $PY3K -eq 1 ]; then
    LIB_PYTHON="${PREFIX}/lib/libpython${PY_VER}m.${DYNAMIC_EXT}"
    INC_PYTHON="$PREFIX/include/python${PY_VER}m"
else
    LIB_PYTHON="${PREFIX}/lib/libpython${PY_VER}.${DYNAMIC_EXT}"
    INC_PYTHON="$PREFIX/include/python${PY_VER}"
fi

cmake .. -LAH                                                           \
    -DPYTHON_EXECUTABLE="${PYTHON}"                                     \
    -DPYTHON_INCLUDE_DIR="${INC_PYTHON}"                                \
    -DPYTHON_LIBRARY="${LIB_PYTHON}"                                    \
    -DPYTHON_PACKAGES_PATH="${SP_DIR}"                                  \
    -DBUILD_opencv_python${PY_MAJOR}=1                                  \
    -DPYTHON${PY_MAJOR}_EXECUTABLE=${PYTHON}                            \
    -DPYTHON${PY_MAJOR}_INCLUDE_DIR=${INC_PYTHON}                       \
    -DPYTHON${PY_MAJOR}_NUMPY_INCLUDE_DIRS=${SP_DIR}/numpy/core/include \
    -DPYTHON${PY_MAJOR}_LIBRARY=${LIB_PYTHON}                           \
    -DPYTHON${PY_MAJOR}_PACKAGES_PATH=${SP_DIR}

make -j8
make install
