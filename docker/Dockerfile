# use debian base
FROM debian:bullseye-slim

# retry at least 3 times to succeed on sketchy connections
RUN printf 'Acquire::http { Proxy "%s"; };\n' $APTPROXY | tee -a /etc/apt/apt.conf.d/proxy

# apt proxy (optional)
ARG APTPROXY=
RUN printf 'Acquire::Retries 3;\n' | tee -a /etc/apt/apt.conf.d/retry || true

# update
RUN set -e; \
	apt-get update; \
	apt-get -y upgrade; \
	:

RUN set -e; \
	apt-get update; \
	apt-get --no-install-recommends -y install bc bison build-essential ca-certificates crossbuild-essential-arm64 crossbuild-essential-armhf debootstrap device-tree-compiler e2tools fakeroot fdisk flex git kmod libncurses-dev libssl-dev make python3 python3-pycryptodome python3-cryptography python3-pyelftools qemu-system-arm sudo wget xz-utils; \
	:

# build environment
WORKDIR /work
COPY shflags /
COPY entry.sh /
ENTRYPOINT ["/bin/sh", "/entry.sh"]
