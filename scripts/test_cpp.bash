#!/bin/bash
#
# ~~~
# This file is part of the dune-xt-common project:
#   https://github.com/dune-community/dune-xt-ci
# Copyright 2009-2018 dune-xt-common developers and contributors. All rights reserved.
# License: Dual licensed as BSD 2-Clause License (http://opensource.org/licenses/BSD-2-Clause)
#      or  GPL-2.0+ (http://opensource.org/licenses/gpl-license)
#          with "runtime exception" (http://www.dune-project.org/license.html)
# Authors:
#   Felix Schindler (2017)
#   René Fritze     (2017 - 2018)
#   Tobias Leibner  (2018)
# ~~~

set -e
set -x

source ${SUPERDIR}/scripts/bash/retry_command.bash
source ${OPTS}
CTEST="ctest -V --timeout ${DXT_TEST_TIMEOUT:-300} -j ${DXT_TEST_PROCS:-2}"

rm -rf ${DUNE_BUILD_DIR}
${SRC_DCTRL} ${BLD} --module=${MY_MODULE} all
${SRC_DCTRL} ${BLD} --only=${MY_MODULE} bexec ${BUILD_CMD}
if [ "${TESTS_MODULE_SUBDIR}" = "None" ] ; then
  ${SRC_DCTRL} ${BLD} --only=${MY_MODULE} bexec ${BUILD_CMD} test_binaries
  HEADERCHECK="headercheck"
else
  ${SRC_DCTRL} ${BLD} --only=${MY_MODULE} bexec ${BUILD_CMD} ${TESTS_MODULE_SUBDIR}_test_binaries
  CTEST="${CTEST} -L ${TESTS_MODULE_SUBDIR}"
  HEADERCHECK="${TESTS_MODULE_SUBDIR}_headercheck"
fi

${SRC_DCTRL} ${BLD} --only=${MY_MODULE} bexec ${CTEST}
${SRC_DCTRL} ${BLD} --only=${MY_MODULE} bexec ${BUILD_CMD} ${HEADERCHECK}

cp ${DUNE_BUILD_DIR}/${MY_MODULE}/${MY_MODULE//-/\/}/test/*xml ${HOME}/testresults/

# clang coverage currently disabled for being too mem hungry
if [[ ${CC} == *"clang"* ]] ; then
    echo "Coverage reporting disabled with Clang"
    exit 0
fi

if [ "${SYSTEM_PULLREQUEST_ISFORK}" == "True" ] ; then
    echo "Coverage reporting disabled for forked repo/PR"
    exit 0
fi

pushd ${DUNE_BUILD_DIR}/${MY_MODULE}
COVERAGE_INFO=${PWD}/coverage.info
lcov --directory . --output-file ${COVERAGE_INFO} --ignore-errors gcov -c
for d in "dune-common" "dune-pybindxi" "dune-geometry"  "dune-istl"  "dune-grid" "dune-alugrid"  "dune-uggrid"  "dune-localfunctions" ; do
    lcov --directory . --output-file ${COVERAGE_INFO} -r ${COVERAGE_INFO} "${SUPERDIR}/${d}/*"
done
lcov --directory . --output-file ${COVERAGE_INFO} -r ${COVERAGE_INFO} "${SUPERDIR}/${MY_MODULE}/dune/xt/*/test/*"
cd ${SUPERDIR}/${MY_MODULE}
bash <(curl -s https://codecov.io/bash) -p ${SUPERDIR}/${MY_MODULE} -Z -K -v \
  -X gcov -X coveragepy -F ctest -f ${COVERAGE_INFO} -t ${CODECOV_TOKEN}
popd
