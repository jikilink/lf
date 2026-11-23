# Инструкция по установке, запуску и проверке собственного сервиса

В данном репозитории лежат четыре файла `check.sh`, `lf-app.service`, `lf-app.env.example`, `app.py`.

- `check.sh` - проверочный скрипт, который проверяет сервис;
- `lf-app.service` - файл конфигурации юнит сервиса;
- `lf-app.env.example` - файл с переменными для приложения, описание находится в самом концу в параграфе `Установка`;
- `app.py` - файл с приложением.

> **Ремарка**
>
> В файл `lf-app.service` добавлены дополнительные опции такие как:
>
> - `NoNewPrivileges` - запрещает процессу и всем его дочерним процессам получать новые привелегии;
> - `PrivateTmp` - изолирование временные каталоги `/tmp` и `/var/tmp` для сервиса;
> - `ProtectSystem` - переводит системные каталоги в режим "только чтения".

## Установка

1.Склонировать репозиторий:

```bash
git clone https://github.com/jikilink/lf.git
```

2.Перейти в директорию склонированного репозитория

```bash
cd lf
```

3.Обновить репозитории ОС:

```bash
sudo apt update
```

4.Установить нужные пакеты:

```bash
sudo apt install -u python3 curl
```

5.Создать пользователя `lfapp` без хомяка с блокировкой входа в систему:

```bash
sudo useradd --system --user-group --shell /usr/sbin/nologin lfapp
```

6.Создать директории с правами:

```bash
sudo install -d -m 0750 -o root -g lfapp /opt/lf-app && sudo install -d -m 0750 -o root -g lfapp /etc/lf-app
```

7.Скопировать файл `app.py` в папку:

```bash
sudo cp app.py /opt/lf-app/app.py
```

8.Включить файл в группу `lfapp` и дать права на чтение:

```bash
sudo chmod 0640 /opt/lf-app/app.py && sudo chown root:lfapp /opt/lf-app/app.py
```

9.Перенести файл `lf-app.env.example` в папку:

```bash
sudo cp lf-app.env.example /etc/lf-app/lf-app.env
```

10.Включить файл в группу `lfapp` и дать права на чтение:

```bash
sudo chmod 0640 /etc/lf-app/lf-app.env && sudo chown root:lfapp /etc/lf-app/lf-app.env
```

11.Открыть файл `lf-app.env` и поменять на содержимое:

- `PORT` - установить нужный порт при котором можно обращаться по HTTP к приложению;
- `APP_MESSAGE` - написать любое сообщение, которое будет отдавать приложение. ОБЯЗАТЕЛЬНО вписать в двойные кавычки.

12.Скопировать файл `lf-app.service` в папку:

```bash
sudo cp lf-app.service /etc/systemd/system/lf-app.service
```

13.Проверяем на наличие синтаксических ошибок в файле юнита:

```bash
sudo systemd-analyze verify /etc/systemd/system/lf-app.service
```

14.Перечитать юнит файлы:

```bash
sudo systemctl daemon-reload
```

15.Сделаем службу в автозагрузку и сразу запустим её:

```bash
sudo systemctl enable --now lf-app.service
```

## Проверка

Перед тем как запускать скрипт для проверки юнита надо добавить права на исполнение:

```bash
sudo chmod u+x check.sh
```

Команда для запуска:

```bash
./check.sh
Или
bash check.sh
```

## Инциденты

### Права на папку

Уберем права `x` у группы на каталог `/opt/lf-app`.

- Симптом - были убраны права на выполнение папки для группы из под которой пользователь запускает сервис. Если нет права на выполнение папки, то пользователь, который находится в данной группе не сможет зайти в папку. Сервис будет не работать и `curl` будет падать с ошибкой.
- Команда, которая нашла проблему:

```bash
namei -l /opt/lf-app/public/index.html
```

- Команда для исправления проблемы:

```bash
sudo chmod g+x /opt/lf-app/
```

- Команда для проверки:

```bash
curl -f http://127.0.0.1:8080/
```

### Занят порт

- Симптом - был занят порт другим процессом, поэтому после запуска сервиса падает с ошибкой `Start request repeated too quickly.`
- Для начало надо понять какой процесс и его pid занял порт:

```bash
ss -tlnp 'sport = :8080'
```

Если в предыдущей команде pid процесса не виден, то можно посмотреть через другую команду:

```bash
pgrep -a python3
```

- Команда, которая поможет нам завершить данный процесс и освободить порт:

```bash
sudo kill -15 <номер_процесса>
```

- Проверяем тем же командами, что процесс завершен и запускаем наш сервис.

### Указан несуществующий путь к `app.py` в `ExecStart`

- Симптом - при обращении к приложению через `curl` отвечает с ошибкой `Couldn't connect to server`
- Посмотрим стату сервиса:

```bash
journalctl -u lf-app.service -n 10 --no-pager
```

- Строка показывающее проблему запуска сервиса:

```bash
lf-app[2445]: /usr/bin/python3: can't open file '/opt/lf-app/lf-app.py': [Errno 2] No such file or directory
```

- Исправление:

```bash
sudo sed -i 's#^ExecStart=.*#ExecStart=/usr/bin/python3 /opt/lf-app/app.py#' /etc/systemd/system/lf-app.service
```

```bash
sudo systemctl daemon-reload && sudo systemctl restart lf-app.service
```

- Итоговая команда для проверки:

```bash
bash check.sh
```

### Неправильно указан путь к файлу с переменнами

- Симптом - при обращении к приложению через `curl` отвечает с ошибкой `Couldn't connect to server`
- Посмотрим стату сервиса:

```bash
sudo journalctl -u lf-app -n 20 --no-pager
```

- Строка показывающее проблему запуска сервиса:

```bash
lf-app.service: Failed to load environment files: No such file or directory
```

- Откроем файл `/etc/systemd/system/lf-app.service` и посмотрим содержимое файла:

```bash
sudo cat /etc/systemd/system/lf-app.service
```

> Неправильно указан путь к файлу с переменнами

- Исправление - исправим путь на правильный, перечитаем конфигурацию юнита и перезагрузим сервис:

```bash
sudo systemctl daemon-reload
```

```bash
sudo systemctl restart lf-app.service
```

- Итоговая команда для проверки:

```bash
bash check.sh
```

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
curl -fsS --resolve app.lf.test:443:127.0.0.1 --cacert /etc/nginx/tls/app.lf.test.crt [https://app.lf.test/](https://app.lf.test/)
```

**Объяснение:** запрос напрямую к `https://127.0.0.1/` не передаёт доменное имя `app.lf.test` ни в расширении TLS SNI, ни в HTTP-заголовке `Host`, поэтому `nginx` не выбирает виртуальный хост `server_name app.lf.test`, а проверка подлинности сертификата по доменному имени завершается ошибкой несовпадения имени.
