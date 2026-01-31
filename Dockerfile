RUN cat > /entrypoint.sh <<'SH'
#!/bin/sh
set -e

APP_DIR="/var/www/html"
DATA_DIR="/data"

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

chown -R www-data:www-data "$DATA_DIR" || true

exec apache2-foreground
SH

RUN chmod +x /entrypoint.sh
