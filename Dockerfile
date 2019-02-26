FROM alpine:3.4

MAINTAINER habibiefaried@gmail.com

ENV NGINX_VERSION=1.11.2 \
     PAGESPEED_VERSION=1.11.33.4 \
     LIBPNG_VERSION=1.2.56 \
     MAKE_J=7 \
     PAGESPEED_ENABLE=on

RUN apk upgrade --no-cache --update && \
    apk add --no-cache --update \
        bash \
        ca-certificates \
        libuuid \
        apr \
        apr-util \
        libjpeg-turbo \
        icu \
        icu-libs \
        openssl \
        pcre \
        zlib \
        git \
        vim

RUN cd /root && git clone https://github.com/vozlt/nginx-module-vts.git && cd /

RUN git clone https://github.com/nbs-system/naxsi.git "/root/nginx-naxsi"

COPY src/nginx/src/http/ngx_http_header_filter_module.c /root/ngx_http_header_filter_module.c
COPY src/nginx/src/core/nginx.h /root/nginx.h

RUN set -x && \
    apk --no-cache add -t .build-deps \
        apache2-dev \
        apr-dev \
        apr-util-dev \
        build-base \
        curl \
        icu-dev \
        libjpeg-turbo-dev \
        linux-headers \
        gperf \
        openssl-dev \
        pcre-dev \
        python \
        zlib-dev && \
    # Build libpng
    cd /tmp && \
    curl -L http://prdownloads.sourceforge.net/libpng/libpng-${LIBPNG_VERSION}.tar.gz | tar -zx && \
    cd /tmp/libpng-${LIBPNG_VERSION} && \
    ./configure --build=$CBUILD --host=$CHOST --prefix=/usr --enable-shared --with-libpng-compat && \
    make -j${MAKE_J} install V=0 && \
    # Build PageSpeed
    cd /tmp && \
    curl -L https://dl.google.com/dl/linux/mod-pagespeed/tar/beta/mod-pagespeed-beta-${PAGESPEED_VERSION}-r0.tar.bz2 | tar -jx && \
    curl -L https://github.com/pagespeed/ngx_pagespeed/archive/v${PAGESPEED_VERSION}-beta.tar.gz | tar -zx && \
    cd /tmp/modpagespeed-${PAGESPEED_VERSION} && \
    curl -L https://raw.githubusercontent.com/lagun4ik/docker-nginx-pagespeed/master/patches/automatic_makefile.patch | patch -p1 && \
    curl -L https://raw.githubusercontent.com/lagun4ik/docker-nginx-pagespeed/master/patches/libpng_cflags.patch | patch -p1 && \
    curl -L https://raw.githubusercontent.com/lagun4ik/docker-nginx-pagespeed/master/patches/pthread_nonrecursive_np.patch | patch -p1 && \
    curl -L https://raw.githubusercontent.com/lagun4ik/docker-nginx-pagespeed/master/patches/rename_c_symbols.patch | patch -p1 && \
    curl -L https://raw.githubusercontent.com/lagun4ik/docker-nginx-pagespeed/master/patches/stack_trace_posix.patch | patch -p1 && \
    ./generate.sh -D use_system_libs=1 -D _GLIBCXX_USE_CXX11_ABI=0 -D use_system_icu=1 && \
    cd /tmp/modpagespeed-${PAGESPEED_VERSION}/src && \
    make -j${MAKE_J} BUILDTYPE=Release CXXFLAGS=" -I/usr/include/apr-1 -I/tmp/libpng-${LIBPNG_VERSION} -fPIC -D_GLIBCXX_USE_CXX11_ABI=0" CFLAGS=" -I/usr/include/apr-1 -I/tmp/libpng-${LIBPNG_VERSION} -fPIC -D_GLIBCXX_USE_CXX11_ABI=0" && \
    cd /tmp/modpagespeed-${PAGESPEED_VERSION}/src/pagespeed/automatic/ && \
    make -j${MAKE_J} psol BUILDTYPE=Release CXXFLAGS=" -I/usr/include/apr-1 -I/tmp/libpng-${LIBPNG_VERSION} -fPIC -D_GLIBCXX_USE_CXX11_ABI=0" CFLAGS=" -I/usr/include/apr-1 -I/tmp/libpng-${LIBPNG_VERSION} -fPIC -D_GLIBCXX_USE_CXX11_ABI=0" && \
    mkdir -p /tmp/incubator-pagespeed-ngx-${PAGESPEED_VERSION}-beta/psol && \
    mkdir -p /tmp/incubator-pagespeed-ngx-${PAGESPEED_VERSION}-beta/psol/lib/Release/linux/x64 && \
    mkdir -p /tmp/incubator-pagespeed-ngx-${PAGESPEED_VERSION}-beta/psol/include/out/Release && \
    cp -r /tmp/modpagespeed-${PAGESPEED_VERSION}/src/out/Release/obj /tmp/incubator-pagespeed-ngx-${PAGESPEED_VERSION}-beta/psol/include/out/Release/ && \
    cp -r /tmp/modpagespeed-${PAGESPEED_VERSION}/src/net /tmp/incubator-pagespeed-ngx-${PAGESPEED_VERSION}-beta/psol/include/ && \
    cp -r /tmp/modpagespeed-${PAGESPEED_VERSION}/src/testing /tmp/incubator-pagespeed-ngx-${PAGESPEED_VERSION}-beta/psol/include/ && \
    cp -r /tmp/modpagespeed-${PAGESPEED_VERSION}/src/pagespeed /tmp/incubator-pagespeed-ngx-${PAGESPEED_VERSION}-beta/psol/include/ && \
    cp -r /tmp/modpagespeed-${PAGESPEED_VERSION}/src/third_party /tmp/incubator-pagespeed-ngx-${PAGESPEED_VERSION}-beta/psol/include/ && \
    cp -r /tmp/modpagespeed-${PAGESPEED_VERSION}/src/tools /tmp/incubator-pagespeed-ngx-${PAGESPEED_VERSION}-beta/psol/include/ && \
    cp -r /tmp/modpagespeed-${PAGESPEED_VERSION}/src/url /tmp/incubator-pagespeed-ngx-${PAGESPEED_VERSION}-beta/psol/include/ && \
    cp -r /tmp/modpagespeed-${PAGESPEED_VERSION}/src/pagespeed/automatic/pagespeed_automatic.a /tmp/incubator-pagespeed-ngx-${PAGESPEED_VERSION}-beta/psol/lib/Release/linux/x64 && \
    # Build Nginx with support for PageSpeed
    cd /tmp && \
    curl -L http://nginx.org/download/nginx-${NGINX_VERSION}.tar.gz | tar -zx && \
    cd /tmp/nginx-${NGINX_VERSION} && \
    rm /tmp/nginx-${NGINX_VERSION}/src/http/ngx_http_header_filter_module.c && \
    rm /tmp/nginx-${NGINX_VERSION}/src/core/nginx.h && \
    cp /root/ngx_http_header_filter_module.c /tmp/nginx-${NGINX_VERSION}/src/http/ngx_http_header_filter_module.c && \
    cp /root/nginx.h /tmp/nginx-${NGINX_VERSION}/src/core/nginx.h && \
    LD_LIBRARY_PATH=/tmp/modpagespeed-${PAGESPEED_VERSION}/usr/lib ./configure \
        --sbin-path=/usr/sbin \
        --modules-path=/usr/lib/nginx \
        --with-http_ssl_module \
        --with-http_gzip_static_module \
        --with-file-aio \
        --with-http_v2_module \
        --with-http_realip_module \
        --without-http_autoindex_module \
        --without-http_browser_module \
        --without-http_geo_module \
        --without-http_memcached_module \
        --without-http_userid_module \
        --without-mail_pop3_module \
        --without-mail_imap_module \
        --without-mail_smtp_module \
        --without-http_split_clients_module \
        --without-http_uwsgi_module \
        --without-http_scgi_module \
        --without-http_upstream_ip_hash_module \
        --with-http_sub_module \
        --with-http_gunzip_module \
        --with-http_secure_link_module \
        --with-threads \
        --with-stream \
        --with-stream_ssl_module \
        --prefix=/etc/nginx \
        --conf-path=/etc/nginx/nginx.conf \
        --http-log-path=/var/log/nginx/access.log \
        --error-log-path=/var/log/nginx/error.log \
        --pid-path=/var/run/nginx.pid \
        --add-module=/tmp/incubator-pagespeed-ngx-${PAGESPEED_VERSION}-beta \
        --add-module=/root/nginx-module-vts \
        --add-module="/root/nginx-naxsi/naxsi_src" \
        --with-cc-opt="-fPIC -I /usr/include/apr-1" \
        --with-ld-opt="-luuid -lapr-1 -laprutil-1 -licudata -licuuc -L/tmp/modpagespeed-${PAGESPEED_VERSION}/usr/lib -lpng12 -lturbojpeg -ljpeg" && \
    make -j${MAKE_J} install --silent && \
    # Clean-up
    cd && \
    apk del .build-deps && \
    rm -rf /tmp/* && \
    # Forward request and error logs to docker log collector
    ln -sf /dev/stdout /var/log/nginx/access.log && \
    ln -sf /dev/stderr /var/log/nginx/error.log && \
    # Make PageSpeed cache writable
    mkdir -p /var/cache/ngx_pagespeed /var/log/pagespeed && \
    chmod -R 777 /var/cache/ngx_pagespeed && chmod -R 777 /var/log/pagespeed \
    && rm -rf /etc/nginx/html/ \
    && mkdir -p /usr/share/nginx/html/ 

COPY config/conf.d /etc/nginx/conf.d
COPY config/nginx.conf /etc/nginx/nginx.conf
COPY html /usr/share/nginx/html
COPY config/naxsi /etc/nginx/naxsi
VOLUME ["/var/cache/ngx_pagespeed","/var/www"]

RUN chmod -R 777 /var/log/
RUN adduser -D nginx

WORKDIR /root
CMD ["nginx", "-g", "daemon off;"]
