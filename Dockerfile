FROM php:7.1-apache
ARG BUILD_NUMBER=18
ARG PARTKEEPR_VERSION=1.4.0
ARG ENABLE_SSL=true

LABEL maintainer="Markus Hubig <mhubig@gmail.com>"
LABEL version="${PARTKEEPR_VERSION}-${BUILD_NUMBER}"


ENV \
	APACHE_SSL_CERTIFICATE_FILE_PATH=/etc/letsencrypt/live/partkeepr.localnetwork/fullchain.pem \
	APACHE_SSL_CERTIFICATE_KEY_PATH=/etc/letsencrypt/live/partkeepr.localnetwork/privkey.pem \
	PARTKEEPR_AUTHENTICATION_PROVIDER='PartKeepr.Auth.WSSEAuthenticationProvider' \
	PARTKEEPR_DATABASE_HOST=database \
	PARTKEEPR_DATABASE_NAME=partkeepr \
	PARTKEEPR_DATABASE_PORT=3306 \
	PARTKEEPR_DATABASE_USER=partkeepr \
	PARTKEEPR_DATABASE_PASS=partkeepr \
	PARTKEEPR_OKTOPART_APIKEY=0123456 \
	PARTKEEPR_SECRET='OJBKOJIKNONAJENLBJJNLFIDPDGKDIED'

COPY install-composer.sh /usr/local/bin/

RUN \
	set -ex && \
	apt-get update && \
	apt-get upgrade -y && \
	apt-get install \
		--no-install-recommends \
		-y \
		bsdtar \
		libcurl4-openssl-dev \
		libfreetype6-dev \
		libjpeg62-turbo-dev \
		libicu-dev \
		libxml2-dev \
		libpng-dev \
		libldap2-dev \
		cron \
		supervisor \
		syslog-ng \
		git \
		wget && \
	rm -r /var/lib/apt/lists/* && \
	\
	docker-php-ext-configure ldap --with-libdir=lib/x86_64-linux-gnu/ && \
	docker-php-ext-configure gd --with-freetype-dir=/usr/include/ --with-jpeg-dir=/usr/include/ && \
	docker-php-ext-install -j$(nproc) curl ldap bcmath gd dom intl opcache pdo pdo_mysql && \
	\
	pecl install apcu_bc-beta && \
	docker-php-ext-enable apcu && \
	\
	cd /var/www/html && \
	git clone https://github.com/aarontc/PartKeepr.git . && \
	cp app/config/parameters.php.dist app/config/parameters.php && \
	install-composer.sh && \
	./composer.phar install && \
	chown -R www-data:www-data /var/www/html && \
	\
	a2enmod rewrite
RUN if [ "$ENABLE_SSL" = "true" ]; then a2enmod ssl; fi


COPY info.php /var/www/html/web/info.php
COPY php.ini /usr/local/etc/php/php.ini
COPY apache.conf /etc/apache2/sites-available/000-default.conf
COPY docker-php-entrypoint mkparameters parameters.template /usr/local/bin/
COPY supervisord.conf /etc/supervisor/conf.d/partkeepr.conf
COPY crontab /etc/cron.d/partkeepr
RUN \
	chmod 0600 /etc/cron.d/partkeepr && \
	chown root:root /etc/cron.d/partkeepr && \
	touch /var/log/partkeepr-cron.log && \
	chown www-data /var/log/partkeepr-cron.log

VOLUME ["/var/www/html/data", "/var/www/html/web"]

CMD [ "/usr/bin/supervisord", "--nodaemon", "--configuration=/etc/supervisor/supervisord.conf" ]
