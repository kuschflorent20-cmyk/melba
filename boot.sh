#!/bin/sh
source venv/bin/activate

# Variables par défaut
export TANDOOR_PORT="${TANDOOR_PORT:-$PORT}"
export MEDIA_ROOT=${MEDIA_ROOT:-/opt/recipes/mediafiles};
export STATIC_ROOT=${STATIC_ROOT:-/opt/recipes/staticfiles};

GUNICORN_WORKERS="${GUNICORN_WORKERS:-3}"
GUNICORN_THREADS="${GUNICORN_THREADS:-2}"
GUNICORN_LOG_LEVEL="${GUNICORN_LOG_LEVEL:-info}"
PLUGINS_BUILD="${PLUGINS_BUILD:-0}"

echo "Checking configuration..."

# Gérer la clé secrète
if [ -f "${SECRET_KEY_FILE}" ]; then
  export SECRET_KEY=$(cat "$SECRET_KEY_FILE")
fi

if [ -z "${SECRET_KEY}" ]; then
  echo "[WARNING] SECRET_KEY is not set!"
fi

# Préparer la base de données
echo "Waiting for database to be ready..."
attempt=0
max_attempts=20

while ! pg_isready --host=${POSTGRES_HOST} --port=${POSTGRES_PORT} --user=${POSTGRES_USER} -q && [ $attempt -lt $max_attempts ]; do
  attempt=$((attempt+1))
  sleep 5
done

if [ $attempt -ge $max_attempts ]; then
  echo "Database not reachable. Exiting."
  exit 1
fi

echo "Database is ready."

# Migration
python manage.py migrate --noinput

# Collecte des fichiers statiques
python manage.py collectstatic --noinput --clear

chmod -R 755 ${MEDIA_ROOT:-/opt/recipes/mediafiles}

# Démarrer Gunicorn sur le port Render
echo "Starting gunicorn on port ${PORT:-8080}..."
exec gunicorn recipes.wsgi:application \
  --bind 0.0.0.0:${PORT:-8080} \
  --workers $GUNICORN_WORKERS \
  --threads $GUNICORN_THREADS \
  --timeout 60 \
  --access-logfile - \
  --error-logfile - \
  --log-level $GUNICORN_LOG_LEVEL
