# Claude Code Prompt — Kalandra by nocto

## Контекст проекта

Ты пишешь **Kalandra** — bash TUI скрипт для подготовки Linux серверов к работе в качестве VPN-ноды с защитой от обнаружения (антидетект) российскими системами DPI/ТСПУ.

**Бренд:** nocto  
**Название:** Kalandra (отсылка к Mirror of Kalandra из Path of Exile — зеркало скрывающее истинное отражение)  
**Tagline:** "Your server has no reflection"  
**Целевая аудитория:** системные администраторы, владельцы VPN-нод на базе Remnawave/Remnanode  
**ОС:** Ubuntu 22.04 и выше / Debian 12  

---

## Структура репозитория

```
kalandra/
├── kalandra.sh              # главный скрипт (точка входа)
├── install.sh               # установщик (curl | bash)
├── modules/
│   ├── ssh.sh               # SSH hardening
│   ├── firewall.sh          # UFW настройка
│   ├── icmp.sh              # блокировка ICMP ping
│   ├── services.sh          # убрать детектируемые сервисы
│   ├── sysctl.sh            # sysctl + BBR
│   ├── fail2ban.sh          # установка и настройка fail2ban
│   ├── ssh_keys.sh          # управление SSH ключами
│   ├── hostname.sh          # смена hostname
│   ├── ipv6.sh              # отключение IPv6
│   ├── traffic_guard.sh     # установка traffic-guard + обновление списков
│   ├── port_knock.sh        # port knocking через knockd
│   ├── telegram.sh          # Telegram алерты
│   ├── logs.sh              # просмотр логов
│   ├── benchmark.sh         # speedtest
│   ├── backup.sh            # бэкап конфигов
│   └── checklist.sh         # чеклист антидетекта
├── lists/
│   └── custom.list          # кастомные IP для блокировки
└── README.md
```

---

## Технические требования

### Общие
- Чистый bash, никаких внешних зависимостей кроме стандартных утилит
- Модульная архитектура — каждый модуль в отдельном файле, подключается через `source`
- Все модули должны работать независимо: `bash modules/ssh.sh`
- Проверка root в начале каждого модуля
- Поддержка Ubuntu 22.04 и Debian 12
- Установка через одну команду: `curl -fsSL https://raw.githubusercontent.com/nocto-dev/kalandra/main/install.sh | sudo bash`
- После установки запускается командой `kalandra`

### Цветовая схема (строго соблюдать)
```bash
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
WHITE='\033[1;37m'
GRAY='\033[0;37m'
BOLD='\033[1m'
NC='\033[0m'
```

### Хелперы (одинаковые во всех модулях)
```bash
ok()      { echo -e "  ${GREEN}[✓]${NC} $1"; }
err()     { echo -e "  ${RED}[✗]${NC} $1"; }
info()    { echo -e "  ${CYAN}[i]${NC} $1"; }
warn()    { echo -e "  ${YELLOW}[!]${NC} $1"; }
step()    { echo -e "\n${BOLD}${WHITE}▶ $1${NC}"; }
confirm() { echo -en "  ${YELLOW}?${NC} $1 [y/N]: "; read -r ans; [[ "$ans" =~ ^[Yy]$ ]]; }
press_enter() { echo -en "\n  ${GRAY}[Enter] продолжить...${NC}"; read -r; }
```

### ASCII баннер (использовать везде)
```
██╗  ██╗ █████╗ ██╗      █████╗ ███╗   ██╗██████╗ ██████╗  █████╗
██║ ██╔╝██╔══██╗██║     ██╔══██╗████╗  ██║██╔══██╗██╔══██╗██╔══██╗
█████╔╝ ███████║██║     ███████║██╔██╗ ██║██║  ██║██████╔╝███████║
██╔═██╗ ██╔══██║██║     ██╔══██║██║╚██╗██║██║  ██║██╔══██╗██╔══██║
██║  ██╗██║  ██║███████╗██║  ██║██║ ╚████║██████╔╝██║  ██║██║  ██║
╚═╝  ╚═╝╚═╝  ╚═╝╚══════╝╚═╝  ╚═╝╚═╝  ╚═══╝╚═════╝ ╚═╝  ╚═╝╚═╝  ╚═╝
```
Под баннером: `by nocto  |  "Your server has no reflection"`

### Прогресс-бар (без unicode блоков — только ASCII)
```bash
bar() {
    local pct=$1 width=20
    [[ -z "$pct" || ! "$pct" =~ ^[0-9]+$ ]] && pct=0
    local filled=$(( pct * width / 100 )) empty=$(( width - filled ))
    local color="${GREEN}"
    (( pct > 70 )) && color="${YELLOW}"
    (( pct > 90 )) && color="${RED}"
    local bar_str="" i
    for (( i=0; i<filled; i++ )); do bar_str+="#"; done
    for (( i=0; i<empty; i++ )); do bar_str+="-"; done
    echo -en "${color}${bar_str}${NC}"
}
```

---

## Дашборд (главный экран)

Показывается при каждом открытии главного меню. Содержит:

```
╔══════════════════ СТАТУС СЕРВЕРА ══════════════════╗
║  🌐 IP адрес    : <внешний IP>
║  🖥  Hostname    : <hostname>
║  🔑 SSH порт    : <порт>
║  🔥 UFW         : active / inactive
║  📡 ICMP ping   : заблокирован (зелёный) / включён (красный)
║  🚫 OpenVPN     : не запущен (зелёный) / ЗАПУЩЕН! (красный)
║  🛡  Fail2ban    : активен / не установлен
║  🔺 TrafficGuard: активен / не установлен
║  🔔 Telegram    : настроен / не настроен
║
║  CPU  [####----------------] 20%
║  RAM  [########------------] 397/3916 MB
║  DISK [###-----------------] 16%
╚════════════════════════════════════════════════════╝
```

---

## Главное меню

```
╔══════════════════════ KALANDRA ══════════════════════╗
║   1. SSH Hardening
║   2. Настроить Firewall (UFW)
║   3. Заблокировать ICMP ping
║   4. Убрать детектируемые сервисы
║   5. Sysctl hardening + BBR
║   6. Установить Fail2ban
║   7. SSH ключи
║   8. Сменить hostname
║   9. Отключить IPv6
║  10. Traffic Guard (блокировка сканеров/ТСПУ)
║  11. Port Knocking
║  12. Telegram алерты
║  13. Просмотр логов
║  14. Бенчмарк скорости
║  15. Бэкап конфигов
║  ──────────────────────────────────────────
║  16. ★ Полный hardening (всё сразу)
║  17. Чеклист антидетекта
║   0. Выход
╚══════════════════════════════════════════════════════╝
```

---

## Описание каждого модуля

### 1. SSH Hardening (`modules/ssh.sh`)

**Действия:**
- Отключить `ssh.socket` (socket activation на Ubuntu 22.04+)
- Сменить порт (по умолчанию предложить 666, принять любой 1-65535)
- Скрыть баннер: `DebianBanner no`, `Banner none`
- Опционально: `PasswordAuthentication no` (с предупреждением что нужен ключ!)
- Опционально: `PermitRootLogin no`
- Открыть новый порт в UFW
- Перезапустить SSH
- **ВАЖНО:** Всегда предупреждать проверить подключение в другой сессии перед закрытием старого порта

**Предупреждение перед отключением пароля:**
```
⚠️  ВНИМАНИЕ: Убедись что SSH-ключ уже добавлен в authorized_keys
    и ты можешь войти по ключу В ДРУГОЙ СЕССИИ.
    Иначе потеряешь доступ к серверу!
```

### 2. Firewall (`modules/firewall.sh`)

**Действия:**
- `ufw default deny incoming`
- `ufw default allow outgoing`
- Закрыть опасные порты: 1194, 500, 4500, 1080, 3128, 8118, 8123, 3389, 51820
- Открыть SSH порт (читать из sshd_config)
- Спросить про 443/tcp
- Спросить про дополнительные порты
- `ufw --force enable`
- Показать `ufw status numbered`

### 3. ICMP (`modules/icmp.sh`)

**Действия:**
- Редактировать `/etc/ufw/before.rules`
- Заменить `echo-request -j ACCEPT` на `echo-request -j DROP` для INPUT и FORWARD
- Оставить `destination-unreachable`, `time-exceeded`, `parameter-problem` — они нужны для MTU и traceroute
- `ufw reload`
- Проверить что изменение применилось

### 4. Убрать сервисы (`modules/services.sh`)

**Проверять и останавливать:**
- openvpn, openvpn@server, xl2tpd, strongswan, pptpd
- squid, 3proxy, dante-server, microsocks
- После остановки показать `ss -tlnp` (только публичные, без 127.x)

### 5. Sysctl + BBR (`modules/sysctl.sh`)

**Файл `/etc/sysctl.d/99-kalandra.conf`:**
```ini
# Антиспуфинг
net.ipv4.conf.all.rp_filter = 1
net.ipv4.conf.default.rp_filter = 1

# SYN flood защита
net.ipv4.tcp_syncookies = 1
net.ipv4.tcp_max_syn_backlog = 2048
net.ipv4.tcp_synack_retries = 2
net.ipv4.tcp_syn_retries = 5

# Не принимать / не отправлять ICMP redirects
net.ipv4.conf.all.accept_redirects = 0
net.ipv4.conf.default.accept_redirects = 0
net.ipv6.conf.all.accept_redirects = 0
net.ipv4.conf.all.send_redirects = 0
net.ipv4.conf.default.send_redirects = 0

# Скрыть версию ядра
kernel.dmesg_restrict = 1
kernel.kptr_restrict = 2

# Игнорировать broadcast ping (smurf)
net.ipv4.icmp_echo_ignore_broadcasts = 1

# BBR — ускорение TCP для VPN трафика
net.core.default_qdisc = fq
net.ipv4.tcp_congestion_control = bbr

# Форвардинг для VPN
net.ipv4.ip_forward = 1
net.ipv6.conf.all.forwarding = 1
```

После применения проверить что BBR активен.

### 6. Fail2ban (`modules/fail2ban.sh`)

**Действия:**
- `apt-get install -y fail2ban`
- Создать `/etc/fail2ban/jail.local` с SSH защитой (порт читать из sshd_config):
```ini
[DEFAULT]
bantime  = 3600
findtime = 600
maxretry = 5
ignoreip = 127.0.0.1/8

[sshd]
enabled  = true
port     = <SSH_PORT>
filter   = sshd
logpath  = /var/log/auth.log
maxretry = 4
bantime  = 7200
```
- `systemctl enable --now fail2ban`
- Показать статус

**Если уже установлен:** показать статус и список забаненных IP (`fail2ban-client status sshd`)

### 7. SSH ключи (`modules/ssh_keys.sh`)

**Подменю:**
1. Сгенерировать новый Ed25519 ключ на сервере → показать публичный ключ
2. Добавить публичный ключ (вставить вручную) → записать в authorized_keys
3. Показать текущие authorized_keys
4. Назад

**При генерации ключа** — показать подробную инструкцию как скопировать приватный ключ на свою машину и настроить `~/.ssh/config`.

### 8. Hostname (`modules/hostname.sh`)

**Действия:**
- Показать текущий hostname
- Предупредить что дефолтные имена (ubuntu, debian, vps12345) выдают VPS
- Принять новый hostname (валидация: только буквы/цифры/дефис)
- `hostnamectl set-hostname`
- Обновить `/etc/hosts`

### 9. IPv6 (`modules/ipv6.sh`)

**Действия:**
- Проверить текущий статус
- Предупредить: не отключай если Remnanode работает через IPv6
- Добавить в `/etc/sysctl.d/99-kalandra.conf`
- Обновить `/etc/default/ufw`: `IPV6=no`
- `ufw reload`

### 10. Traffic Guard (`modules/traffic_guard.sh`)

**Это ключевой модуль — блокировка ТСПУ и сканеров.**

**Источник:** https://github.com/dotX12/traffic-guard  
**Списки:** https://github.com/shadow-netlab/traffic-guard-lists

**Подменю:**
1. Установить traffic-guard
2. Применить списки (government + antiscanner)
3. Применить только government_networks (ТСПУ)
4. Применить только antiscanner
5. Обновить списки вручную
6. Настроить автообновление (cron еженедельно)
7. Статус / показать сколько IP заблокировано
8. Назад

**Установка:**
```bash
curl -fsSL https://raw.githubusercontent.com/dotX12/traffic-guard/master/install.sh | bash
```

**Применение списков:**
```bash
traffic-guard full \
  -u https://raw.githubusercontent.com/shadow-netlab/traffic-guard-lists/refs/heads/main/public/government_networks.list \
  -u https://raw.githubusercontent.com/shadow-netlab/traffic-guard-lists/refs/heads/main/public/antiscanner.list \
  --enable-logging
```

**Автообновление (cron):**
```bash
# /etc/cron.weekly/kalandra-traffic-guard
#!/bin/bash
traffic-guard full \
  -u https://raw.githubusercontent.com/shadow-netlab/traffic-guard-lists/refs/heads/main/public/government_networks.list \
  -u https://raw.githubusercontent.com/shadow-netlab/traffic-guard-lists/refs/heads/main/public/antiscanner.list
```

**Статус:**
- Показать сколько IP в ipset: `ipset list SCANNERS-BLOCK-V4 | grep "Number of entries"`
- Показать последние заблокированные из лога

### 11. Port Knocking (`modules/port_knock.sh`)

**Концепция:** SSH порт не виден снаружи пока не постучишься в нужную последовательность портов.

**Установка knockd:**
```bash
apt-get install -y knockd
```

**Конфиг `/etc/knockd.conf`:**
```ini
[options]
    UseSyslog
    Interface = <NETWORK_INTERFACE>

[openSSH]
    sequence    = <PORT1>,<PORT2>,<PORT3>
    seq_timeout = 10
    command     = /sbin/iptables -I INPUT -s %IP% -p tcp --dport <SSH_PORT> -j ACCEPT
    tcpflags    = syn

[closeSSH]
    sequence    = <PORT3>,<PORT2>,<PORT1>
    seq_timeout = 10
    command     = /sbin/iptables -D INPUT -s %IP% -p tcp --dport <SSH_PORT> -j ACCEPT
    tcpflags    = syn
```

**Действия:**
- Сгенерировать случайную последовательность из 3 портов (1024-60000)
- Показать команду для подключения:
```bash
# Стук для открытия SSH:
knock <SERVER_IP> PORT1 PORT2 PORT3
ssh -p 666 root@<SERVER_IP>

# Стук для закрытия:
knock <SERVER_IP> PORT3 PORT2 PORT1
```
- Предупредить: закрыть SSH порт в UFW после настройки (knockd откроет динамически)
- Показать инструкцию установки `knock` клиента на MacOS/Linux/Windows

**Клиентские команды:**
```bash
# Linux/Mac:
apt install knockd  # или brew install knock
knock IP PORT1 PORT2 PORT3

# Альтернатива без knock клиента (через nmap или nc):
nmap -Pn --host-timeout 201 --max-retries 0 -p PORT1 IP
nmap -Pn --host-timeout 201 --max-retries 0 -p PORT2 IP
nmap -Pn --host-timeout 201 --max-retries 0 -p PORT3 IP
```

### 12. Telegram алерты (`modules/telegram.sh`)

**Алерты отправляются при:**
- Новом SSH подключении (кто, откуда, когда)
- Неудачных попытках входа (5+ попыток с одного IP)
- Fail2ban бане IP
- Высокой нагрузке CPU > 90% или RAM > 90%
- Перезагрузке сервера

**Настройка:**
- Принять Bot Token и Chat ID
- Сохранить в `/etc/kalandra/telegram.conf`
- Создать systemd сервис для мониторинга SSH логов
- Тестовое сообщение при сохранении

**Формат алертов:**
```
🔐 [Kalandra] SSH подключение
Сервер: hostname (IP)
Пользователь: root
Откуда: 1.2.3.4
Время: 2026-04-20 15:30:00
```

```
🚨 [Kalandra] Fail2ban бан
Сервер: hostname
Заблокирован IP: 1.2.3.4
Причина: SSH брутфорс (5 попыток)
```

```
⚠️ [Kalandra] Высокая нагрузка
Сервер: hostname
CPU: 95%
RAM: 87%
```

**Реализация мониторинга SSH:**
```bash
# /etc/kalandra/ssh-monitor.sh
journalctl -u ssh -f --no-pager | while read -r line; do
    if echo "$line" | grep -q "Accepted"; then
        # парсить и отправлять алерт
    fi
    if echo "$line" | grep -q "Failed password"; then
        # считать попытки и алертить
    fi
done
```

### 13. Логи (`modules/logs.sh`)

**Подменю:**
1. SSH — последние подключения
2. SSH — неудачные попытки (с группировкой по IP и счётчиком)
3. UFW — заблокированные соединения (топ-10 IP)
4. Fail2ban — активные баны
5. Traffic Guard — заблокированные сканеры (из CSV лога)
6. Кто сейчас подключён
7. Назад

**Для UFW логов** — показывать топ атакующих IP:
```bash
grep "UFW BLOCK" /var/log/ufw.log | awk '{print $13}' | cut -d= -f2 | sort | uniq -c | sort -rn | head -10
```

### 14. Бенчмарк (`modules/benchmark.sh`)

- Установить speedtest-cli если нет
- Запустить тест
- Показать результат с расчётом: сколько пользователей выдержит нода при средней нагрузке 5 Мбит/с на человека

### 15. Бэкап (`modules/backup.sh`)

**Сохранять в `/root/kalandra-backup-ДАТА/`:**
- `/etc/ssh/sshd_config`
- `/etc/ufw/before.rules`
- `/etc/default/ufw`
- `/etc/sysctl.d/99-kalandra.conf`
- `/etc/fail2ban/jail.local`
- `/etc/knockd.conf`
- `/etc/kalandra/telegram.conf`
- `/etc/hosts`

Показать команды восстановления.

### 16. Полный hardening (`kalandra.sh` — функция)

Порядок выполнения:
1. Бэкап
2. Убрать детектируемые сервисы
3. SSH hardening
4. Firewall
5. ICMP
6. Sysctl + BBR
7. Fail2ban
8. Traffic Guard (установка + оба списка)
9. Спросить про Port Knocking
10. Спросить про Telegram алерты
11. Показать чеклист

### 17. Чеклист антидетекта (`modules/checklist.sh`)

Проверять и показывать статус:
- SSH на нестандартном порту
- SSH баннер скрыт
- Парольная аутентификация отключена
- UFW включён
- UFW: default deny incoming
- ICMP ping заблокирован
- OpenVPN не запущен
- Порт 1194 закрыт
- Порт 3389 (RDP) закрыт
- Порт 1080 (SOCKS5) закрыт
- Fail2ban активен
- Sysctl hardening применён
- BBR активен
- IPv6 отключён (опционально)
- Traffic Guard установлен и активен
- Port Knocking настроен (опционально)
- Telegram алерты настроены (опционально)
- Автообновление списков настроено

В конце: итоговый счёт X/18 и рекомендации.

---

## install.sh

```bash
#!/bin/bash
# Kalandra by nocto — installer

INSTALL_DIR="/opt/kalandra"
BIN_PATH="/usr/local/bin/kalandra"
REPO="https://raw.githubusercontent.com/nocto-dev/kalandra/main"

# Скачать все файлы
mkdir -p "$INSTALL_DIR/modules"
curl -fsSL "$REPO/kalandra.sh" -o "$INSTALL_DIR/kalandra.sh"
for module in ssh firewall icmp services sysctl fail2ban ssh_keys hostname ipv6 traffic_guard port_knock telegram logs benchmark backup checklist; do
    curl -fsSL "$REPO/modules/${module}.sh" -o "$INSTALL_DIR/modules/${module}.sh"
done

# Создать wrapper
cat > "$BIN_PATH" << 'EOF'
#!/bin/bash
exec /opt/kalandra/kalandra.sh "$@"
EOF

chmod +x "$INSTALL_DIR/kalandra.sh" "$BIN_PATH"
chmod +x "$INSTALL_DIR"/modules/*.sh

mkdir -p /etc/kalandra

echo "✓ Kalandra установлена. Запускай: kalandra"
```

---

## Важные технические детали

### Определение сетевого интерфейса
```bash
IFACE=$(ip route | grep default | awk '{print $5}' | head -1)
```

### Определение дистрибутива
```bash
if [[ -f /etc/debian_version ]]; then
    DISTRO="debian"
elif [[ -f /etc/redhat-release ]]; then
    DISTRO="rhel"
fi
```

### Сохранение конфига Kalandra
```bash
KALANDRA_CONF="/etc/kalandra/kalandra.conf"
# Хранить: SSH_PORT, TELEGRAM_TOKEN, TELEGRAM_CHAT_ID, KNOCK_SEQUENCE
```

### CPU парсинг (избегать float в bash)
```bash
cpu_usage=$(top -bn1 | grep "Cpu(s)" | awk '{print int($2)}')
```

### Проверка что сервис существует перед systemctl
```bash
systemctl list-units --full -all 2>/dev/null | grep -q "$service" && systemctl is-active --quiet "$service"
```

---

## Стиль кода

- Все функции в snake_case
- Локальные переменные через `local`
- Проверки через `[[ ]]` не `[ ]`
- Кавычки везде: `"$variable"`
- Ошибки перенаправлять в `/dev/null` где не нужны: `&>/dev/null`
- После каждого важного действия — проверка результата и `ok()` или `err()`
- Никаких `set -e` — обрабатывать ошибки явно
- Комментарии на русском языке

---

## README.md

Написать на русском языке в стиле проекта Решала (дерзко, по делу, с характером). Включить:
- Описание проекта и что он делает
- Список возможностей
- Инструкцию установки
- Скриншот/ASCII дашборда
- Список модулей
- Совместимость
- Лицензия MIT
- Ссылки: nocto, ByeByeVPN, traffic-guard, Remnawave

---

## Что НЕ включать

- Установку Remnawave/Remnanode (пользователь ставит сам)
- Установку Xray/VLESS напрямую (это делает Remnanode)
- Любой код для атак или взлома
- Поддержку не-Linux систем
