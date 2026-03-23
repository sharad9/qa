#!/usr/bin/env bash
# Bootstrap Kiwi TCMS on first run.
# Usage: sudo bash infra/deploy.sh
set -euo pipefail

COMPOSE="docker compose -f $(dirname "$0")/docker-compose.yml"

echo "==> Pulling images..."
$COMPOSE pull

echo "==> Starting services..."
$COMPOSE up -d

echo "==> Waiting for database to be ready..."
sleep 10

echo "==> Running migrations..."
$COMPOSE exec kiwi python manage.py migrate --noinput

echo "==> Creating superuser (if not exists)..."
$COMPOSE exec kiwi python manage.py shell -c "
from django.contrib.auth import get_user_model
User = get_user_model()
if not User.objects.filter(username='admin').exists():
    User.objects.create_superuser('admin', 'admin@example.com', 'admin')
    print('Superuser created: admin / admin')
else:
    print('Superuser already exists.')
"

echo ""
echo "==> Kiwi TCMS is ready at http://localhost:8080"
echo "    Login: admin / admin"
echo "    IMPORTANT: Change the password immediately in production!"
