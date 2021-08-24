ARG CC
ARG COMMIT
ARG BASE
ARG PROJECT
FROM ${PROJECT}/base_${BASE}_${CC}:${COMMIT}

WORKDIR ${SUPERDIR}

ARG project_name
ENV MY_MODULE=${project_name}

# run our local scripts look for an OPTS env entry
# and ensure ${MY_MODULE} from checkout is used via clean mount point
# and removes xt-la, xt-grid, xt-functions for xt-common, etc
RUN set -euxo pipefail && \
    ${SRC_DCTRL} ${BLD} all || (cat ${DUNE_BUILD_DIR}/*/CMakeFiles/CMakeError.log; false) && \
    ${SRC_DCTRL} ${BLD} bexec "${BUILD_CMD} bindings || echo no bindings" && \
    rm -rf ${MY_MODULE}  && \
    mkdir ${MY_MODULE}


# THE END
ENV DEBIAN_FRONTEND teletype
