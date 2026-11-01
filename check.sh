#!/usr/bin/env bash
set -Eeuo pipefail

# Вывод активности сервиса
sudo systemctl status lf-app.service --no-pager -l
echo "###################################"
# Проверка статуса сервиса, что он находится в автозагрузке
sudo systemctl is-enabled lf-app.service
echo "###################################"
# Проверка на прослушивания порта
sudo ss -H -tulnp 'sport = :8080' | grep -q
echo "###################################"
# Проверка HTTP-запроса
curl -f http://127.0.0.1:8080/
echo "###################################"
# Проверка, что процесс работает от пользователя lfapp
pgrep -a -u lfapp python3