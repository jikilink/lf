# Домашняя работа s5e03: HTTPS reverse proxy и диагностика по слоям

Схема прохождения запроса:

`app.lf.test:443 -> nginx -> 127.0.0.1:8080 -> lf-app`

> **Важно:** закрытый ключ `/etc/nginx/tls/app.lf.test.key` генерируется локально на сервере и **не добавляется** в Git-репозиторий.

## Установка и настройка

1.Добавить локальную привязку домена `app.lf.test` в `/etc/hosts`:

```bash
getent hosts app.lf.test >/dev/null || echo '127.0.0.1 app.lf.test' | sudo tee -a /etc/hosts
```

2.Установить `nginx`, `openssl`, `curl` и `dnsutils`:

```bash
sudo apt update && sudo apt install -y nginx openssl curl dnsutils
```

3.Создать каталог для TLS-сертификатов с ограниченными правами:

```bash
sudo install -d -m 0750 -o root -g www-data /etc/nginx/tls
```

4.Сгенерировать самоподписанный сертификат для `app.lf.test` (с обязательным `SAN`) и настроить права на ключ:

```bash
sudo openssl req -x509 -nodes -newkey rsa:2048 -days 30 \
  -keyout /etc/nginx/tls/app.lf.test.key \
  -out /etc/nginx/tls/app.lf.test.crt \
  -subj '/CN=app.lf.test' \
  -addext 'subjectAltName=DNS:app.lf.test'
sudo chmod 0640 /etc/nginx/tls/app.lf.test.key && sudo chown root:www-data /etc/nginx/tls/app.lf.test.key
sudo chmod 0644 /etc/nginx/tls/app.lf.test.crt && sudo chown root:root /etc/nginx/tls/app.lf.test.crt
```

5.Скопировать конфигурацию виртуального хоста, включить сайт, проверить синтаксис и перезагрузить `nginx`:

```bash
sudo cp lf-app.nginx.conf /etc/nginx/sites-available/lf-app
sudo ln -sfn /etc/nginx/sites-available/lf-app /etc/nginx/sites-enabled/lf-app
sudo nginx -t && sudo systemctl reload nginx
```

## Проверка рабочего пути запроса по слоям

1.**Разрешение имени:**

```bash
getent hosts app.lf.test
```

Вывод: домен `app.lf.test` успешно разрешается в локальный адрес `127.0.0.1`.

2.**Маршрут:**

```bash
ip route get 127.0.0.1
```

Вывод: трафик к `127.0.0.1` направляется напрямую через локальный интерфейс `lo`.

3.**Слушающий порт nginx:**

```bash
ss -lntp 'sport = :443'
```

Вывод: процесс `nginx` слушает TCP-порт `443` и готов принимать HTTPS-подключения.

4.**TLS-сертификат:**

```bash
openssl s_client -connect app.lf.test:443 -servername app.lf.test -CAfile /etc/nginx/tls/app.lf.test.crt -verify_return_error </dev/null
```

Вывод: TLS-рукопожатие завершается без ошибок (`Verify return code: 0 (ok)`), сертификат действителен для `app.lf.test`.

5.**HTTP-ответ nginx:**

```bash
curl -fsS --cacert /etc/nginx/tls/app.lf.test.crt [https://app.lf.test/](https://app.lf.test/)
```

Вывод: `nginx` успешно проксирует HTTPS-запрос и возвращает ответ приложения `Linux Factory работает`.

6.**Прямой HTTP-ответ приложения:**

```bash
curl -fsS [http://127.0.0.1:8080/](http://127.0.0.1:8080/)
```

Вывод: сервис `lf-app` напрямую отвечает по локальному адресу `127.0.0.1:8080` строкой `Linux Factory работает`.

## Автоматическая проверка

Выдать права на выполнение и запустить проверочный скрипт:

```bash
chmod u+x check-network.sh
./check-network.sh
Или
bash check-network.sh
```

## Инциденты

### 1. Неверный порт приложения в `proxy_pass`

Для воспроизведения в `/etc/nginx/sites-available/lf-app` порт в `proxy_pass` был изменён с `8080` на `8081` с последующими `sudo nginx -t && sudo systemctl reload nginx`.

- **Внешний симптом:** при HTTPS-запросе к `https://app.lf.test/` возвращается HTTP-ошибка `502 Bad Gateway` (`curl: (22) The requested URL returned error: 502`).
- **Последний успешно пройденный слой:** слой 4 (TLS-сертификат) — клиент успешно устанавливает защищённое TLS-соединение с `nginx` на порту `443`, но проксирование на бэкенд обрывается.
- **Команда, которая нашла проблему:**

  ```bash
  tail -n 5 /var/log/nginx/error.log
  ```

  *(в логе зафиксировано `connect() failed (111: Connection refused) while connecting to upstream ... upstream: "http://127.0.0.1:8081/"`)*.
- **Исправление:**

  ```bash
  sudo sed -i 's/127\.0\.0\.1:8081/127.0.0.1:8080/' /etc/nginx/sites-available/lf-app && sudo nginx -t && sudo systemctl reload nginx
  ```

- **Итоговая проверка:**

  ```bash
  ./check-network.sh
  ```

### 2. Неверный IP для `app.lf.test` в `/etc/hosts`

Для воспроизведения в `/etc/hosts` адрес для `app.lf.test` был временно заменён на недоступный IP `192.0.2.1`.

- **Внешний симптом:** клиент не может установить TCP-соединение с `app.lf.test:443` и завершается по таймауту (`curl: (28) Failed to connect to app.lf.test port 443 ... Connection timed out`).
- **Последний успешно пройденный слой:** слой 1 (разрешение имени) — система формально находит запись для `app.lf.test` в `/etc/hosts`, но возвращает неверный IP-адрес, из-за чего запрос не доходит до локального интерфейса `lo` и порта `443` `nginx`.
- **Команда, которая нашла проблему:**

  ```bash
  getent hosts app.lf.test
  ```

  *(выводит `192.0.2.1 app.lf.test` вместо `127.0.0.1 app.lf.test`)*.
- **Исправление:**

  ```bash
  sudo sed -i 's/^.*app\.lf\.test/127.0.0.1 app.lf.test/' /etc/hosts
  ```

- **Итоговая проверка:**

  ```bash
  ./check-network.sh
  ```

## Задание со звёздочкой

Проверка сайта без использования `/etc/hosts` с подстановкой адреса на уровне клиента:

```bash
curl -fsS --resolve app.lf.test:443:127.0.0.1 --cacert /etc/nginx/tls/app.lf.test.crt
```

**Объяснение:** запрос напрямую к `https://127.0.0.1/` не передаёт доменное имя `app.lf.test` ни в расширении TLS SNI, ни в HTTP-заголовке `Host`, поэтому `nginx` не выбирает виртуальный хост `server_name app.lf.test`, а проверка подлинности сертификата по доменному имени завершается ошибкой несовпадения имени.
