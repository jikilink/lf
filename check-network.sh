#!/usr/bin/env bash
set -Eeuo pipefail

CERT_PATH="/etc/nginx/tls/app.lf.test.crt"
SITE_URL="https://app.lf.test/"
DOMAIN="app.lf.test"
EXPECTED_TEXT="Linux Factory работает"

if [[ ! -r "$CERT_PATH" ]]; then
  echo "Ошибка: сертификат $CERT_PATH не найден или недоступен для чтения"
  exit 1
fi

if ! RESOLVED_IP="$(getent hosts "$DOMAIN" | awk '{print $1; exit}')" || [[ -z "$RESOLVED_IP" ]]; then
  echo "Ошибка: не удалось разрешить доменное имя $DOMAIN"
  exit 1
fi
echo "OK: имя $DOMAIN разрешается в $RESOLVED_IP"

RESPONSE="$(curl -fsS --connect-timeout 5 --max-time 10 --cacert "$CERT_PATH" "$SITE_URL")" || {
  echo "Ошибка: не удалось выполнить HTTPS-запрос к $SITE_URL"
  exit 1
}

if [[ "$RESPONSE" != *"$EXPECTED_TEXT"* ]]; then
  echo "Ошибка: неожиданный ответ сервера: $RESPONSE"
  exit 1
fi

echo "OK: HTTPS-запрос к $SITE_URL успешен, получен ожидаемый ответ: $RESPONSE"