FROM ubuntu:22.04

MAINTAINER gerstl <gerstl@ece.utexas.edu>

ARG INSTALL_ROOT=/opt
ARG SYSTEMC_VERSION=2.3.3
ARG SYSTEMC_ARCHIVE=systemc-2.3.3.tar.gz
ARG XILINX_VERSION=2022.1

# build with "docker build --build-arg XILINX_VERSION=2022.1 -t qemu-systemc:2022.1 ."

# install dependences:

RUN apt-get update &&  DEBIAN_FRONTEND=noninteractive apt-get install -y -q \
    build-essential \
    ninja-build \
    ccache \
    clang \
    cpio \
    chrpath \
    autoconf \
    flex \
    bison \
    libselinux1 \
    gnupg \
    wget \
    socat \
    gcc \
    gettext \
    git \
    glusterfs-common \
    gzip \
    unzip \
    libaio-dev \
    libattr1-dev \
    libbrlapi-dev \
    libbz2-dev \
    libcacard-dev \
    libcap-ng-dev \
    libcurl4-gnutls-dev \
    libdrm-dev \
    libepoxy-dev \
    libfdt-dev \
    libgbm-dev \
    libsdl1.2-dev \
    libglib2.0-dev \
    lib32z1-dev \
    libgtk2.0-0 \
    libgtk-3-dev \
    libibverbs-dev \
    libiscsi-dev \
    libjemalloc-dev \
    libjpeg-turbo8-dev \
    liblzo2-dev \
    libncurses5-dev \
    libncursesw5-dev \
    libnfs-dev \
    libnss3-dev \
    libnuma-dev \
    libpixman-1-dev \
    librados-dev \
    librbd-dev \
    librdmacm-dev \
    libsasl2-dev \
    libsdl2-dev \
    libseccomp-dev \
    libsnappy-dev \
    libspice-protocol-dev \
    libspice-server-dev \
    libssh-dev \
    libssl-dev \
    libusb-1.0-0-dev \
    libusbredirhost-dev \
    libvdeplug-dev \
    libvte-2.91-dev \
    libxen-dev \
    libzstd-dev \
    libgcrypt20-dev \ 
    locales \
    lsb-release \
    libtool \
    libtool-bin \
    make \
    rsync \
    bc \
    sudo \
    tofrodos \
    iproute2 \
    gawk \
    net-tools \
    expect \
    python3-yaml \
    python3-sphinx \
    sparse \
    screen \
    tftpd \
    pax \
    diffstat \
    vim-tiny \
    xvfb \
    xterm \
    texinfo \
    update-inetd \
    xfslibs-dev \
    device-tree-compiler \
 && apt-get clean \
 && rm -rf /var/lib/apt/lists/*

RUN locale-gen en_US.UTF-8 && update-locale

# make a xilinx user
RUN adduser --disabled-password --gecos '' xilinx && \
  usermod -aG sudo xilinx && \
  echo "xilinx ALL=(ALL) NOPASSWD: ALL" >> /etc/sudoers

# run the SystemC install
RUN cd /home/xilinx && \
  wget https://www.accellera.org/images/downloads/standards/systemc/${SYSTEMC_ARCHIVE} && \
  tar xzf ${SYSTEMC_ARCHIVE} && \
  mkdir systemc-${SYSTEMC_VERSION}/objdir && \
  cd systemc-${SYSTEMC_VERSION}/objdir && \
  ../configure --prefix=${INSTALL_ROOT}/systemc-${SYSTEMC_VERSION} && \
  make && \
  make install && \
  cd /home/xilinx && \
  rm -f ${SYSTEMC_ARCHIVE} && \
  rm -rf systemc-${SYSTEMC_VERSION}

# install QEMU 
#  had to add --enable-gcrypt as libary dependency detection did not work 
#  automatically. This is for the vhost-crypt devices (I believe)
#  this also brought dependency of libgcrypt20-dev (see above)
RUN cd /home/xilinx && \
  git clone -b xlnx_rel_v${XILINX_VERSION} --depth 1 https://github.com/Xilinx/qemu.git && \
  cd qemu && \
  mkdir build && \ 
  cd build && \ 
  ../configure --target-list=aarch64-softmmu,microblazeel-softmmu --enable-fdt --disable-kvm --disable-xen --enable-gcrypt&& \
  make && \
  make install && \
  cd /home/xilinx && \
  rm -rf qemu

# make /bin/sh symlink to bash instead of dash:
RUN echo "dash dash/sh boolean false" | debconf-set-selections
RUN DEBIAN_FRONTEND=noninteractive dpkg-reconfigure dash

USER xilinx
ENV HOME /home/xilinx
ENV LANG en_US.UTF-8
WORKDIR /home/xilinx

# add SystemC to path
RUN echo "" >> /home/xilinx/.bashrc && \
  echo "export LD_LIBRARY_PATH=${INSTALL_ROOT}/systemc-${SYSTEMC_VERSION}/lib-linux64" >> /home/xilinx/.bashrc

# clone the Xilinx SystemC co-simulation demo
RUN cd /home/xilinx && \
  git clone --depth 1 https://github.com/Xilinx/systemctlm-cosim-demo.git && \
  cd systemctlm-cosim-demo && \
  git submodule update --init libsystemctlm-soc && \
  sed -i -e 's|/usr/local/systemc-2.3.2|'${INSTALL_ROOT}'/systemc-'${SYSTEMC_VERSION}'|g' Makefile && \
  make && \
  make TARGETS= clean

# Optional: clone the device trees for co-simulation
#RUN cd /home/xilinx && \
#  git clone -b xilinx-v${XILINX_VERSION} --depth 1 https://github.com/Xilinx/qemu-devicetrees && \
#  cd qemu-devicetrees && \
#  make

# copy QEMU boot script
COPY qemu-boot /home/xilinx/
RUN sudo chown xilinx.xilinx /home/xilinx/qemu-boot && \
  mkdir tmp

