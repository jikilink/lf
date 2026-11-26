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
