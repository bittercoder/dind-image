FROM golang:alpine as builder

COPY . /go/src/github.com/bittercoder/dind-image
ENV CGO_ENABLED 0
RUN mkdir /assets
RUN go build -o /assets/ecr-login github.com/bittercoder/dind-image/vendor/github.com/awslabs/amazon-ecr-credential-helper/ecr-login/cmd

FROM docker:stable-dind AS resource

# Install Docker Compose, bash, jq, ca-certs etc.
RUN apk --update --no-cache \        
        add bash jq ca-certificates curl device-mapper mkinitfs e2fsprogs e2fsprogs-extra iptables git py-pip 

RUN pip install docker-compose

COPY --from=builder /assets /opt/resource

# Put docker-credentials-ecr-login in the right location and set it as the creds store
RUN mv /opt/resource/ecr-login /usr/local/bin/docker-credential-ecr-login
RUN mkdir -p ~/.docker
RUN echo '{"credsStore":"ecr-login"}' >> ~/.docker/config.json

WORKDIR /src

# Include useful functions to start/stop docker daemon in garden-runc containers on Concourse CI
# Its usage would be something like: source /docker.lib.sh && start_docker "" "" "-g=$(pwd)/graph"
COPY docker-lib.sh /docker-lib.sh
