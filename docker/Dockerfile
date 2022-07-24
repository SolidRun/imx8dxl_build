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
	apt-get -y install --no-install-recommends build-essential crossbuild-essential-arm64 wget make device-tree-compiler xz-utils sudo libssl-dev bison flex git bc ca-certificates; \
	:

# build environment
WORKDIR /work
COPY shflags /
COPY entry.sh /
ENTRYPOINT ["/bin/sh", "/entry.sh"]
