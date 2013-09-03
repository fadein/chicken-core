#!/bin/sh
# runtests.sh - run CHICKEN testsuite
#
# - Note: this needs a proper shell, so it will not work with plain mingw
#   (just the compiler and the Windows shell, without MSYS)

set -e
TEST_DIR=`pwd`
OS_NAME=`uname -s`
DYLD_LIBRARY_PATH=${TEST_DIR}/..
LD_LIBRARY_PATH=${LD_LIBRARY_PATH}:${TEST_DIR}/..
#LD_LIBRARY_PATH=${TEST_DIR}/..
LIBRARY_PATH=${TEST_DIR}/..:${LIBRARY_PATH}
export DYLD_LIBRARY_PATH LD_LIBRARY_PATH LIBRARY_PATH

rm -fr test-repository
mkdir -p test-repository

# copy files into test-repository (by hand to avoid calling `chicken-install'):

for x in setup-api.so setup-api.import.so setup-download.so \
      setup-download.import.so chicken.import.so lolevel.import.so \
      srfi-1.import.so srfi-4.import.so data-structures.import.so \
      ports.import.so files.import.so posix.import.so \
      srfi-13.import.so srfi-69.import.so extras.import.so \
      irregex.import.so srfi-14.import.so tcp.import.so \
      foreign.import.so srfi-18.import.so \
      utils.import.so csi.import.so irregex.import.so types.db; do
  cp ../$x test-repository
done

CHICKEN_REPOSITORY=${TEST_DIR}/test-repository
CHICKEN=../chicken
CHICKEN_INSTALL=${TEST_DIR}/../chicken-install
CHICKEN_UNINSTALL=${TEST_DIR}/../chicken-uninstall
ASMFLAGS=
FAST_OPTIONS="-O5 -d0 -b -disable-interrupts"

TYPESDB=../types.db
cp $TYPESDB test-repository/types.db

if test -n "$MSYSTEM"; then
    CHICKEN="..\\chicken.exe"
    ASMFLAGS=-Wa,-w
    # make compiled tests use proper library on Windows
    cp ../lib*chicken*.dll .
fi


# for cygwin
if test -f ../cygchicken-0.dll; then
    cp ../cygchicken-0.dll .
    cp ../cygchicken-0.dll reverser/tags/1.0
    mv ../cygchicken-0.dll ../cygchicken-0.dll_
fi

compile="../csc -compiler $CHICKEN -v -I.. -L.. -include-path .. -o a.out"
compile2="../csc -compiler $CHICKEN -v -I.. -L.. -include-path .."
compile_s="../csc -s -compiler $CHICKEN -v -I.. -L.. -include-path .."
interpret="../csi -n -include-path .."

rm -f *.exe *.so *.o *.import.* a.out ../foo.import.*

echo "======================================== private repository test ..."
mkdir -p tmp
$compile private-repository-test.scm -private-repository -o tmp/xxx
tmp/xxx $PWD/tmp
PATH=$PWD/tmp:$PATH xxx $PWD/tmp
# this may crash, if the PATH contains a non-matching libchicken.dll on Windows:
#PATH=$PATH:$PWD/tmp xxx $PWD/tmp
rm -fr rev-app rev-app-2 reverser/*.import.* reverser/*.so

echo "======================================== reinstall tests"
CHICKEN_REPOSITORY=$CHICKEN_REPOSITORY $CHICKEN_UNINSTALL -force reverser
CHICKEN_REPOSITORY=$CHICKEN_REPOSITORY $CHICKEN_INSTALL -t local -l $TEST_DIR reverser:1.0 \
 -csi ${TEST_DIR}/../csi
CHICKEN_REPOSITORY=$CHICKEN_REPOSITORY $interpret -bnq rev-app.scm 1.0
CHICKEN_REPOSITORY=$CHICKEN_REPOSITORY $CHICKEN_INSTALL -t local -l $TEST_DIR -reinstall -force \
 -csi ${TEST_DIR}/../csi
CHICKEN_REPOSITORY=$CHICKEN_REPOSITORY $interpret -bnq rev-app.scm 1.0

echo
echo "dump -X64 -nhv rev-app | less"
echo
echo "======================================== deployment tests"
# echo "Press the [ANY] key to continue"
# read
set -x

mkdir rev-app
CHICKEN_REPOSITORY=$CHICKEN_REPOSITORY $CHICKEN_INSTALL -t local -l $TEST_DIR reverser
echo
echo
CHICKEN_REPOSITORY=$CHICKEN_REPOSITORY $compile2 -deploy rev-app.scm
echo
echo
export CSC_OPTIONS=-v\ -Wl,-R/home/efalor/.storm-dev/lib
CHICKEN_REPOSITORY=$CHICKEN_REPOSITORY $CHICKEN_INSTALL -deploy -prefix rev-app -t local -l $TEST_DIR reverser -k
echo
echo
unset LD_LIBRARY_PATH DYLD_LIBRARY_PATH CHICKEN_REPOSITORY
rev-app/rev-app 1.1
mv rev-app rev-app-2
rev-app-2/rev-app 1.1

echo "======================================== done."
