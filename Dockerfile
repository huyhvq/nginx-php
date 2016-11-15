FROM ubuntu:16.04
MAINTAINER Huy Huynh <huyhvq@icloud.com>
ENV DEBIAN_FRONTEND noninteractive

# Change sources server

RUN sed -i 's|http://archive.ubuntu.com/ubuntu|http://mirror-fpt-telecom.fpt.net/ubuntu/|g' /etc/apt/sources.list

# Update Package Lists
RUN apt-get update && apt-get -y upgrade && apt-get install -y --no-install-recommends apt-utils

# Ensure UTF-8
RUN locale-gen en_US.UTF-8
ENV LANG       en_US.UTF-8
ENV LC_ALL     en_US.UTF-8

# Setup timezone & install libraries

RUN apt-get install -y python-software-properties \
&& apt-get install -y software-properties-common curl\
&& apt-get install -y language-pack-en-base \
&& add-apt-repository -y ppa:nginx/stable \
&& add-apt-repository ppa:ondrej/php

RUN curl -s https://packagecloud.io/gpg.key | apt-key add - \
&& echo "deb http://packages.blackfire.io/debian any main" | tee /etc/apt/sources.list.d/blackfire.list

RUN apt-get update

RUN apt-get install -y \
    build-essential \
    dos2unix \
    gcc \
    git \
    libmcrypt4 \
    python2.7-dev \
    python-pip \
    re2c \
    supervisor \
    unattended-upgrades \
    whois \
    vim \
    libnotify-bin \
    libpcre3-dev \
    unzip \
    wget \
    dialog \
    net-tools
# Set timezone
RUN ln -sf /usr/share/zoneinfo/UTC /etc/localtime

# Install PHP
RUN apt-get install -y \
    php7.0-dev \
    php7.0-fpm \
    php7.0-bcmath \
    php7.0-curl \
    php7.0-gd \
    php7.0-geoip \
    php7.0-imagick \
    php7.0-intl \
    php7.0-json \
    php7.0-ldap \
    php7.0-mbstring \
    php7.0-mcrypt \
    php7.0-memcache \
    php7.0-memcached \
    php7.0-mongo \
    php7.0-mysqlnd \
    php7.0-pgsql \
    php7.0-redis \
    php7.0-sqlite \
    php7.0-xmlrpc \
    php7.0-xdebug \
    nginx \
&& apt-get clean \
&& mkdir /run/php && chown www-data:www-data /run/php \
&& rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

# Set Some PHP CLI Settings

RUN sed -i "s/error_reporting = .*/error_reporting = E_ALL/" /etc/php/7.0/cli/php.ini \
&& sed -i "s/display_errors = .*/display_errors = On/" /etc/php/7.0/cli/php.ini \
&& sed -i "s/memory_limit = .*/memory_limit = 512M/" /etc/php/7.0/cli/php.ini \
&& sed -i "s/;date.timezone.*/date.timezone = UTC/" /etc/php/7.0/cli/php.ini


# Setup Some PHP-FPM Options
RUN echo "xdebug.remote_enable = 1" >> /etc/php/7.0/fpm/conf.d/20-xdebug.ini \
&& echo "xdebug.remote_connect_back = 1" >> /etc/php/7.0/fpm/conf.d/20-xdebug.ini \
&& echo "xdebug.remote_port = 9000" >> /etc/php/7.0/fpm/conf.d/20-xdebug.ini \
&& echo "xdebug.max_nesting_level = 512" >> /etc/php/7.0/fpm/conf.d/20-xdebug.ini

# Disable XDebug On The CLI
RUN phpdismod -s cli xdebug

# Blackfire
RUN version=$(php -r "echo PHP_MAJOR_VERSION.PHP_MINOR_VERSION;") \
&& curl -A "Docker" -o /tmp/blackfire-probe.tar.gz -D - -L -s https://blackfire.io/api/v1/releases/probe/php/linux/amd64/$version \
&& tar zxpf /tmp/blackfire-probe.tar.gz -C /tmp \
&& mv /tmp/blackfire-*.so $(php -r "echo ini_get('extension_dir');")/blackfire.so \
&& printf "extension=blackfire.so\nblackfire.agent_socket=tcp://blackfire:8707\n" > /etc/php/7.0/cli/conf.d/blackfire.ini

# Install nodejs, npm, phalcon & composer
#RUN curl -sL https://deb.nodesource.com/setup_6.x | bash - \
#&& apt-get install -y nodejs \
#&& /usr/bin/npm install -g gulp \
#&& /usr/bin/npm install -g bower \
#&& /usr/bin/npm install -g yarn

RUN curl -sS https://getcomposer.org/installer | php -- --install-dir=/usr/bin --filename=composer

# Nginx & PHP & Supervisor configuration
COPY config/php/php.ini /etc/php/7.0/fpm/php.ini
COPY config/nginx/vhost.conf /etc/nginx/sites-available/default
COPY config/nginx/nginx.conf /etc/nginx/nginx.conf
COPY config/nginx/fastcgi_params.conf /etc/nginx/fastcgi_params
COPY config/supervisor/supervisord.conf /etc/supervisord.conf

# Forward request and error logs to docker log collector
RUN ln -sf /dev/stdout /var/log/nginx/access.log
RUN ln -sf /dev/stderr /var/log/nginx/error.log

# Add php test file
COPY ./info.php /src/public/index.php

# Start Supervisord
COPY ./start.sh /start.sh
RUN chmod 755 /start.sh

EXPOSE 80 443 9001

CMD ["/bin/bash", "/start.sh"]