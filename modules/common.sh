#!/bin/bash
# Общие переменные, цвета и хелперы — подключается во всех модулях

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
WHITE='\033[1;37m'
GRAY='\033[0;37m'
BOLD='\033[1m'
NC='\033[0m'

ok()          { echo -e "  ${GREEN}[✓]${NC} $1"; }
err()         { echo -e "  ${RED}[✗]${NC} $1"; }
info()        { echo -e "  ${CYAN}[i]${NC} $1"; }
warn()        { echo -e "  ${YELLOW}[!]${NC} $1"; }
step()        { echo -e "\n${BOLD}${WHITE}▶ $1${NC}"; }
normalize_input() {
    local value="$1"
    value="${value//$'\r'/}"
    echo -n "$value"
}

confirm() {
    local ans
    echo -en "  ${YELLOW}?${NC} $1 [y/N]: "
    read -r ans
    ans="$(normalize_input "$ans")"
    [[ "$ans" =~ ^[Yy]$ ]]
}
press_enter() { echo -en "\n  ${GRAY}[Enter] продолжить...${NC}"; read -r; }

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

KALANDRA_CONF="/etc/kalandra/kalandra.conf"

check_root() {
    if [[ $EUID -ne 0 ]]; then
        err "Требуются права root. Запусти через sudo."
        exit 1
    fi
}

# Определение сетевого интерфейса
get_iface() {
    ip route | grep default | awk '{print $5}' | head -1
}

# Определение дистрибутива
get_distro() {
    if [[ -f /etc/debian_version ]]; then
        echo "debian"
    elif [[ -f /etc/redhat-release ]]; then
        echo "rhel"
    else
        echo "unknown"
    fi
}

# Чтение SSH порта из sshd_config
get_ssh_port() {
    local port
    port=$(grep -E "^Port " /etc/ssh/sshd_config 2>/dev/null | awk '{print $2}' | head -1)
    echo "${port:-22}"
}

# Сохранить параметр в конфиге Kalandra
save_conf() {
    local key="$1" value="$2"
    mkdir -p /etc/kalandra
    if grep -q "^${key}=" "$KALANDRA_CONF" 2>/dev/null; then
        sed -i "s|^${key}=.*|${key}=${value}|" "$KALANDRA_CONF"
    else
        echo "${key}=${value}" >> "$KALANDRA_CONF"
    fi
}

# Прочитать параметр из конфига Kalandra
read_conf() {
    local key="$1"
    grep -E "^${key}=" "$KALANDRA_CONF" 2>/dev/null | cut -d= -f2-
}

# Проверить что сервис существует и активен
service_active() {
    local service="$1"
    systemctl list-units --full -all 2>/dev/null | grep -q "$service" && \
        systemctl is-active --quiet "$service"
}

show_banner() {
    echo -e "${CYAN}"
    echo '██╗  ██╗ █████╗ ██╗      █████╗ ███╗   ██╗██████╗ ██████╗  █████╗ '
    echo '██║ ██╔╝██╔══██╗██║     ██╔══██╗████╗  ██║██╔══██╗██╔══██╗██╔══██╗'
    echo '█████╔╝ ███████║██║     ███████║██╔██╗ ██║██║  ██║██████╔╝███████║'
    echo '██╔═██╗ ██╔══██║██║     ██╔══██║██║╚██╗██║██║  ██║██╔══██╗██╔══██║'
    echo '██║  ██╗██║  ██║███████╗██║  ██║██║ ╚████║██████╔╝██║  ██║██║  ██║'
    echo '╚═╝  ╚═╝╚═╝  ╚═╝╚══════╝╚═╝  ╚═╝╚═╝  ╚═══╝╚═════╝ ╚═╝  ╚═╝╚═╝  ╚═╝'
    echo -e "${NC}"
    echo -e "  ${GRAY}by nocto  |  ${MAGENTA}\"Your server has no reflection\"${NC}"
    echo
}
