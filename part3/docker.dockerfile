FROM alpine:3.18
RUN apk update && apk upgrade && rm -rf /var/cache/apk/*
RUN apk add --no-cache curl
ENTRYPOINT ["/bin/sh", "-c", "curl -s https://ifconfig.me"]
