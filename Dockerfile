FROM php:8.2-apache

# --- Ensure ONLY prefork MPM is enabled (required for mod_php) ---
RUN a2dismod mpm_event mpm_worker || true \
 && a2enmod mpm_prefork

# --- System dependencies for PHP extensions + common runtime needs ---
RUN apt-get update && apt-get install -y --no-install-recommends \
    libpng-dev \
    libjpeg62-turbo-dev \
    libfreetype6-dev \
    libzip-dev \
    libicu-dev \
    libonig-dev \
    unzip \
    git \
    ca-certificates \
 && rm -rf /var/lib/apt/lists/*

# --- PHP extensions required by Gibbon ---
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

# --- PHP defaults (reasonable for a school MIS demo) ---
RUN { \
  echo "memory_limit=256M"; \
  echo "upload_max_filesize=64M"; \
  echo "post_max_size=64M"; \
  echo "max_execution_time=120"; \
  echo "max_input_vars=5000"; \
  echo "date.timezone=UTC"; \
} > /usr/local/etc/php/conf.d/gibbon.ini

# --- OPcache (helps with performance) ---
RUN { \
  echo "opcache.enable=1"; \
  echo "opcache.enable_cli=0"; \
  echo "opcache.memory_consumption=128"; \
  echo "opcache.interned_strings_buffer=16"; \
  echo "opcache.max_accelerated_files=20000"; \
  echo "opcache.validate_timestamps=1"; \
  echo "opcache.revalidate_freq=60"; \
} > /usr/local/etc/php/conf.d/opcache.ini

# --- Apache: enable rewrite (Gibbon likes clean URLs) ---
RUN a2enmod rewrite

# --- App location ---
WORKDIR /var/www/html

# Copy your repo into the image
COPY . /var/www/html

# --- Persistent storage path (Railway volume should mount here) ---
RUN mkdir -p /data/uploads

# --- Entrypoint: link uploads to /data and persist/restore config.php ---
RUN cat > /entrypoint.sh <<'SH'
#!/bin/sh
set -e

APP_DIR="/var/www/html"
DATA_DIR="/data"

# Ensure data dirs exist
mkdir -p "$DATA_DIR/uploads"

# Make uploads persistent via symlink
if [ -d "$APP_DIR/uploads" ] && [ ! -L "$APP_DIR/uploads" ]; then
  rm -rf "$APP_DIR/uploads"
fi
ln -sfn "$DATA_DIR/uploads" "$APP_DIR/uploads"

# Restore config.php if previously persisted
if [ -f "$DATA_DIR/config.php" ] && [ ! -f "$APP_DIR/config.php" ]; then
  cp "$DATA_DIR/config.php" "$APP_DIR/config.php"
fi

# If installer created config.php, persist it for future redeploys
if [ -f "$APP_DIR/config.php" ] && [ ! -f "$DATA_DIR/config.php" ]; then
  cp "$APP_DIR/config.php" "$DATA_DIR/config.php"
fi

# Permissions (apache user is www-data)
chown -R www-data:www-data "$DATA_DIR" || true

exec apache2-foreground
SH

RUN chmod +x /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]# --- OPcache ---
RUN { \
  echo "opcache.enable=1"; \
  echo "opcache.enable_cli=0"; \
  echo "opcache.memory_consumption=128"; \
  echo "opcache.interned_strings_buffer=16"; \
  echo "opcache.max_accelerated_files=20000"; \
  echo "opcache.validate_timestamps=1"; \
  echo "opcache.revalidate_freq=60"; \
} > /usr/local/etc/php/conf.d/opcache.ini

# --- Apache config for Railway ---
RUN a2enmod rewrite \
 && sed -i 's/^Listen 80$/Listen ${PORT}/' /etc/apache2/ports.conf \
 && sed -i 's/<VirtualHost \*:80>/<VirtualHost \*:${PORT}>/' /etc/apache2/sites-available/000-default.conf

WORKDIR /var/www/html

# --- Copy app ---
COPY . /var/www/html

# --- Persistent storage ---
RUN mkdir -p /data/uploads

# --- Entrypoint ---
RUN cat > /entrypoint.sh <<'SH'
#!/bin/sh
set -e

APP_DIR="/var/www/html"
DATA_DIR="/data"

mkdir -p "$DATA_DIR/uploads"

# Persist uploads
if [ -d "$APP_DIR/uploads" ] && [ ! -L "$APP_DIR/uploads" ]; then
  rm -rf "$APP_DIR/uploads"
fi
ln -sfn "$DATA_DIR/uploads" "$APP_DIR/uploads"

# Restore config.php
if [ -f "$DATA_DIR/config.php" ] && [ ! -f "$APP_DIR/config.php" ]; then
  cp "$DATA_DIR/config.php" "$APP_DIR/config.php"
fi

# Persist config.php after install
if [ -f "$APP_DIR/config.php" ] && [ ! -f "$DATA_DIR/config.php" ]; then
  cp "$APP_DIR/config.php" "$DATA_DIR/config.php"
fi

chown -R www-data:www-data "$DATA_DIR" || true

exec apache2-foreground
SH

RUN chmod +x /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]
