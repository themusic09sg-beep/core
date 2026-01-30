FROM php:8.2-cli-bookworm

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y --no-install-recommends \
    git \
    unzip \
    pkg-config \
    autoconf \
    g++ \
    make \
    libpng-dev \
    libjpeg62-turbo-dev \
    libfreetype6-dev \
    libzip-dev \
    libicu-dev \
    libonig-dev \
    && docker-php-ext-configure gd --with-freetype --with-jpeg \
    && docker-php-ext-install -j"$(nproc)" mysqli mbstring gd zip intl \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app
COPY . /app

CMD php -S 0.0.0.0:$PORT -t .
