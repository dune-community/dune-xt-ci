ARG BASE
FROM dunecommunity/testing-base_${BASE}

ARG COMMIT

RUN git clone https://github.com/dune-community/dune-xt-super.git ${SUPERDIR} && \
    cd ${SUPERDIR} && \
    git checkout ${COMMIT} && \
    git submodule foreach git reset --hard && \
    git submodule update --init --recursive && \
    git submodule status
WORKDIR ${SUPERDIR}

ARG CC
ARG CXX

ENV CC=${CC} \
    CXX=${CXX}

# run our local scripts look for an OPTS env entry
RUN ./bin/download_external_libraries.py 1> /dev/null && \
    ./bin/build_external_libraries.py 1> /dev/null

RUN . environments/${DXT_ENVIRONMENT}/PATH.sh