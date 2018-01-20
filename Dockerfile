FROM golang:alpine as builder

COPY . /go/src/github.com/bittercoder/dind-image
ENV CGO_ENABLED 0
RUN mkdir /assets
RUN go build -o /assets/ecr-login github.com/bittercoder/dind-image/vendor/github.com/awslabs/amazon-ecr-credential-helper/ecr-login/cmd

FROM alpine:latest AS resource

ENV ENTRYKIT_VERSION=0.4.0

# Install Docker, Docker Compose, bash, jq, ca-certs
RUN apk --update --no-cache \        
        add bash docker jq ca-certificates curl device-mapper mkinitfs e2fsprogs e2fsprogs-extra iptables docker && \        
        apk add py-pip && \
        pip install docker-compose

COPY --from=builder /assets /opt/resource

#put docker-credentials-ecr-login in the right location and set it as the creds store
RUN mv /opt/resource/ecr-login /usr/local/bin/docker-credential-ecr-login
RUN mkdir -p ~/.docker
RUN echo '{"credsStore":"ecr-login"}' >> ~/.docker/config.json

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
