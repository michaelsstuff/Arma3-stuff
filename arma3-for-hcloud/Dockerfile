FROM golang:alpine
ENV HTTP_PROXY "http://10.0.75.1:8080"
ENV HTTPS_PROXY "http://10.0.75.1:8080"

RUN apk update \
	&& apk add git
RUN go get -u github.com/hetznercloud/cli/cmd/hcloud

ENTRYPOINT ["/go/bin/hcloud"]
