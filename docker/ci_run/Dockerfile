ARG BASE
ARG REGISTRY
FROM $REGISTRY/$BASE

ADD . ${SUPERDIR}/${MY_MODULE}/
RUN cd ${SUPERDIR} && \
    echo ${SRC_DCTRL} ${BLD} --only=${MY_MODULE} all && \
    ${SRC_DCTRL} ${BLD} --only=${MY_MODULE} all
