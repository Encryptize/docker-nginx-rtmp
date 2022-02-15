FROM alpine:3.15 as builder

# Versions of nginx and nginx-rtmp-module to use
ENV NGINX_VERSION nginx-1.21.6
ENV NGINX_RTMP_MODULE_VERSION 1.2.2

# Install dependencies
RUN apk update && \ 
    apk add build-base pcre pcre-dev openssl openssl-dev zlib zlib-dev wget

# Download and decompress nginx
RUN mkdir -p /tmp/build/nginx && \
    cd /tmp/build/nginx && \
    wget -O ${NGINX_VERSION}.tar.gz https://nginx.org/download/${NGINX_VERSION}.tar.gz && \
    tar -zxf ${NGINX_VERSION}.tar.gz

# Download and decompress RTMP module
RUN mkdir -p /tmp/build/nginx-rtmp-module && \
    cd /tmp/build/nginx-rtmp-module && \
    wget -O nginx-rtmp-module-${NGINX_RTMP_MODULE_VERSION}.tar.gz https://github.com/arut/nginx-rtmp-module/archive/v${NGINX_RTMP_MODULE_VERSION}.tar.gz && \
    tar -zxf nginx-rtmp-module-${NGINX_RTMP_MODULE_VERSION}.tar.gz

# Build and install nginx
RUN cd /tmp/build/nginx/${NGINX_VERSION} && \
    ./configure \
        --sbin-path=/usr/local/sbin/nginx \
        --conf-path=/etc/nginx/nginx.conf \
        --error-log-path=/var/log/nginx/error.log \
        --pid-path=/var/run/nginx/nginx.pid \
        --lock-path=/var/lock/nginx/nginx.lock \
        --http-log-path=/var/log/nginx/access.log \
        --http-client-body-temp-path=/tmp/nginx-client-body \
        --with-http_ssl_module \
        --with-threads \
        --with-ipv6 \
        --add-module=/tmp/build/nginx-rtmp-module/nginx-rtmp-module-${NGINX_RTMP_MODULE_VERSION} && \
    make -j $(getconf _NPROCESSORS_ONLN) && \
    make install && \
    mkdir /var/lock/nginx && \
    rm -rf /tmp/build

FROM alpine:3.15

RUN apk update && \
    apk add ca-certificates openssl pcre && \
    rm -rf /var/cache/apk/*

COPY --from=builder /etc/nginx /etc/nginx
COPY --from=builder /run/nginx /run/nginx
COPY --from=builder /usr/local/nginx /usr/local/nginx
COPY --from=builder /usr/local/sbin/nginx /usr/local/sbin/nginx
COPY --from=builder /var/log/nginx /var/log/nginx

# Forward logs to Docker
RUN ln -sf /dev/stdout /var/log/nginx/access.log && \
    ln -sf /dev/stderr /var/log/nginx/error.log

COPY nginx.conf /etc/nginx/nginx.conf

RUN mkdir -p /www
ADD static /www/static

EXPOSE 80/tcp
EXPOSE 1935/tcp

VOLUME [ "/dash" ]

CMD ["nginx", "-g", "daemon off;"]