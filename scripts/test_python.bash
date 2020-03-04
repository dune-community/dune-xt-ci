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
#   René Fritze    (2018)
#   Tobias Leibner (2018)
# ~~~

set -e
set -x

source ${SUPERDIR}/scripts/bash/retry_command.bash

rm -rf ${DUNE_BUILD_DIR}
${SRC_DCTRL} ${BLD} --module=${MY_MODULE} all
${SRC_DCTRL} ${BLD} --only=${MY_MODULE} bexec ${BUILD_CMD}
${SRC_DCTRL} ${BLD} --only=${MY_MODULE} bexec ${BUILD_CMD} bindings
${SRC_DCTRL} ${BLD} --only=${MY_MODULE} bexec ${BUILD_CMD} test_python

cp ${DUNE_BUILD_DIR}/${MY_MODULE}/python/pytest_results.xml ${HOME}/testresults/

if [ "${SYSTEM_PULLREQUEST_ISFORK}" == "True" ] ; then
    echo "Coverage reporting disabled for forked repo/PR"
    exit 0
fi

cd ${SUPERDIR}/${MY_MODULE}
bash <(curl -s https://codecov.io/bash) -p ${SUPERDIR}/${MY_MODULE} -K -Z -v \
  -X gcov -F pytest -t ${CODECOV_TOKEN}
