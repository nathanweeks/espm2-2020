#syntax=docker/dockerfile:experimental
FROM alpine:3.12.0 AS gcc-builder

RUN apk add alpine-sdk

RUN set -o pipefail \
  && wget -qO - 'https://gitlab.alpinelinux.org/alpine/aports/-/archive/v3.12.0/aports-v3.12.0.tar.gz?path=main%2Fgcc' \
     | tar -xzf -

ENV REPODEST=/packages

RUN adduser -G abuild -D builder \
  && echo 'builder ALL=(ALL) NOPASSWD:ALL' >> /etc/sudoers \
  && mkdir ${REPODEST} \
  && chown -R builder:abuild ${REPODEST} aports-*

COPY --chown=builder ./src/aports-v3.12.0-main-gcc.patch /

USER builder

RUN abuild-keygen -a -i \
  && cd aports-*/main/gcc \
  && patch -p3 < /aports-v3.12.0-main-gcc.patch \
  && abuild -r

FROM alpine:3.12.0 AS gcc-pr87939

# omit g++, gcc-doc, and APKINDEX.tar.gz
RUN --mount=src=/packages,dst=/packages,from=gcc-builder apk add --no-cache --allow-untrusted /packages/main/x86_64/gcc-[0-9]* /packages/main/x86_64/gfortran* /packages/main/x86_64/lib*

FROM gcc-pr87939 AS ulfm2-builder

RUN apk add --no-cache \
  autoconf \
  automake \
  flex \
  git \
  libtool \
  make \
  musl-dev \
  perl

WORKDIR /src

RUN git init \
  && git remote add origin https://bitbucket.org/icldistcomp/ulfm2.git \
  && git fetch --depth=1 origin 0823ee3e57d24d11ee1c8ba232c601707645a7a8  \
  && git checkout 0823ee3e57d24d11ee1c8ba232c601707645a7a8 \
  && git submodule update --init --recursive --depth=1 \
  && find . -name topology-linux.c -exec sed -i.bak '/#include <linux\/unistd.h>/s|^|//|' {} + \
  && ./autogen.pl

RUN sh ./configure --disable-io-romio --enable-mpirun-prefix-by-default --disable-man-pages \
  && make -j \
  && make install

FROM gcc-pr87939 AS ulfm2

# TODO: gdb, musl-dbg: allow stack traces when debugging
RUN apk add --no-cache \
  musl-dev \
  dropbear-ssh

COPY --from=ulfm2-builder /usr/local/ /usr/local/

# environment variables for local testing
ENV OMPI_ALLOW_RUN_AS_ROOT=1 \
    OMPI_ALLOW_RUN_AS_ROOT_CONFIRM=1 \
    OMPI_MCA_btl='tcp,self' \
    OMPI_MCA_rmaps_base_oversubscribe=1

FROM ulfm2 AS opencoarrays-ft-builder

RUN apk add --no-cache \
  bash \
  cmake \
  make \
  perl

COPY ./src/OpenCoarrays-ft /OpenCoarrays-ft

# set to "Debug" for debug build; defaults to Release
ARG BUILD_TYPE

RUN mkdir OpenCoarrays-ft/OpenCoarrays-ft-build \
  && cd OpenCoarrays-ft/OpenCoarrays-ft-build \
  && cmake .. -DCMAKE_INSTALL_PREFIX=/opt/opencoarrays-ft -DCMAKE_BUILD_TYPE=${BUILD_TYPE:-RelWithDebInfo} -DCAF_ENABLE_FAILED_IMAGES=TRUE -DGFORTRAN_PR87939=TRUE \
  && make \
  && make install/fast

FROM opencoarrays-ft-builder AS opencoarrays-ft-test
WORKDIR /OpenCoarrays-ft/OpenCoarrays-ft-build
RUN make test

FROM ulfm2 AS opencoarrays-ft
# Shifter needs user's host login shell inside the container for ssh to function
# https://pubs.cray.com/bundle/XC_Series_Shifter_User_Guide_CLE70UP00_S-2571/page/ssh_Use_Within_the_Shifter_Environment.html
RUN apk add --no-cache bash

COPY --from=opencoarrays-ft-builder /opt/opencoarrays-ft /opt/opencoarrays-ft

ENV PATH=/opt/opencoarrays-ft/bin:${PATH}
ARG OMPI_MCA_mpi_ft_verbose
ENV OMPI_MCA_mpi_ft_verbose=${OMPI_MCA_mpi_ft_verbose:-0}
