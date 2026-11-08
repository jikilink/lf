#!/usr/bin/env bash
set -Eeuo pipefail

# Вывод активности сервиса

sudo systemctl status lf-app.service --no-pager -l
echo "###################################"

# Проверка статуса сервиса, что он находится в автозагрузке

sudo systemctl is-enabled lf-app.service
echo "###################################"

# Проверка на прослушивания порта

sudo ss -H -tulnp 'sport = :8080'
echo "###################################"

# Проверка HTTP-запроса

curl -f http://127.0.0.1:8080/
echo "###################################"

# Проверка переменной

CHECK_DEFAULT=$(sudo grep -m 1 "APP_MESSAGE" /etc/lf-app/lf-app.env 2>/dev/null | cut -c 1 || true)
APP_MESSAGE=$(sudo grep -m 1 "APP_MESSAGE" /etc/lf-app/lf-app.env | cut -d '=' -f 2 | tr -d '"')
CURL=$(curl -fs http://127.0.0.1:8080/)

if [ "$CHECK_DEFAULT" = "#" ] || [ -z "$CHECK_DEFAULT" ]; then
        if [ "$CURL" = "Linux Factory" ]; then
                echo "Не указана переменная в файле /etc/lf-app/lf-app.env, в приложении используется переменная по умолчанию"
                exit 1
        else
                echo "Не обрабатывается переменная"
                exit 1
        fi
else
        if [ "$CURL" = "$APP_MESSAGE" ]; then
                echo "В приложении переменная выводится правильно"
        else
                echo "Не обрабатывается переменная"
                exit 1
        fi
fi
echo "###################################"

# Проверка, что процесс работает от пользователя lfapp
pgrep -a -u lfapp python3