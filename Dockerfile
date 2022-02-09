# Copyright 2020 Coinbase, Inc.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

# Build eunod
FROM ubuntu:18.04 as eunod-builder

RUN mkdir -p /app \
  && chown -R nobody:nogroup /app
WORKDIR /app

# Source: https://github.com/Euno/eunowallet/blob/master/doc/build-unix.md
RUN apt-get update && apt-get install -y make gcc g++ autoconf autotools-dev bsdmainutils build-essential git libboost-all-dev libcurl4-openssl-dev libdb++-dev libevent-dev libssl-dev libtool pkg-config python python-pip libzmq3-dev zlib1g-dev libseccomp-dev libcap-dev libncap-dev wget libcanberra-gtk-module automake python3 obfs4proxy libncap-dev

RUN git clone https://github.com/Euno/eunowallet 

RUN cd eunowallet \
  && cd depends \
  && make \
  && cd.. \
  && ./autogen.sh \
  && ./configure --disable-tests --without-miniupnpc --without-gui --with-incompatible-bdb --disable-hardening --disable-zmq --disable-bench --disable-wallet --disable-man --disable-shared \
  && make

RUN mv eunowallet/src/eunod /app/eunod \
  && rm -rf euno

# Build Rosetta Server Components
FROM ubuntu:18.04 as rosetta-builder

RUN mkdir -p /app \
  && chown -R nobody:nogroup /app
WORKDIR /app

RUN apt-get update && apt-get install -y curl make gcc g++
ENV GOLANG_VERSION 1.15.5
ENV GOLANG_DOWNLOAD_SHA256 9a58494e8da722c3aef248c9227b0e9c528c7318309827780f16220998180a0d
ENV GOLANG_DOWNLOAD_URL https://golang.org/dl/go$GOLANG_VERSION.linux-amd64.tar.gz

RUN curl -fsSL "$GOLANG_DOWNLOAD_URL" -o golang.tar.gz \
  && echo "$GOLANG_DOWNLOAD_SHA256  golang.tar.gz" | sha256sum -c - \
  && tar -C /usr/local -xzf golang.tar.gz \
  && rm golang.tar.gz

ENV GOPATH /go
ENV PATH $GOPATH/bin:/usr/local/go/bin:$PATH
RUN mkdir -p "$GOPATH/src" "$GOPATH/bin" && chmod -R 777 "$GOPATH"

# Use native remote build context to build in any directory
COPY . src 
RUN cd src \
  && go build \
  && cd .. \
  && mv src/rosetta-euno /app/rosetta-euno \
  && mv src/assets/* /app \
  && rm -rf src 

## Build Final Image
FROM ubuntu:18.04

RUN apt-get update && \
  apt-get install --no-install-recommends -y libevent-dev libboost-system-dev libboost-filesystem-dev libboost-test-dev libboost-thread-dev libcap-dev libboost-all-dev && \
  apt-get clean && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

RUN mkdir -p /app \
  && chown -R nobody:nogroup /app \
  && mkdir -p /data \
  && chown -R nobody:nogroup /data

WORKDIR /app

# Copy binary from eunod-builder
COPY --from=eunod-builder /app/eunod /app/eunod

# Copy binary from rosetta-builder
COPY --from=rosetta-builder /app/* /app/

# Set permissions for everything added to /app
RUN chmod -R 755 /app/*

CMD ["/app/rosetta-euno"]
