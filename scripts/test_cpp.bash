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

# rm -rf ${DUNE_BUILD_DIR}
# ${SRC_DCTRL} ${BLD} --module=${MY_MODULE} all
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
# ${SRC_DCTRL} ${BLD} --only=${MY_MODULE} bexec ${BUILD_CMD} ${HEADERCHECK}

cp ${DUNE_BUILD_DIR}/${MY_MODULE}/${MY_MODULE//-/\/}/test/*xml ${HOME}/testresults/
