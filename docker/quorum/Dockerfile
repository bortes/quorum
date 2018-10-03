FROM ubuntu:16.04 AS builder

# definir versao do GO LANG
ENV GO_VERSION="go1.9.3.linux-amd64"

# definir versao do Quorum
ENV QUORUM_VERSION="2.0.2"

# definir versao do Constellation
ENV CONSTELLATION_VERSION="0.3.2"
ENV CONSTELLATION_RELEASE="constellation-$CONSTELLATION_VERSION-ubuntu1604"

# definir variavies para geracao dos artefatos
ENV GOROOT=/opt/google/go

RUN    apt-get update

# criar repositorio para artefatos
RUN    mkdir -p /build 

# instalar golang
RUN    apt-get install --yes wget
RUN    mkdir -p /opt/google
RUN    wget -q https://dl.google.com/go/$GO_VERSION.tar.gz -P /opt/google
RUN    tar xfz /opt/google/$GO_VERSION.tar.gz -C /opt/google/
RUN    find /opt/google/go/bin/ -type f -executable -exec cp  {} /usr/local/bin/ \;

# instalar quorum
RUN    apt-get install --yes git make gcc
RUN    mkdir -p /opt

RUN    git -C /opt clone https://github.com/jpmorganchase/quorum.git
RUN    git -C /opt/quorum checkout tags/v$QUORUM_VERSION
RUN    make -C /opt/quorum all
RUN    find /opt/quorum/build/bin/ -type f -executable -exec cp  {} /build \;

RUN    apt-get update
# criar repositorio para artefatos
RUN    mkdir -p /build
# instalar constellation 
RUN    apt-get install --yes wget xz-utils
RUN    mkdir -p /opt
RUN    wget -q https://github.com/jpmorganchase/constellation/releases/download/v$CONSTELLATION_VERSION/$CONSTELLATION_RELEASE.tar.xz -P /opt
RUN    tar xfJ /opt/$CONSTELLATION_RELEASE.tar.xz -C /opt/
RUN    mv /opt/$CONSTELLATION_RELEASE /opt/constellation
RUN    find /opt/constellation/ -type f -executable -exec cp  {} /build \;

# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

FROM ubuntu:16.04 AS deployer

# lista as portas que serao expostas
#   8545    API geth
#   30303   rede geth
#   50400   consenso RAFT geth
#   9001    API constelation
# EXPOSE 8545 30303/udp 50400 9001

# copiar artefatos
COPY --from=builder /build /usr/local/bin/

# copiar scrtips
COPY ./controller.sh /usr/local/bin/

# criar usuario
RUN    addgroup quorum \
    && adduser --ingroup quorum --disabled-login --gecos "Quorum container user" quorum \
# criar estrutura container
    && mkdir -p \
        /var/run/supervisor \
        /var/opt/nodes \
        /etc/opt/quorum \ 
        /var/opt/quorum \
        /etc/opt/constellation \
        /var/opt/constellation \
    && chown -R quorum:quorum \
        /usr/local/bin/controller.sh \
        /var/run/supervisor \
        /var/opt/nodes \
        /etc/opt/quorum \
        /var/opt/quorum \
        /etc/opt/constellation \
        /var/opt/constellation \
# instalar dependencias
    && apt-get update \
    && apt-get install --no-install-recommends --yes \
# https://github.com/jpmorganchase/constellation/issues/102#issuecomment-409469971
        netbase \
# https://github.com/jpmorganchase/constellation#prerequisites
        libsodium-dev libleveldb-dev libgmp10 \
# instalas pacotes extras
        dnsutils curl supervisor vim iputils-ping iproute2 netcat \
    &&  apt-get autoremove --yes \
    && rm -rf /var/lib/apt/lists/*

COPY ./docker-entrypoint.sh /usr/local/bin/

# troca usuario
USER quorum
WORKDIR /home/quorum

# habilita o script para execucao inicial
ENTRYPOINT ["/usr/local/bin/docker-entrypoint.sh"]
