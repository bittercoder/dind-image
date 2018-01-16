FROM golang:alpine as builder

COPY . /go/src/github.com/bittercoder/dind-image
ENV CGO_ENABLED 0
RUN mkdir /assets
RUN go build -o /assets/ecr-login github.com/bittercoder/dind-image/vendor/github.com/awslabs/amazon-ecr-credential-helper/ecr-login/cmd

FROM alpine:3.4 AS resource
# https://github.com/mumoshu/dcind
# MAINTAINER Yusuke KUOKA <kuoka@chatwork.com>

ENV DOCKER_VERSION=1.13.1 \
    DOCKER_COMPOSE_VERSION=1.11.1 \
    ENTRYKIT_VERSION=0.4.0

# Install Docker, Docker Compose, bash, jq, ca-certs
RUN apk --update --no-cache \        
        add bash docker jq ca-certificates curl device-mapper mkinitfs e2fsprogs e2fsprogs-extra iptables && \
        curl https://get.docker.com/builds/Linux/x86_64/docker-${DOCKER_VERSION}.tgz | tar zx && \
        mv /docker/* /bin/ && chmod +x /bin/docker* \
    && \
        apk add py-pip && \
        pip install docker-compose==${DOCKER_COMPOSE_VERSION}

COPY --from=builder /assets /opt/resource
RUN mv /opt/resource/ecr-login /usr/local/bin/docker-credential-ecr-login

RUN curl -L https://github.com/progrium/entrykit/releases/download/v${ENTRYKIT_VERSION}/entrykit_${ENTRYKIT_VERSION}_Linux_x86_64.tgz | tar zxv
RUN mv ./entrykit /bin/entrykit
RUN chmod +x /bin/entrykit && entrykit --symlink

WORKDIR /src

RUN echo $'#!/bin/bash \n\
/bin/docker daemon' > /bin/docker-daemon && chmod +x /bin/docker-daemon

RUN echo $'#!/bin/bash \n\
docker info && \n\
/usr/bin/docker-compose pull && \n\
echo Cloning /var/lib/docker to /cached-graph... && \n\
ls -lah /var/lib/docker' > /bin/docker-compose-pull && chmod +x /bin/docker-compose-pull

ENV SWITCH_PULL="codep docker-daemon docker-compose-pull"
ENV SWITCH_SHELL=bash
ENV CODEP_DAEMON=/bin/docker\ daemon
ENV CODEP_COMPOSE=/usr/bin/docker-compose\ up

# Include useful functions to start/stop docker daemon in garden-runc containers on Concourse CI
# Its usage would be something like: source /docker.lib.sh && start_docker "" "" "-g=$(pwd)/graph"
COPY docker-lib.sh /docker-lib.sh

ENTRYPOINT ["entrykit", "-e"]
