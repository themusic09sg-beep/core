FROM php:8.2-apache

# --- System dependencies for PHP extensions ---
RUN apt-get update && apt-get install -y --no-install-recommends \
    libpng-dev \
    libjpeg62-turbo-dev \
    libfreetype6-dev \
    libzip-dev \
    libicu-dev \
    unzip \
    git \
    ca-certificates \
 && rm -rf /var/lib/apt/lists/*

# --- PHP extensions ---
RUN docker-php-ext-configure gd --with-freetype --with-jpeg \
 && docker-php-ext-install -j"$(nproc)" \
    gd \
    intl \
    zip \
    mbstring \
    gettext \
    bcmath \
    pdo_mysql \
    mysqli \
    opcache

# --- PHP recommended settings (safe defaults) ---
RUN { \
  echo "memory_limit=256M"; \
  echo "upload_max_filesize=64M"; \
  echo "post_max_size=64M"; \
  echo "max_execution_time=120"; \
  echo "date.timezone=UTC"; \
} > /usr/local/etc/php/conf.d/gibbon.ini

# --- OPcache (helps speed a lot) ---
RUN { \
  echo "opcache.enable=1"; \
  echo "opcache.enable_cli=0"; \
  echo "opcache.memory_consumption=128"; \
  echo "opcache.interned_strings_buffer=16"; \
  echo "opcache.max_accelerated_files=20000"; \
  echo "opcache.validate_timestamps=1"; \
  echo "opcache.revalidate_freq=60"; \
} > /usr/local/etc/php/conf.d/opcache.ini

# --- Apache: use Railway PORT + enable rewrite ---
RUN a2enmod rewrite \
 && sed -i 's/^Listen 80$/Listen ${PORT}/' /etc/apache2/ports.conf \
 && sed -i 's/<VirtualHost \*:80>/<VirtualHost \*:${PORT}>/' /etc/apache2/sites-available/000-default.conf

# --- App location ---
WORKDIR /var/www/html

# Copy your repo into the image
# (Make sure your repo root contains Gibbon's files like index.php, modules/, etc.)
COPY . /var/www/html

# --- Persistent storage for Railway volume ---
# We'll store config + uploads in /data and bind them into the app each start
RUN mkdir -p /data/uploads

# Entrypoint: restore config/uploads from /data, and persist config after install
RUN cat > /entrypoint.sh <<'SH' \
#!/bin/sh
set -e

APP_DIR="/var/www/html"
DATA_DIR="/data"

# Ensure data dirs exist
mkdir -p "$DATA_DIR/uploads"

# Persist uploads directory
if [ -d "$APP_DIR/uploads" ] && [ ! -L "$APP_DIR/uploads" ]; then
  rm -rf "$APP_DIR/uploads"
fi
ln -sfn "$DATA_DIR/uploads" "$APP_DIR/uploads"

# Restore config.php if we have it persisted
if [ -f "$DATA_DIR/config.php" ] && [ ! -f "$APP_DIR/config.php" ]; then
  cp "$DATA_DIR/config.php" "$APP_DIR/config.php"
fi

# If installer created config.php, persist it for future redeploys
if [ -f "$APP_DIR/config.php" ] && [ ! -f "$DATA_DIR/config.php" ]; then
  cp "$APP_DIR/config.php" "$DATA_DIR/config.php"
fi

# Permissions (apache user is www-data in this image)
chown -R www-data:www-data "$DATA_DIR" || true

exec apache2-foreground
SH
 && chmod +x /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]RUN composer install --no-dev --optimize-autoloader

CMD php -S 0.0.0.0:$PORT -t . router.php
