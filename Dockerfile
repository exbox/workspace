FROM ubuntu:cosmic
#FROM phusion/baseimage:latest

RUN DEBIAN_FRONTEND=noninteractive
ENV DEBIAN_FRONTEND=noninteractive
#RUN locale-gen en_US.UTF-8

ENV LANGUAGE=en_US.UTF-8
ENV LC_ALL=en_US.UTF-8
ENV LC_CTYPE=en_US.UTF-8
ENV LANG=en_US.UTF-8
ENV TERM xterm

#####################################
# Set Timezone
#####################################

ARG TZ=Europe/London
ENV TZ ${TZ}
RUN ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && echo $TZ > /etc/timezone

#RUN apt-get update && apt-get install -y software-properties-common && add-apt-repository -y ppa:ondrej/php  && add-apt-repository ppa:apt-fast/stable
RUN apt-get update && apt-get install -y software-properties-common && add-apt-repository -y ppa:ondrej/php 

#RUN apt-get install -y apt-fast;

RUN rm /var/log/lastlog /var/log/faillog

#--------------------------------------------------------------------------
# Software's Installation
#--------------------------------------------------------------------------

# Install "PHP Extentions", "libraries", "Software's"
RUN apt update && \
    apt install -y --allow-downgrades --allow-remove-essential \
        --allow-change-held-packages \
        php7.3-cli \
        php7.3-common \
        php7.3-curl \
        php7.3-intl \
        php7.3-json \
        php7.3-xml \
        php7.3-mbstring \
        php7.3-imagick \
        php7.3-mysql \
        php7.3-pgsql \
        php7.3-sqlite \
        php7.3-sqlite3 \
        php7.3-zip \
        php7.3-bcmath \
        php7.3-memcached \
        php7.3-gd \
        php7.3-dev \
        php7.3-mongodb \
        pkg-config \
        libcurl4-openssl-dev \
#        libedit-dev \
        libssl-dev \
        libxml2-dev \
        xz-utils \
        libsqlite3-dev \
        sqlite3 \
        git \
        curl \
        vim \
        postgresql-client \
        mysql-client \
#        libxpm4 libxrender1 libgtk2.0-0 libnss3 libgconf-2-4 \
#        chromium-browser xvfb gtk2-engines-pixbuf \
#        xfonts-cyrillic xfonts-100dpi xfonts-75dpi xfonts-base xfonts-scalable \
#        x11-apps
#        imagemagick \
        iputils-ping \
        fish \
    && apt-get clean

# Install composer and add its bin to the PATH.
RUN curl -s http://getcomposer.org/installer | php && echo "export PATH=${PATH}:/var/www/vendor/bin" >> ~/.bashrc && mv composer.phar /usr/local/bin/composer

# Source the bash
RUN . ~/.bashrc

#####################################
# Non-Root User:
#####################################

# Add a non-root user to prevent files being created with root permissions on host machine.
ARG PUID=1000
ARG PGID=1000

ENV PUID ${PUID}
ENV PGID ${PGID}

RUN groupadd -g ${PGID} laradock && \
    useradd -u ${PUID} -g laradock -m laradock && \
    apt-get update -yqq

USER root

#####################################
# Composer:
#####################################

# Add the composer.json
COPY ./composer.json /home/laradock/.composer/composer.json

# Make sure that ~/.composer belongs to laradock
RUN chown -R laradock:laradock /home/laradock/.composer
USER laradock
RUN  composer global install

#####################################
# Crontab
#####################################
USER root

COPY ./crontab /etc/cron.d
RUN chmod -R 644 /etc/cron.d

#####################################
# User Aliases
#####################################

USER root

COPY ./aliases.sh /root/aliases.sh
COPY ./aliases.sh /home/laradock/aliases.sh

RUN sed -i 's/\r//' /root/aliases.sh && \
    sed -i 's/\r//' /home/laradock/aliases.sh && \
    chown laradock:laradock /home/laradock/aliases.sh && \
    echo "" >> ~/.bashrc && \
    echo "# Load Custom Aliases" >> ~/.bashrc && \
    echo "source ~/aliases.sh" >> ~/.bashrc && \
	echo "" >> ~/.bashrc

USER laradock

RUN echo "" >> ~/.bashrc && \
    echo "# Load Custom Aliases" >> ~/.bashrc && \
    echo "source ~/aliases.sh" >> ~/.bashrc && \
	echo "" >> ~/.bashrc


#####################################
# Node / NVM:
#####################################

# Check if NVM needs to be installed
ARG NODE_VERSION=stable
ENV NODE_VERSION ${NODE_VERSION}
ARG INSTALL_NODE=true
ENV INSTALL_NODE ${INSTALL_NODE}
ENV NVM_DIR /home/laradock/.nvm
ARG NPM_REGISTRY
ENV NPM_REGISTRY ${NPM_REGISTRY}
RUN if [ ${INSTALL_NODE} = true ]; then \
    # Install nvm (A Node Version Manager)
    curl -o- https://raw.githubusercontent.com/creationix/nvm/v0.33.1/install.sh | bash && \
        . $NVM_DIR/nvm.sh && \
        nvm install ${NODE_VERSION} && \
        nvm use ${NODE_VERSION} && \
        nvm alias ${NODE_VERSION} && \
        if [ ${NPM_REGISTRY} ]; then \
        npm config set registry ${NPM_REGISTRY} \
        ;fi && \
        npm install -g vue-cli \
;fi

# Wouldn't execute when added to the RUN statement in the above block
# Source NVM when loading bash since ~/.profile isn't loaded on non-login shell
RUN if [ ${INSTALL_NODE} = true ]; then \
    echo "" >> ~/.bashrc && \
    echo 'export NVM_DIR="$HOME/.nvm"' >> ~/.bashrc && \
    echo '[ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh"  # This loads nvm' >> ~/.bashrc \
;fi

# Add NVM binaries to root's .bashrc
USER root

RUN if [ ${INSTALL_NODE} = true ]; then \
    echo "" >> ~/.bashrc && \
    echo 'export NVM_DIR="/home/laradock/.nvm"' >> ~/.bashrc && \
    echo '[ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh"  # This loads nvm' >> ~/.bashrc \
;fi

# Add PATH for node
ENV PATH $PATH:$NVM_DIR/versions/node/v${NODE_VERSION}/bin

RUN if [ ${NPM_REGISTRY} ]; then \
    . ~/.bashrc && npm config set registry ${NPM_REGISTRY} \
;fi

#####################################
# Non-root user : PHPUnit path
#####################################

# add ./vendor/bin to non-root user's bashrc (needed for phpunit)
USER laradock

RUN echo "" >> ~/.bashrc && \
    echo 'export PATH="/var/www/vendor/bin:$PATH"' >> ~/.bashrc

#####################################
# Prestissimo:
#####################################
USER laradock

RUN composer global require "hirak/prestissimo"

#####################################
# Image optimizers:
#####################################
USER root

RUN composer global require "hirak/prestissimo"

ARG INSTALL_IMAGE_OPTIMIZERS=false
ENV INSTALL_IMAGE_OPTIMIZERS ${INSTALL_IMAGE_OPTIMIZERS}
RUN apt-get install -y --force-yes jpegoptim optipng pngquant gifsicle && . ~/.bashrc && npm install -g svgo

USER laradock

#####################################
# PYTHON:
#####################################

ARG INSTALL_PYTHON=false
ENV INSTALL_PYTHON ${INSTALL_PYTHON}
RUN if [ ${INSTALL_PYTHON} = true ]; then \
  apt-get update \
  && apt-get -y install python python-pip python-dev build-essential  \
  && pip install --upgrade pip  \
  && pip install --upgrade virtualenv \
;fi

#####################################
# ImageMagick:
#####################################
USER root
ARG INSTALL_IMAGEMAGICK=true
ENV INSTALL_IMAGEMAGICK ${INSTALL_IMAGEMAGICK}
RUN if [ ${INSTALL_IMAGEMAGICK} = true ]; then \
    apt-get install -y --force-yes imagemagick php-imagick \
;fi

#####################################
# Dusk Dependencies:
#####################################
USER root
ARG CHROME_DRIVER_VERSION=2.37
ENV CHROME_DRIVER_VERSION ${CHROME_DRIVER_VERSION}
ARG INSTALL_DUSK_DEPS=true
ENV INSTALL_DUSK_DEPS ${INSTALL_DUSK_DEPS}
RUN if [ ${INSTALL_DUSK_DEPS} = true ]; then \
  add-apt-repository ppa:ondrej/php \
  && apt-get update \
  && apt-get -y install zip wget unzip xdg-utils \
    libxpm4 libxrender1 libgtk2.0-0 libnss3 libgconf-2-4 xvfb \
    gtk2-engines-pixbuf xfonts-cyrillic xfonts-100dpi xfonts-75dpi \
    xfonts-base xfonts-scalable x11-apps \
  && wget https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb \
  && dpkg -i --force-depends google-chrome-stable_current_amd64.deb \
  && apt-get -y -f install \
  && dpkg -i --force-depends google-chrome-stable_current_amd64.deb \
  && rm google-chrome-stable_current_amd64.deb \
  && wget https://chromedriver.storage.googleapis.com/${CHROME_DRIVER_VERSION}/chromedriver_linux64.zip \
  && unzip chromedriver_linux64.zip \
  && mv chromedriver /usr/local/bin/ \
  && rm chromedriver_linux64.zip \
;fi

#####################################
# Check PHP version:
#####################################

#RUN php -v | head -n 1 | grep -q "PHP 7.2."

#
#--------------------------------------------------------------------------
# Final Touch
#--------------------------------------------------------------------------
#

# Clean up
USER root
RUN apt-get clean && \
    rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

# Set default work directory
WORKDIR /var/www