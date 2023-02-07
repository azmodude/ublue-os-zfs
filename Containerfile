# Based on https://github.com/coreos/layering-examples
# Needs to be set to the Fedora version
# on CoreOS stable stream, as it is our base image.
ARG FEDORA_MAJOR_VERSION=37

FROM quay.io/fedora-ostree-desktops/silverblue:${FEDORA_MAJOR_VERSION} as kernel-query
#We can't use the `uname -r` as it will pick up the host kernel version
RUN rpm -qa kernel --queryformat '%{VERSION}-%{RELEASE}.%{ARCH}' > /kernel-version.txt

# Using https://openzfs.github.io/openzfs-docs/Developer%20Resources/Custom%20Packages.html
FROM registry.fedoraproject.org/fedora:${FEDORA_MAJOR_VERSION} as builder

COPY --from=kernel-query /kernel-version.txt /kernel-version.txt
ARG FEDORA_MAJOR_VERSION=37
RUN dnf install -y jq dkms gcc make autoconf automake libtool rpm-build libtirpc-devel libblkid-devel \
  libuuid-devel libudev-devel openssl-devel zlib-devel libaio-devel libattr-devel elfutils-libelf-devel \
  kernel-$(cat /kernel-version.txt) kernel-modules-$(cat /kernel-version.txt) kernel-devel-$(cat /kernel-version.txt) \
  python3 python3-devel python3-setuptools python3-cffi libffi-devel git ncompress libcurl-devel
WORKDIR /
# Uses project_id from: https://release-monitoring.org/project/11706/
RUN curl "https://release-monitoring.org/api/v2/versions/?project_id=11706" | jq --raw-output '.stable_versions[0]' >> /zfs-version.txt
RUN curl -L -O https://github.com/openzfs/zfs/releases/download/zfs-$(cat /zfs-version.txt)/zfs-$(cat /zfs-version.txt).tar.gz && \
  tar xzf zfs-$(cat /zfs-version.txt).tar.gz && mv zfs-$(cat /zfs-version.txt) zfs
WORKDIR /zfs
RUN bash -c "./configure -with-linux=/usr/src/kernels/$(cat /kernel-version.txt)/ -with-linux-obj=/usr/src/kernels/$(cat /kernel-version.txt)/" && \
  make -j$(nproc) rpm-utils rpm-kmod
RUN mkdir -p /zfs-current && \
  mv zfs-$(cat /zfs-version.txt)-[0-9].fc${FEDORA_MAJOR_VERSION}.$(uname -p).rpm /zfs-current && \
  mv kmod-zfs-$(cat /kernel-version.txt)-$(cat /zfs-version.txt)-[0-9].fc${FEDORA_MAJOR_VERSION}.$(uname -p).rpm /zfs-current && \
  mv libnvpair3-$(cat /zfs-version.txt)-[0-9].fc${FEDORA_MAJOR_VERSION}.$(uname -p).rpm /zfs-current && \
  mv libuutil3-$(cat /zfs-version.txt)-[0-9].fc${FEDORA_MAJOR_VERSION}.$(uname -p).rpm /zfs-current && \
  mv libzfs5-$(cat /zfs-version.txt)-[0-9].fc${FEDORA_MAJOR_VERSION}.$(uname -p).rpm /zfs-current && \
  mv libzpool5-$(cat /zfs-version.txt)-[0-9].fc${FEDORA_MAJOR_VERSION}.$(uname -p).rpm /zfs-current
