FROM alpine:3.18
RUN apk add --no-cache curl
ENTRYPOINT ["/bin/sh", "-c", "curl -s https://ifconfig.me"]
