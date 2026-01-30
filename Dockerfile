FROM php:8.2-cli

# Install required system libraries for PHP extensions
RUN apt-get update && apt-get install -y \
    libpng-dev \
    libjpeg62-turbo-dev \
    libfreetype6-dev \
    libzip-dev \
    libicu-dev \
    unzip \
    && docker-php-ext-configure gd --with-freetype --with-jpeg \
    && docker-php-ext-install mysqli mbstring gd zip intl

# Set working directory
WORKDIR /app

# Copy application files
COPY . /app

# Start PHP built-in server on Railway's assigned port
CMD php -S 0.0.0.0:$PORT -t .
