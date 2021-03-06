#for yutaf/nginx-php-7.0
FROM nginx:1.10.1
MAINTAINER yutaf <yutafuji2008@gmail.com>

RUN \
# Inatall apt packages
  apt-get update && \
  DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
# binary
    curl \
    mysql-client \
# TODO remove after redis is available by pecl install
    git \
# php
    make \
    gcc \
    zlib1g-dev \
    libssl-dev \
    libpcre3-dev \
    perl \
    libxml2-dev \
    libjpeg-dev \
    libpng12-dev \
    libfreetype6-dev \
    libmcrypt-dev \
    libcurl4-openssl-dev \
    libreadline-dev \
    libicu-dev \
    g++ \
# xdebug
    autoconf \
# supervisor
    supervisor && \
  rm -r /var/lib/apt/lists/*

#
# Create /usr/local/src directory
#
RUN mkdir -p /usr/local/src

#
# php
#
RUN \
  cd /usr/local/src && \
  curl -L -O http://php.net/distributions/php-7.0.8.tar.gz && \
  tar xzvf php-7.0.8.tar.gz && \
  cd php-7.0.8 && \
  ./configure \
    --prefix=/opt/php-7.0.8 \
    --with-config-file-path=/srv/php/etc \
    --with-config-file-scan-dir=/srv/php/etc/php.d \
    --with-libdir=lib64 \
    --enable-mbstring \
    --enable-intl \
    --with-icu-dir=/usr \
    --with-gettext=/usr \
    --with-pcre-regex=/usr \
    --with-pcre-dir=/usr \
    --with-readline=/usr \
    --with-libxml-dir=/usr/bin/xml2-config \
    --with-mysqli \
    --with-pdo-mysql \
    --with-zlib=/usr \
    --with-zlib-dir=/usr \
    --with-gd \
    --with-jpeg-dir=/usr \
    --with-png-dir=/usr \
    --with-freetype-dir=/usr \
    --enable-gd-native-ttf \
    --enable-gd-jis-conv \
    --with-openssl=/usr \
# ubuntu only
    --with-libdir=/lib/x86_64-linux-gnu \
    --with-mcrypt=/usr \
    --enable-bcmath \
    --with-curl \
    --enable-zip \
    --disable-cgi \
    --enable-fpm \
    --with-fpm-user=www-data \
    --with-fpm-group=www-data \
    --enable-pcntl \
    --enable-exif && \
  make && \
  make install && \
  cd && \
  rm -r /usr/local/src/php-7.0.8

# Add php to PATH to compile extensions like xdebug
ENV PATH /opt/php-7.0.8/bin:/opt/php-7.0.8/sbin:$PATH

# workaround for curl certification error
COPY templates/ca-bundle-curl.crt /root/ca-bundle-curl.crt
#RUN curl -k -L -o $HOME/ca-bundle-curl.crt https://curl.haxx.se/ca/cacert.pem

# xdebug
RUN \
  cd /usr/local/src && \
  curl --cacert $HOME/ca-bundle-curl.crt -L -O http://xdebug.org/files/xdebug-2.4.0.tgz && \
  tar -xzf xdebug-2.4.0.tgz && \
  cd xdebug-2.4.0 && \
  phpize && \
  ./configure --enable-xdebug && \
  make && \
  make install && \
  cd && \
  rm -r /usr/local/src/xdebug-2.4.0

# redis
RUN \
  pecl install redis

# apcu
RUN printf "\n" | pecl install apcu-5.1.4

#
# Edit config files
#
# Apache config
#RUN \
#  sed -i "s/^Listen 80/#&/" /opt/apache2.2.31/conf/httpd.conf && \
#  sed -i "s/^DocumentRoot/#&/" /opt/apache2.2.31/conf/httpd.conf && \
#  sed -i "/^<Directory/,/^<\/Directory/s/^/#/" /opt/apache2.2.31/conf/httpd.conf && \
#  sed -i "s;ScriptAlias /cgi-bin;#&;" /opt/apache2.2.31/conf/httpd.conf && \
#  sed -i "s;#\(Include conf/extra/httpd-mpm.conf\);\1;" /opt/apache2.2.31/conf/httpd.conf && \
#  sed -i "s;#\(Include conf/extra/httpd-default.conf\);\1;" /opt/apache2.2.31/conf/httpd.conf && \
## DirectoryIndex; index.html precedes index.php
#  sed -i "/^\s*DirectoryIndex/s/$/ index.php/" /opt/apache2.2.31/conf/httpd.conf && \
#  sed -i "s/\(ServerTokens \)Full/\1Prod/" /opt/apache2.2.31/conf/extra/httpd-default.conf && \
#  echo "Include /srv/apache/apache.conf" >> /opt/apache2.2.31/conf/httpd.conf && \
## Change User & Group
#  useradd --system --shell /usr/sbin/nologin --user-group --home /dev/null apache; \
#  sed -i "s;^\(User \)daemon$;\1apache;" /opt/apache2.2.31/conf/httpd.conf && \
#  sed -i "s;^\(Group \)daemon$;\1apache;" /opt/apache2.2.31/conf/httpd.conf && \
#  echo 'CustomLog "|/opt/apache2.2.31/bin/rotatelogs /srv/www/logs/access/access.%Y%m%d.log 86400 540" combined' >> /srv/apache/apache.conf && \
#  echo 'ErrorLog "|/opt/apache2.2.31/bin/rotatelogs /srv/www/logs/error/error.%Y%m%d.log 86400 540"' >> /srv/apache/apache.conf && \
#  mkdir -p /srv/www/logs && \
#  cd /srv/www/logs && \
#  mkdir -m 777 access error app && \
#  cd - && \

RUN \
  mkdir -p /srv/www/public/ && \
  echo "<?php echo 'hello, php';" > /srv/www/public/index.php && \
  echo "<?php throw new \Exception;" > /srv/www/public/error.php && \
  echo "<?php phpinfo();" > /srv/www/public/info.php

#
# php setting
#
COPY php/etc/php.ini /srv/php/etc/
COPY php/etc/php.ini /srv/php/etc/php-cli.ini
# For composer working
RUN echo 'zend.detect_unicode = Off' >> /srv/php/etc/php-cli.ini
# php fpm config file
RUN mv /opt/php-7.0.8/etc/php-fpm.conf.default /opt/php-7.0.8/etc/php-fpm.conf
COPY php/etc/php-fpm.d/www.conf /opt/php-7.0.8/etc/php-fpm.d/
# php.ini for modulues
COPY php/etc/php.d/ /srv/php/etc/php.d/

# Set xdebug zend_extension path only in web config file
# Docker cli xdebug is not supported by PhpStorm
RUN echo 'zend_extension = xdebug.so' >> /srv/php/etc/php.ini

# nginx setting
COPY nginx/nginx.conf /etc/nginx/
COPY nginx/conf.d /etc/nginx/conf.d/
# Disable forwarding logs to /dev/stdout, /dev/stderr
RUN rm /var/log/nginx/access.log /var/log/nginx/error.log

COPY scripts/run.sh /root/run.sh
# supervisor
COPY templates/supervisord.conf /etc/supervisor/conf.d/
RUN \
#  echo '[program:apache2]' >> /etc/supervisor/conf.d/supervisord.conf && \
#  echo 'command=/opt/apache2.2.31/bin/httpd -DFOREGROUND' >> /etc/supervisor/conf.d/supervisord.conf && \
# set TERM
  echo export TERM=xterm-256color >> /root/.bashrc && \
# set timezone
#  ln -sf /usr/share/zoneinfo/Japan /etc/localtime && \
# Delete logs except dot files
#  echo '00 5 1,15 * * find /srv/www/logs -not -regex ".*/\.[^/]*$" -type f -mtime +15 -exec rm -f {} \;' > /root/crontab && \
#  crontab /root/crontab && \
# chmod script for running container
  chmod +x /root/run.sh

WORKDIR /srv/www
EXPOSE 80
CMD ["/root/run.sh"]
