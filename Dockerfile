FROM php:8.2-apache

# --- System dependencies for PHP extensions + tools ---
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

# --- PHP extensions required by Gibbon (and common modules) ---
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

# --- Apache: enable rewrite + ensure ONLY ONE MPM (prefork) ---
RUN a2enmod rewrite \
 && a2dismod mpm_event mpm_worker >/dev/null 2>&1 || true \
 && a2enmod mpm_prefork

# --- Apache: silence ServerName warning ---
RUN echo "ServerName localhost" > /etc/apache2/conf-available/servername.conf \
 && a2enconf servername

# --- Composer (for vendor/autoload.php) ---
COPY --from=composer:2 /usr/bin/composer /usr/bin/composer

# --- PHP recommended settings (safe defaults) ---
RUN { \
  echo "memory_limit=256M"; \
  echo "upload_max_filesize=64M"; \
  echo "post_max_size=64M"; \
  echo "max_execution_time=120"; \
  echo "date.timezone=UTC"; \
} > /usr/local/etc/php/conf.d/gibbon.ini

# --- OPcache (speed) ---
RUN { \
  echo "opcache.enable=1"; \
  echo "opcache.enable_cli=0"; \
  echo "opcache.memory_consumption=128"; \
  echo "opcache.interned_strings_buffer=16"; \
  echo "opcache.max_accelerated_files=20000"; \
  echo "opcache.validate_timestamps=1"; \
  echo "opcache.revalidate_freq=60"; \
} > /usr/local/etc/php/conf.d/opcache.ini

# --- App location ---
WORKDIR /var/www/html
COPY . /var/www/html

# --- Install PHP dependencies (creates vendor/) ---
# If your repo already includes vendor/, this is still fine.
RUN composer install --no-dev --optimize-autoloader

# --- Volume-backed storage ---
# Railway Volume should be mounted at /data in Railway settings
RUN mkdir -p /data/uploads

# --- Entrypoint: PORT fix + MPM sanity + persist config/uploads ---
RUN cat > /entrypoint.sh <<'SH'
#!/bin/sh
set -e

APP_DIR="/var/www/html"
DATA_DIR="/data"

mkdir -p "$DATA_DIR/uploads"

# Force ONLY prefork MPM every boot (fixes "More than one MPM loaded")
a2dismod mpm_event mpm_worker >/dev/null 2>&1 || true
a2enmod mpm_prefork >/dev/null 2>&1 || true

# Railway PORT fix (Apache does NOT expand ${PORT} in config files)
if [ -n "${PORT:-}" ]; then
  sed -i "s/^Listen .*/Listen ${PORT}/" /etc/apache2/ports.conf
  sed -i "s/<VirtualHost \*:.*>/<VirtualHost *:${PORT}>/" /etc/apache2/sites-available/000-default.conf
fi

# Persist uploads via symlink into the volume
if [ -e "$APP_DIR/uploads" ] && [ ! -L "$APP_DIR/uploads" ]; then
  rm -rf "$APP_DIR/uploads"
fi
ln -sfn "$DATA_DIR/uploads" "$APP_DIR/uploads"

# Restore config.php from volume (so redeploys don't reset install)
if [ -f "$DATA_DIR/config.php" ] && [ ! -f "$APP_DIR/config.php" ]; then
  cp "$DATA_DIR/config.php" "$APP_DIR/config.php"
fi

# If installer created config.php, persist it to volume
if [ -f "$APP_DIR/config.php" ] && [ ! -f "$DATA_DIR/config.php" ]; then
  cp "$APP_DIR/config.php" "$DATA_DIR/config.php"
fi

chown -R www-data:www-data "$DATA_DIR" || true

exec apache2-foreground
SH

RUN chmod +x /entrypoint.sh
ENTRYPOINT ["/entrypoint.sh"]
