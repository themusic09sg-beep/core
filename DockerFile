FROM php:8.2-cli

# Install required system libs
RUN apt-get update && apt-get install -y \
    libpng-dev \
    libjpeg-dev \
    libfreetype6-dev \
    libzip-dev \
    unzip \
    && docker-php-ext-configure gd --with-freetype --with-jpeg \
    && docker-php-ext-install mysqli mbstring gd zip intl

# Set working directory
WORKDIR /app

# Copy app files
COPY . /app

# Railway provides $PORT
CMD php -S 0.0.0.0:$PORT -t .
