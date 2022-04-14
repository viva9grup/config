#!/usr/bin/env bash
clear

#+----------------------------------------------------------------------------+
#+ Check current users ID. If user is not 0 (root), exit.
#+----------------------------------------------------------------------------+
if [ "${EUID}" != 0 ];
then
echo "ServerAdmin NGINX Auto-Installer should be executed as the root user."
exit
fi

#+----------------------------------------------------------------------------+
#+ Pre-Configuration
#+----------------------------------------------------------------------------+
cpuCount=$(nproc --all)
currentPath="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
dhparamBits="4096"
nginxUser="nginx"
openSslVers="3.0"
pcreVers="10.39"
zlibVers="1.2.11"

#+----------------------------------------------------------------------------+
#+ Setup
#+----------------------------------------------------------------------------+
nginxSetup() {
    apt-get update \
    && apt-get -y upgrade \
    && mkdir /etc/install \
    && cd /etc/install \
    && apt-get -y install autoconf automake bc bison build-essential ccache cmake curl dh-systemd flex gcc geoip-bin google-perftools g++ haveged icu-devtools letsencrypt libacl1-dev libbz2-dev libcap-ng-dev libcap-ng-utils libcurl4-openssl-dev libdmalloc-dev libenchant-dev libevent-dev libexpat1-dev libfontconfig1-dev libfreetype6-dev libgd-dev libgeoip-dev libghc-iconv-dev libgmp-dev libgoogle-perftools-dev libice-dev libice6 libicu-dev libjbig-dev libjpeg-dev libjpeg-turbo8-dev libjpeg8-dev libluajit-5.1-2 libluajit-5.1-common libluajit-5.1-dev liblzma-dev libmhash-dev libmhash2 libmm-dev libncurses5-dev libnspr4-dev libpam0g-dev libpcre3 libpcre3-dev libperl-dev libpng-dev libpthread-stubs0-dev libreadline-dev libselinux1-dev libsm-dev libsm6 libssl-dev libtidy-dev libtiff5-dev libtiffxx5 libtool libunbound-dev libvpx-dev libvpx3 libwebp-dev libx11-dev libxau-dev libxcb1-dev libxdmcp-dev libxml2-dev libxpm-dev libxslt1-dev libxt-dev libxt6 make nano perl pkg-config python-dev software-properties-common systemtap-sdt-dev unzip webp wget xtrans-dev zip zlib1g-dev zlibc sysstat auditd libxml-libxml-perl libxml2-utils python-libxml2 libxslt1.1 python-libxslt1 libxml-filter-xslt-perl libxml-libxslt-perl libgd-perl libgd-text-perl python-gd libgoogle-perftools4 dos2unix
    sudo apt install software-properties-common -y
    sudo add-apt-repository ppa:certbot/certbot -y
    sudo apt install certbot -y
    sudo apt install htop nload dos2unix curl unzip zip -y
    sudo rm /etc/localtime
    sudo ln -s /usr/share/zoneinfo/Asia/Jakarta /etc/localtime
    mkdir -p /var/cache/pagespeed
    mkdir -p /var/cache/nginx/proxy_temp
    local nginxUserExists=$(id -u ${nginxUser} > /dev/null 2>&1; echo $?)
    wget https://raw.githubusercontent.com/viva9grup/config/main/swap.sh
    dos2unix swap.sh
    bash swap.sh

    if [ "${nginxUserExists}" != "0" ];
    then
    useradd -d /etc/nginx -s /bin/false nginx
    fi

    mkdir -p /home/nginx/htdocs/public \
    && mkdir -p /usr/local/src/{github,packages/{openssl,pcre,zlib}} \
    && mkdir -p /etc/nginx/cache/{client,fastcgi,proxy,uwsgi,scgi} \
    && mkdir -p /etc/nginx/config/{php,proxy,sites,ssl} \
    && mkdir -p /etc/nginx/{lock,logs/{domains,server/{access,error}}} \
    && mkdir -p /etc/nginx/{modules,pid,sites,ssl}

    cd /usr/local/src/github \
    && git clone https://github.com/nginx/nginx.git \
    && git clone https://github.com/simpl/ngx_devel_kit.git \
    && git clone https://github.com/openresty/headers-more-nginx-module.git \
    && git clone https://github.com/vozlt/nginx-module-vts.git \
    && git clone https://github.com/google/brotli.git \
    && git clone https://github.com/bagder/libbrotli \
    && git clone https://github.com/google/ngx_brotli \
    && git clone https://github.com/nbs-system/naxsi.git \
    && git clone https://github.com/openresty/set-misc-nginx-module.git

    cd /usr/local/src/github \
    && wget https://github.com/apache/incubator-pagespeed-ngx/archive/refs/tags/v1.9.32.10-beta.tar.gz \
    && unzip v1.9.32.10-beta.tar.gz \
    && cd incubator-pagespeed-ngx-1.9.32.10-beta \
    && wget https://dl.google.com/dl/page-speed/psol/1.9.32.10.tar.gz \
    && tar -xzvf 1.9.32.10.tar.gz \
    && wget https://github.com/FRiCKLE/ngx_cache_purge/archive/2.3.tar.gz \
    && tar -zxvf 2.3.tar.gz \
    && mv ngx_cache_purge-2.3 ngx_cache_purge \

    cd /usr/local/src/github/brotli \
    && python setup.py install

    cd /usr/local/src/github/libbrotli \
    && ./autogen.sh \
    && ./configure \
    && make -j ${cpuCount} \
    && make install

    cd /usr/local/src/github/ngx_brotli \
    && git submodule update --init

    cd /usr/local/src/packages \
    && wget https://github.com/PhilipHazel/pcre2/archive/refs/tags/pcre2-10.39.tar.gz \
    && wget https://www.zlib.net/fossils/zlib-1.2.12.tar.gz \
    && tar -zxvf zlib-1.2.12.tar.gz \
    && tar xvf pcre2-10.39.tar.gz --strip-components=1 -C /usr/local/src/packages/pcre \
    && tar xvf zlib-${zlibVers}.tar.gz --strip-components=1 -C /usr/local/src/packages/zlib \
    && cd /usr/share \
    && git clone https://github.com/openssl/openssl.git \
    && cd openssl \
    && git checkout tls1.3-draft-18 \
    && ./config shared enable-tls1_3 --prefix=/usr/share/openssl --openssldir=/usr/share/openssl -Wl,-rpath,'$(LIBRPATH)' \
	&& openssl dhparam -out /etc/nginx/ssl/dhparam.pem ${dhparamBits}

}

nginxCompile() {
    #+------------------------------------------------------------------------+
    #+ Configure & Compile NGINX
    #+------------------------------------------------------------------------+
    cd /usr/local/src/github/nginx \
    && ./auto/configure --prefix=/etc/nginx \
    --sbin-path=/usr/sbin/nginx \
    --conf-path=/etc/nginx/config/nginx.conf \
    --lock-path=/etc/nginx/lock/nginx.lock \
    --pid-path=/etc/nginx/pid/nginx.pid \
    --error-log-path=/etc/nginx/logs/error.log \
    --http-log-path=/etc/nginx/logs/access.log \
    --http-client-body-temp-path=/etc/nginx/cache/client \
    --http-proxy-temp-path=/etc/nginx/cache/proxy \
    --http-fastcgi-temp-path=/etc/nginx/cache/fastcgi \
    --http-uwsgi-temp-path=/etc/nginx/cache/uwsgi \
    --http-scgi-temp-path=/etc/nginx/cache/scgi \
    --user=nginx \
    --group=nginx \
    --with-poll_module \
    --with-threads \
    --with-file-aio \
    --with-http_ssl_module \
    --with-http_v2_module \
    --with-http_realip_module \
    --with-http_addition_module \
    --with-http_xslt_module \
    --with-http_image_filter_module \
    --with-http_sub_module \
    --with-http_dav_module \
    --with-http_flv_module \
    --with-http_mp4_module \
    --with-http_gunzip_module \
    --with-http_gzip_static_module \
    --with-http_auth_request_module \
    --with-http_random_index_module \
    --with-http_secure_link_module \
    --with-http_degradation_module \
    --with-http_slice_module \
    --with-http_stub_status_module \
    --with-stream \
    --with-stream_ssl_module \
    --with-stream_realip_module \
    --with-stream_geoip_module \
    --with-stream_ssl_preread_module \
    --with-google_perftools_module \
    --with-openssl=/usr/share/openssl \
    --with-openssl-opt=enable-tls1_3 \
    --with-pcre=/usr/local/src/packages/pcre \
    --with-pcre-jit \
    --with-zlib=/usr/local/src/packages/zlib \
    --with-openssl=/usr/local/src/packages/openssl \
    --add-module=/usr/local/src/github/naxsi/naxsi_src \
    --add-module=/usr/local/src/github/ngx_devel_kit \
    --add-module=/usr/local/src/github/nginx-module-vts \
    --add-module=/usr/local/src/github/ngx_brotli \
    --add-module=/usr/local/src/github/headers-more-nginx-module \
    --add-module=/usr/local/src/github/set-misc-nginx-module \
    --add-module=/usr/local/src/github/incubator-pagespeed-ngx-1.9.32.10-beta \
    && make -j ${cpuCount} \
    && make install
}

nginxConfigure() {
    #+------------------------------------------------------------------------+
    #+ Copy new configuration
    #+------------------------------------------------------------------------+
    mkdir /etc/nginx/config \
    && cd /etc/nginx/config \
    && wget https://raw.githubusercontent.com/viva9grup/config/main/config/static.conf \
    && wget https://raw.githubusercontent.com/viva9grup/config/main/config/ssl.conf \
    && wget https://raw.githubusercontent.com/viva9grup/config/main/config/resolver.conf \
    && wget https://raw.githubusercontent.com/viva9grup/config/main/config/proxy.conf \
    && wget https://raw.githubusercontent.com/viva9grup/config/main/config/letsencrypt.conf \
    && wget https://raw.githubusercontent.com/viva9grup/config/main/config/pagespeed-adv.conf \
    && wget https://raw.githubusercontent.com/viva9grup/config/main/pagespeed.conf \
    && wget https://raw.githubusercontent.com/viva9grup/config/main/config/headers.conf \
    && wget https://raw.githubusercontent.com/viva9grup/config/main/config/fastcgi_params \
    && wget https://raw.githubusercontent.com/viva9grup/config/main/nginx.conf -O /etc/nginx/nginx.conf \
    && wget https://raw.githubusercontent.com/viva9grup/config/main/sites/_.conf -O /etc/nginx/config/ \
    && cp -R ${currentPath}/systemd/nginx.service /lib/systemd/system/nginx.service \\
    && wget https://raw.githubusercontent.com/viva9grup/config/main/default.vcl -O /etc/varnish/ \
    && wget https://raw.githubusercontent.com/viva9grup/config/main/varnish.params -O /etc/varnish/ \
    && wget https://raw.githubusercontent.com/viva9grup/config/main/varnish.service -O /usr/lib/systemd/system/varnish.service


    #+------------------------------------------------------------------------+
    #+ Set correct permissions and ownership
    #+------------------------------------------------------------------------+
    chown -R nginx:nginx /home/

    #+------------------------------------------------------------------------+
    #+ Create systemd service script and start NGINX
    #+------------------------------------------------------------------------+
    systemctl enable nginx \
    && systemctl start nginx
}

nginxCleanup() {
    #+------------------------------------------------------------------------+
    #+ Remove GitHub and downloaded packages
    #+------------------------------------------------------------------------+
    rm -rf /usr/local/src/github \
    && rm -rf /usr/local/src/packages
}

nginxSetup \
&& nginxCompile \
&& nginxConfigure \
&& nginxCleanup
