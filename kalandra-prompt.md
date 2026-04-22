# Claude Code Prompt — Kalandra v2 by nocto
# Платформа управления VPN инфраструктурой

## Контекст

Ты дорабатываешь **Kalandra** — bash TUI инструмент для управления VPN-нодами на базе Remnawave/Remnanode.

Репозиторий: https://github.com/Volkofff666/kalandra
Текущая версия: 0.6.0 — базовый hardening скрипт с 17 модулями.

**Задача:** Превратить его в полноценную платформу управления VPN инфраструктурой. Версия 1.0.0.

**Бренд:** nocto | Kalandra | "Your server has no reflection"
**ОС:** Ubuntu 22.04, Ubuntu 24.04, Debian 12
**Стек:** bash, Docker, Remnanode, Prometheus, Grafana, Node Exporter

---

## Новая структура репозитория

```
kalandra/
├── kalandra.sh                  # главный скрипт, точка входа
├── install.sh                   # установщик: curl | bash
├── uninstall.sh                 # удаление
├── CHANGELOG.md                 # история версий
├── modules/
│   ├── common.sh                # хелперы, цвета, общие функции (уже есть)
│   ├── ssh.sh                   # (уже есть)
│   ├── firewall.sh              # (уже есть)
│   ├── icmp.sh                  # (уже есть)
│   ├── services.sh              # (уже есть)
│   ├── sysctl.sh                # (уже есть)
│   ├── fail2ban.sh              # (уже есть)
│   ├── ssh_keys.sh              # (уже есть)
│   ├── hostname.sh              # (уже есть)
│   ├── ipv6.sh                  # (уже есть)
│   ├── traffic_guard.sh         # (уже есть)
│   ├── port_knock.sh            # (уже есть)
│   ├── telegram.sh              # (уже есть)
│   ├── logs.sh                  # (уже есть)
│   ├── benchmark.sh             # (уже есть)
│   ├── backup.sh                # (уже есть)
│   ├── checklist.sh             # (уже есть)
│   ├── docker.sh                # НОВЫЙ — управление Docker
│   ├── remnanode.sh             # НОВЫЙ — установка и управление Remnanode
│   ├── quickstart.sh            # НОВЫЙ — быстрый старт новой ноды
│   ├── monitoring.sh            # НОВЫЙ — Grafana + Prometheus стек
│   ├── health.sh                # НОВЫЙ — диагностика ноды
│   └── fleet.sh                 # НОВЫЙ — управление флотом серверов
├── fleet/
│   ├── nodes.conf               # список нод флота (IP, порт, пользователь)
│   └── known_hosts              # SSH known_hosts для флота
├── monitoring/
│   ├── docker-compose.yml       # Prometheus + Grafana + Node Exporter
│   ├── prometheus.yml           # конфиг Prometheus
│   └── grafana/
│       └── dashboard.json       # готовый дашборд для VPN нод
└── lists/
    └── custom.list              # кастомные IP для блокировки
```

---

## Стиль кода (строго соблюдать существующий)

### Цвета (из common.sh — не менять)
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

### Хелперы (из common.sh — не менять)
```bash
ok()          { echo -e "  ${GREEN}[✓]${NC} $1"; }
err()         { echo -e "  ${RED}[✗]${NC} $1"; }
info()        { echo -e "  ${CYAN}[i]${NC} $1"; }
warn()        { echo -e "  ${YELLOW}[!]${NC} $1"; }
step()        { echo -e "\n${BOLD}${WHITE}▶ $1${NC}"; }
confirm()     { echo -en "  ${YELLOW}?${NC} $1 [y/N]: "; read -r ans; [[ "$ans" =~ ^[Yy]$ ]]; }
press_enter() { echo -en "\n  ${GRAY}[Enter] продолжить...${NC}"; read -r; }
```

### Правила кода
- Чистый bash, никаких внешних зависимостей кроме стандартных утилит
- Все переменные через `local` внутри функций
- Проверки через `[[ ]]`
- Кавычки везде: `"$variable"`
- После каждого действия — проверка и `ok()` или `err()`
- Комментарии на русском языке
- Никаких `set -e` — обрабатывать ошибки явно

---

## Обновлённое главное меню

```
╔══════════════════════ KALANDRA v1.0.0 ═══════════════════════╗
║
║  🚀 БЫСТРЫЙ СТАРТ
║   1. ⚡ Новая нода за 5 минут     [quickstart]
║
║  🛡️  БЕЗОПАСНОСТЬ
║   2. 🔑 SSH Hardening
║   3. 🔥 Firewall (UFW)
║   4. 📡 ICMP блокировка
║   5. 🧹 Убрать детектируемые сервисы
║   6. ⚙️  Sysctl + BBR
║   7. 🚫 Fail2ban
║   8. 🗝️  SSH ключи
║   9. 🏷️  Hostname
║  10. 🌐 IPv6
║  11. 🔺 Traffic Guard
║  12. 🚪 Port Knocking
║  13. 📬 Telegram алерты
║
║  🐳 DOCKER & REMNANODE
║  14. 🐳 Docker управление
║  15. 🔌 Remnanode установка/управление
║
║  📊 МОНИТОРИНГ
║  16. 📊 Grafana + Prometheus стек
║  17. 🩺 Диагностика ноды
║
║  🛸 FLEET
║  18. 🛸 Управление флотом
║
║  🔧 УТИЛИТЫ
║  19. 📋 Логи
║  20. 🚀 Бенчмарк
║  21. 💾 Бэкап конфигов
║  ─────────────────────────────────────────────
║  22. ★  Полный hardening (всё сразу)
║  23. ✅ Чеклист антидетекта
║   0. 👋 Выход
╚═══════════════════════════════════════════════════════════════╝
```

---

## НОВЫЕ МОДУЛИ — детальное описание

---

### МОДУЛЬ: quickstart.sh — "Новая нода за 5 минут"

Это ГЛАВНАЯ киллер-фича. Один пункт который разворачивает полностью готовую ноду.

**Функция:** `run_quickstart`

**Шаги по порядку:**
1. Показать что будет сделано и запросить подтверждение
2. Обновить систему: `apt-get update && apt-get upgrade -y`
3. Установить базовые пакеты: `curl wget git ufw fail2ban`
4. Запустить базовый hardening (SSH, firewall, icmp, sysctl)
5. Установить Docker
6. Установить Remnanode
7. Настроить Traffic Guard
8. Показать итоговую сводку с токеном Remnanode

**Установка Docker:**
```bash
curl -fsSL https://get.docker.com | sh
systemctl enable docker
systemctl start docker
```

**Установка Remnanode:**
```bash
bash <(curl -Ls https://raw.githubusercontent.com/remnawave/node/refs/heads/main/install.sh)
```

После установки — показать токен/конфиг для подключения к Remnawave панели.

**Итоговый экран после quickstart:**
```
╔══════════════════════════════════════════════════╗
║  ✅ НОДА ГОТОВА К РАБОТЕ
║
║  🌐 IP адрес    : 185.x.x.x
║  🔑 SSH порт    : 666
║  🐳 Docker      : запущен
║  🔌 Remnanode   : запущен
║  🔺 TrafficGuard: активен
║  🛡  Fail2ban    : активен
║
║  📋 Следующий шаг:
║  Добавь эту ноду в Remnawave панель
║  используя токен из конфига Remnanode
╚══════════════════════════════════════════════════╝
```

**Время выполнения:** показывать прогресс каждого шага с таймером.

---

### МОДУЛЬ: docker.sh — управление Docker

**Функция:** `run_docker`

**Подменю:**
```
🐳 DOCKER
─────────────────────────
1. 📦 Статус контейнеров
2. 🔄 Рестарт контейнера
3. 📋 Логи контейнера
4. 📊 Статистика (docker stats)
5. 🧹 Очистка мусора
6. 🐳 Установить Docker
0. ← Назад
```

**Реализация:**

```bash
# Статус контейнеров — красивый вывод
docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}" 2>/dev/null

# Статистика — одноразовый снапшот (не интерактивный)
docker stats --no-stream 2>/dev/null

# Очистка мусора
docker system prune -f 2>/dev/null
docker volume prune -f 2>/dev/null

# Логи — последние 50 строк с выбором контейнера
containers=$(docker ps --format "{{.Names}}" 2>/dev/null)
# показать список, выбрать, показать логи
```

**Если Docker не установлен** — предложить установить.

---

### МОДУЛЬ: remnanode.sh — Remnanode управление

**Функция:** `run_remnanode`

**Подменю:**
```
🔌 REMNANODE
─────────────────────────
1. 📦 Статус
2. 🔄 Перезапустить
3. 📋 Логи (последние 50 строк)
4. 📋 Логи в реальном времени
5. ⬆️  Обновить до последней версии
6. 🔌 Установить Remnanode
7. ❌ Удалить Remnanode
0. ← Назад
```

**Определение статуса:**
```bash
# Remnanode работает через Docker
docker ps | grep -q "remnanode" && ok "Remnanode запущен" || err "Remnanode не запущен"

# Логи
docker logs remnanode --tail 50 2>/dev/null

# Рестарт
docker restart remnanode 2>/dev/null

# Обновление
docker pull remnawave/node:latest 2>/dev/null
docker restart remnanode 2>/dev/null
```

**Установка:**
```bash
bash <(curl -Ls https://raw.githubusercontent.com/remnawave/node/refs/heads/main/install.sh)
```

**Удаление:**
```bash
docker stop remnanode 2>/dev/null
docker rm remnanode 2>/dev/null
docker rmi remnawave/node:latest 2>/dev/null
```

---

### МОДУЛЬ: monitoring.sh — Grafana + Prometheus

**Функция:** `run_monitoring`

**Подменю:**
```
📊 МОНИТОРИНГ
─────────────────────────
1. 🚀 Установить стек (Grafana + Prometheus + Node Exporter)
2. 📊 Статус стека
3. 🔄 Перезапустить стек
4. 🌐 Открыть Grafana (показать URL)
5. ⬆️  Обновить стек
6. ❌ Удалить стек
0. ← Назад
```

**docker-compose.yml для мониторинга:**
```yaml
version: '3.8'

services:
  prometheus:
    image: prom/prometheus:latest
    container_name: kalandra-prometheus
    restart: unless-stopped
    ports:
      - "127.0.0.1:9090:9090"
    volumes:
      - /opt/kalandra/monitoring/prometheus.yml:/etc/prometheus/prometheus.yml
      - prometheus_data:/prometheus
    command:
      - '--config.file=/etc/prometheus/prometheus.yml'
      - '--storage.tsdb.retention.time=30d'

  grafana:
    image: grafana/grafana:latest
    container_name: kalandra-grafana
    restart: unless-stopped
    ports:
      - "3000:3000"
    environment:
      - GF_SECURITY_ADMIN_PASSWORD=kalandra
      - GF_USERS_ALLOW_SIGN_UP=false
      - GF_SERVER_ROOT_URL=http://localhost:3000
    volumes:
      - grafana_data:/var/lib/grafana
      - /opt/kalandra/monitoring/grafana:/etc/grafana/provisioning

  node-exporter:
    image: prom/node-exporter:latest
    container_name: kalandra-node-exporter
    restart: unless-stopped
    ports:
      - "127.0.0.1:9100:9100"
    volumes:
      - /proc:/host/proc:ro
      - /sys:/host/sys:ro
      - /:/rootfs:ro
    command:
      - '--path.procfs=/host/proc'
      - '--path.sysfs=/host/sys'
      - '--collector.filesystem.mount-points-exclude=^/(sys|proc|dev|host|etc)($$|/)'

volumes:
  prometheus_data:
  grafana_data:
```

**prometheus.yml:**
```yaml
global:
  scrape_interval: 15s
  evaluation_interval: 15s

scrape_configs:
  - job_name: 'node'
    static_configs:
      - targets: ['node-exporter:9100']

  - job_name: 'prometheus'
    static_configs:
      - targets: ['localhost:9090']
```

**Установка стека:**
```bash
# Создать директории
mkdir -p /opt/kalandra/monitoring/grafana

# Скопировать конфиги
# Запустить
cd /opt/kalandra/monitoring
docker-compose up -d

# Открыть порт Grafana
ufw allow 3000/tcp
```

**После установки показать:**
```
╔══════════════════════════════════════════╗
║  📊 Grafana установлена!
║
║  URL     : http://IP_СЕРВЕРА:3000
║  Логин   : admin
║  Пароль  : kalandra
║
║  ⚠️  Смени пароль после первого входа!
╚══════════════════════════════════════════╝
```

**Дашборд Grafana (grafana/dashboard.json):**
Создать готовый JSON дашборд с панелями:
- CPU Usage (gauge + graph)
- RAM Usage (gauge + graph)
- Network In/Out (graph)
- Disk Usage (gauge)
- Active connections (graph)
- System Uptime (stat)
- Load Average (graph)

---

### МОДУЛЬ: health.sh — диагностика ноды

**Функция:** `run_health`

**Что проверяет:**

```bash
run_health() {
    print_banner
    echo -e "  ${BOLD}${MAGENTA}[ 🩺 ДИАГНОСТИКА НОДЫ ]${NC}\n"
    
    local ext_ip
    ext_ip=$(curl -s --max-time 5 https://api.ipify.org)
    
    # 1. Внешний IP и геолокация
    step "Сетевая информация"
    local geo
    geo=$(curl -s --max-time 5 "https://ipapi.co/${ext_ip}/json/" 2>/dev/null)
    local country city isp
    country=$(echo "$geo" | grep -o '"country_name":"[^"]*"' | cut -d'"' -f4)
    city=$(echo "$geo" | grep -o '"city":"[^"]*"' | cut -d'"' -f4)
    isp=$(echo "$geo" | grep -o '"org":"[^"]*"' | cut -d'"' -f4)
    info "IP: ${ext_ip} | ${city}, ${country}"
    info "Провайдер: ${isp}"
    
    # 2. Проверка открытых портов снаружи
    step "Проверка портов"
    local ssh_port
    ssh_port=$(get_ssh_port)
    check_port_external() {
        local port=$1 desc=$2
        if curl -s --max-time 5 "https://portchecker.co/check?port=${port}&host=${ext_ip}" 2>/dev/null | grep -q "open"; then
            ok "Порт ${port} (${desc}) — открыт снаружи"
        else
            warn "Порт ${port} (${desc}) — не проверить через API"
        fi
    }
    # Просто проверяем что сервисы слушают
    ss -tlnp | grep -q ":${ssh_port} " && ok "SSH порт ${ssh_port} — слушается" || err "SSH порт ${ssh_port} — не слушается!"
    ss -tlnp | grep -q ":443 " && ok "Порт 443 — слушается" || warn "Порт 443 — не слушается"
    
    # 3. Remnanode статус
    step "Remnanode"
    if docker ps 2>/dev/null | grep -q "remnanode"; then
        ok "Remnanode — запущен"
        local uptime
        uptime=$(docker inspect remnanode --format='{{.State.StartedAt}}' 2>/dev/null | cut -dT -f1)
        info "Запущен с: ${uptime}"
    else
        err "Remnanode — не запущен"
    fi
    
    # 4. Docker статус
    step "Docker"
    if systemctl is-active --quiet docker 2>/dev/null; then
        ok "Docker — запущен"
        local containers
        containers=$(docker ps -q 2>/dev/null | wc -l)
        info "Активных контейнеров: ${containers}"
    else
        err "Docker — не запущен"
    fi
    
    # 5. Системные ресурсы
    step "Системные ресурсы"
    local cpu ram disk load
    cpu=$(top -bn1 | grep "Cpu(s)" | awk '{print int($2)}')
    ram=$(free -m | awk '/^Mem:/{printf "%d/%d MB (%.0f%%)", $3, $2, $3*100/$2}')
    disk=$(df / | awk 'NR==2{printf "%s/%s (%s)", $3, $2, $5}')
    load=$(uptime | awk -F'load average:' '{print $2}' | xargs)
    info "CPU: ${cpu}%"
    info "RAM: ${ram}"
    info "Disk: ${disk}"
    info "Load: ${load}"
    
    # 6. Ping до популярных CDN (задержка)
    step "Задержка до CDN"
    for host in "1.1.1.1" "8.8.8.8" "google.com"; do
        local latency
        latency=$(ping -c 1 -W 3 "$host" 2>/dev/null | grep -oP 'time=\K[0-9.]+')
        [[ -n "$latency" ]] && info "${host}: ${latency}ms" || warn "${host}: недоступен"
    done
    
    # 7. Проверка блокировок ТСПУ
    step "Статус Traffic Guard"
    if command -v ipset &>/dev/null; then
        local blocked_v4
        blocked_v4=$(ipset list SCANNERS-BLOCK-V4 2>/dev/null | grep "Number of entries" | awk '{print $4}')
        [[ -n "$blocked_v4" ]] && ok "Заблокировано IPv4 подсетей: ${blocked_v4}" || warn "Traffic Guard не активен"
    fi
    
    press_enter
}
```

---

### МОДУЛЬ: fleet.sh — управление флотом

Это ВТОРАЯ главная киллер-фича. Управление всеми нодами из одного места.

**Функция:** `run_fleet`

**Формат файла nodes.conf:**
```
# Kalandra Fleet — список нод
# Формат: NAME|IP|SSH_PORT|USER
#
nl01|185.x.x.1|666|root
nl03|185.x.x.2|666|root
de01|194.x.x.1|666|root
fi02|65.x.x.x|22|root
ru02|92.x.x.x|666|root
```

**Подменю Fleet:**
```
🛸 FLEET — УПРАВЛЕНИЕ ФЛОТОМ
─────────────────────────────────────────
1. 📋 Список нод и статус
2. ➕ Добавить ноду
3. ➖ Удалить ноду
4. 🔌 Подключиться к ноде (SSH)
─────────────────────────────────────────
5. 🚀 Развернуть Kalandra на всех нодах
6. 🛡️  Запустить hardening на всех нодах
7. 🔺 Обновить Traffic Guard на всех
8. ⬆️  Обновить Kalandra на всех нодах
─────────────────────────────────────────
9. ⚡ Выполнить команду на всех нодах
0. ← Назад
```

**Реализация статуса нод:**
```bash
fleet_status() {
    echo -e "\n  ${BOLD}${WHITE}СТАТУС ФЛОТА${NC}\n"
    
    local nodes_file="/opt/kalandra/fleet/nodes.conf"
    
    if [[ ! -f "$nodes_file" ]]; then
        warn "Флот пуст. Добавь ноды через пункт 2."
        return
    fi
    
    printf "  %-12s %-18s %-8s %-10s %-10s\n" "ИМЯ" "IP" "ПОРТ" "SSH" "СТАТУС"
    echo "  ─────────────────────────────────────────────────────"
    
    while IFS='|' read -r name ip port user; do
        [[ "$name" =~ ^#.*$ || -z "$name" ]] && continue
        
        # Проверка SSH доступности
        if ssh -o ConnectTimeout=3 -o StrictHostKeyChecking=no \
               -o BatchMode=yes -p "$port" "${user}@${ip}" "echo ok" &>/dev/null; then
            ssh_status="${GREEN}✓ online${NC}"
        else
            ssh_status="${RED}✗ offline${NC}"
        fi
        
        printf "  %-12s %-18s %-8s %-10s " "$name" "$ip" "$port" "$user"
        echo -e "$(echo -e ${ssh_status})"
        
    done < "$nodes_file"
    echo ""
}
```

**Выполнение команды на всех нодах:**
```bash
fleet_exec_all() {
    local cmd="$1"
    
    while IFS='|' read -r name ip port user; do
        [[ "$name" =~ ^#.*$ || -z "$name" ]] && continue
        echo -en "  ${CYAN}[${name}]${NC} "
        result=$(ssh -o ConnectTimeout=5 -o StrictHostKeyChecking=no \
                     -o BatchMode=yes -p "$port" "${user}@${ip}" "$cmd" 2>&1)
        if [[ $? -eq 0 ]]; then
            ok "${result}"
        else
            err "Ошибка: ${result}"
        fi
    done < "/opt/kalandra/fleet/nodes.conf"
}
```

**Развертывание Kalandra на всех нодах:**
```bash
fleet_deploy_all() {
    local install_cmd="curl -fsSL https://raw.githubusercontent.com/Volkofff666/kalandra/main/install.sh | sudo bash"
    
    step "Развертывание Kalandra на всём флоте..."
    fleet_exec_all "$install_cmd"
}
```

**Обновление Traffic Guard на всех нодах:**
```bash
fleet_update_traffic_guard() {
    local tg_cmd="traffic-guard full \
        -u https://raw.githubusercontent.com/shadow-netlab/traffic-guard-lists/refs/heads/main/public/government_networks.list \
        -u https://raw.githubusercontent.com/shadow-netlab/traffic-guard-lists/refs/heads/main/public/antiscanner.list"
    
    step "Обновление Traffic Guard на всём флоте..."
    fleet_exec_all "$tg_cmd"
}
```

**Подключение к ноде:**
```bash
fleet_connect() {
    # Показать список нод с номерами
    # Выбрать номер
    # exec ssh -p PORT USER@IP
    local nodes_file="/opt/kalandra/fleet/nodes.conf"
    local i=1
    local names=() ips=() ports=() users=()
    
    while IFS='|' read -r name ip port user; do
        [[ "$name" =~ ^#.*$ || -z "$name" ]] && continue
        names+=("$name"); ips+=("$ip"); ports+=("$port"); users+=("$user")
        echo -e "  ${CYAN}${i}${NC}. ${name} (${ip}:${port})"
        (( i++ ))
    done < "$nodes_file"
    
    echo -en "\n  ${YELLOW}→${NC} Выбери ноду: "
    read -r num
    (( num-- ))
    
    exec ssh -p "${ports[$num]}" "${users[$num]}@${ips[$num]}"
}
```

---

## Обновления существующих модулей

### common.sh — добавить функции

```bash
# Определение сетевого интерфейса
get_iface() {
    ip route | grep default | awk '{print $5}' | head -1
}

# Проверка установлен ли Docker
docker_installed() {
    command -v docker &>/dev/null && systemctl is-active --quiet docker 2>/dev/null
}

# Проверка запущен ли контейнер
container_running() {
    docker ps 2>/dev/null | grep -q "$1"
}

# Красивый заголовок секции с эмодзи
section() {
    echo -e "\n  ${BOLD}${MAGENTA}[ $1 ]${NC}\n"
}

# Spinner для долгих операций
spinner() {
    local pid=$1 msg="${2:-Выполняется...}"
    local spin='⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏'
    local i=0
    while kill -0 "$pid" 2>/dev/null; do
        printf "\r  ${CYAN}${spin:$i:1}${NC} ${msg}"
        i=$(( (i+1) % 10 ))
        sleep 0.1
    done
    printf "\r"
}

# Запустить команду с spinner
run_with_spinner() {
    local msg="$1"; shift
    "$@" &>/dev/null &
    spinner $! "$msg"
    wait $!
    return $?
}
```

### sysctl.sh — добавить оптимизацию для высокой нагрузки

Добавить в `/etc/sysctl.d/99-kalandra.conf`:
```ini
# Оптимизация для высокой нагрузки (много соединений)
net.core.somaxconn = 32768
net.ipv4.tcp_max_tw_buckets = 6000
net.ipv4.tcp_fastopen = 3
net.ipv4.tcp_rmem = 4096 87380 67108864
net.ipv4.tcp_wmem = 4096 65536 67108864
net.core.rmem_max = 67108864
net.core.wmem_max = 67108864
net.ipv4.tcp_mtu_probing = 1
fs.file-max = 1000000
```

И в `/etc/security/limits.conf`:
```
* soft nofile 51200
* hard nofile 51200
root soft nofile 51200
root hard nofile 51200
```

### benchmark.sh — улучшить

Добавить после speedtest:
```bash
# Расчёт ёмкости ноды
local download_mbps  # получить из speedtest
local users_5mbps=$(( download_mbps / 5 ))
local users_10mbps=$(( download_mbps / 10 ))

echo ""
info "Расчётная ёмкость ноды:"
info "При нагрузке 5 Мбит/с на юзера: ~${users_5mbps} одновременных"
info "При нагрузке 10 Мбит/с на юзера: ~${users_10mbps} одновременных"
```

---

## install.sh — обновить

```bash
#!/bin/bash
# Kalandra by nocto — installer v1.0.0

set -e

INSTALL_DIR="/opt/kalandra"
BIN_PATH="/usr/local/bin/kalandra"
REPO="https://raw.githubusercontent.com/Volkofff666/kalandra/main"
VERSION="1.0.0"

# Цвета
GREEN='\033[0;32m'; CYAN='\033[0;36m'; YELLOW='\033[1;33m'
RED='\033[0;31m'; NC='\033[0m'; BOLD='\033[1m'

echo -e "${CYAN}"
cat << 'EOF'
██╗  ██╗ █████╗ ██╗      █████╗ ███╗   ██╗██████╗ ██████╗  █████╗
██║ ██╔╝██╔══██╗██║     ██╔══██╗████╗  ██║██╔══██╗██╔══██╗██╔══██╗
█████╔╝ ███████║██║     ███████║██╔██╗ ██║██║  ██║██████╔╝███████║
██╔═██╗ ██╔══██║██║     ██╔══██║██║╚██╗██║██║  ██║██╔══██╗██╔══██║
██║  ██╗██║  ██║███████╗██║  ██║██║ ╚████║██████╔╝██║  ██║██║  ██║
╚═╝  ╚═╝╚═╝  ╚═╝╚══════╝╚═╝  ╚═╝╚═╝  ╚═══╝╚═════╝ ╚═╝  ╚═╝╚═╝  ╚═╝
EOF
echo -e "${NC}"
echo -e "  ${BOLD}by nocto${NC} | Установка v${VERSION}..."
echo ""

# Проверка root
if [[ $EUID -ne 0 ]]; then
    echo -e "  ${RED}[✗]${NC} Нужен root: sudo bash install.sh"
    exit 1
fi

# Проверка ОС
if ! grep -qE "ubuntu|debian" /etc/os-release 2>/dev/null; then
    echo -e "  ${YELLOW}[!]${NC} Поддерживается только Ubuntu/Debian"
fi

# Установка зависимостей
echo -e "  ${CYAN}[i]${NC} Устанавливаем зависимости..."
apt-get update -qq
apt-get install -y -qq curl wget git ufw 2>/dev/null

# Скачиваем файлы
echo -e "  ${CYAN}[i]${NC} Скачиваем Kalandra..."
mkdir -p "$INSTALL_DIR/modules" "$INSTALL_DIR/fleet" "$INSTALL_DIR/monitoring/grafana" "$INSTALL_DIR/lists"

# Главный скрипт
curl -fsSL "$REPO/kalandra.sh" -o "$INSTALL_DIR/kalandra.sh"

# Модули
MODULES="common ssh firewall icmp services sysctl fail2ban ssh_keys hostname ipv6
         traffic_guard port_knock telegram logs benchmark backup checklist
         docker remnanode quickstart monitoring health fleet"

for mod in $MODULES; do
    echo -ne "  ${CYAN}[i]${NC} Модуль: ${mod}.sh\r"
    curl -fsSL "$REPO/modules/${mod}.sh" -o "$INSTALL_DIR/modules/${mod}.sh" 2>/dev/null || \
        echo -e "  ${YELLOW}[!]${NC} Модуль ${mod}.sh не найден, пропускаем"
done

# Мониторинг конфиги
curl -fsSL "$REPO/monitoring/docker-compose.yml" -o "$INSTALL_DIR/monitoring/docker-compose.yml" 2>/dev/null || true
curl -fsSL "$REPO/monitoring/prometheus.yml" -o "$INSTALL_DIR/monitoring/prometheus.yml" 2>/dev/null || true

# Права
chmod +x "$INSTALL_DIR/kalandra.sh"
chmod +x "$INSTALL_DIR/modules/"*.sh 2>/dev/null || true

# Создать wrapper команду
cat > "$BIN_PATH" << 'WRAPPER'
#!/bin/bash
exec /opt/kalandra/kalandra.sh "$@"
WRAPPER
chmod +x "$BIN_PATH"

# Создать nodes.conf если нет
if [[ ! -f "$INSTALL_DIR/fleet/nodes.conf" ]]; then
    cat > "$INSTALL_DIR/fleet/nodes.conf" << 'NODES'
# Kalandra Fleet — список нод
# Формат: NAME|IP|SSH_PORT|USER
# Пример:
# nl01|185.x.x.1|666|root
NODES
fi

echo ""
echo -e "  ${GREEN}[✓]${NC} Kalandra v${VERSION} установлена!"
echo ""
echo -e "  Запуск: ${CYAN}kalandra${NC}"
echo -e "  Новая нода за 5 минут: ${CYAN}kalandra${NC} → пункт 1"
echo ""
```

---

## CHANGELOG.md

```markdown
# Changelog

## [1.0.0] — 2026-04-xx

### Добавлено
- ⚡ Quickstart — новая нода за 5 минут (Docker + Remnanode + hardening)
- 🐳 Модуль управления Docker
- 🔌 Модуль управления Remnanode
- 📊 Grafana + Prometheus мониторинг одной командой
- 🩺 Диагностика ноды (порты, геолокация, задержки, Remnanode статус)
- 🛸 Fleet — управление всеми нодами из одного места
- 🔄 Оптимизация sysctl для высокой нагрузки (50k+ соединений)
- ⚡ Spinner для долгих операций
- 🔄 Автообновление через `kalandra --check-update`

### Изменено
- Обновлено главное меню с эмодзи и группировкой по категориям
- Benchmark теперь считает ёмкость ноды в пользователях
- Версионирование APP_VERSION в kalandra.sh

## [0.6.0] — 2026-04-20
- Базовый hardening: SSH, UFW, ICMP, sysctl, fail2ban
- Traffic Guard интеграция
- Port Knocking
- Telegram алерты
- Чеклист антидетекта
```

---

## Важные требования к реализации

1. **Fleet работает через SSH ключи** — никаких паролей. При добавлении ноды — проверять что ключ работает.

2. **Все долгие операции** (установка Docker, обновление пакетов, fleet операции) — показывать spinner или прогресс.

3. **Grafana по умолчанию слушает на всех интерфейсах** (порт 3000). Предупредить пользователя что нужно либо закрыть UFW либо настроить пароль.

4. **Fleet exec** — выполнять параллельно через `&` + `wait`, не последовательно. Показывать результаты по мере готовности.

5. **Quickstart** — если что-то уже установлено (Docker, Remnanode) — пропускать этот шаг, не переустанавливать.

6. **Обратная совместимость** — все существующие модули (1-17) работают как раньше. Новые добавляются сверху.

7. **Версия** — обновить `APP_VERSION="1.0.0"` в kalandra.sh.

8. **Topics в README** — добавить badges:
```markdown
![Version](https://img.shields.io/badge/version-1.0.0-blue)
![License](https://img.shields.io/badge/license-MIT-green)
![OS](https://img.shields.io/badge/OS-Ubuntu%2022.04%2F24.04%20%7C%20Debian%2012-orange)
```

---

## Что НЕ делать

- Не трогать логику существующих модулей (1-17) — только добавлять новые
- Не добавлять установку Remnawave панели — только Remnanode
- Не добавлять веб-интерфейс — только TUI в терминале
- Не использовать Python/Node.js — только bash