FROM golang:alpine

RUN apk update \
	&& apk add git bash openssh openssl
RUN go get -u github.com/hetznercloud/cli/cmd/hcloud

WORKDIR /root
COPY id_ecdsa id_ecdsa.pub /root/.ssh/
COPY entrypoint.sh /root/
ENTRYPOINT ["/bin/bash"]
