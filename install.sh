#!/bin/bash
# Kalandra by nocto — установщик

set -e

INSTALL_DIR="/opt/kalandra"
BIN_PATH="/usr/local/bin/kalandra"
REPO="https://raw.githubusercontent.com/nocto-dev/kalandra/main"

RED='\033[0;31m'
GREEN='\033[0;32m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
BOLD='\033[1m'
NC='\033[0m'

ok()   { echo -e "  ${GREEN}[✓]${NC} $1"; }
err()  { echo -e "  ${RED}[✗]${NC} $1"; }
info() { echo -e "  ${CYAN}[i]${NC} $1"; }

if [[ $EUID -ne 0 ]]; then
    err "Требуются права root. Запусти: sudo bash install.sh"
    exit 1
fi

echo -e "${CYAN}"
echo '██╗  ██╗ █████╗ ██╗      █████╗ ███╗   ██╗██████╗ ██████╗  █████╗ '
echo '██║ ██╔╝██╔══██╗██║     ██╔══██╗████╗  ██║██╔══██╗██╔══██╗██╔══██╗'
echo '█████╔╝ ███████║██║     ███████║██╔██╗ ██║██║  ██║██████╔╝███████║'
echo '██╔═██╗ ██╔══██║██║     ██╔══██║██║╚██╗██║██║  ██║██╔══██╗██╔══██║'
echo '██║  ██╗██║  ██║███████╗██║  ██║██║ ╚████║██████╔╝██║  ██║██║  ██║'
echo '╚═╝  ╚═╝╚═╝  ╚═╝╚══════╝╚═╝  ╚═╝╚═╝  ╚═══╝╚═════╝ ╚═╝  ╚═╝╚═╝  ╚═╝'
echo -e "${NC}"
echo -e "  ${MAGENTA}${BOLD}Установка Kalandra by nocto${NC}"
echo -e "  ${CYAN}\"Your server has no reflection\"${NC}"
echo

# Зависимости
info "Проверяем зависимости..."
if ! command -v curl &>/dev/null; then
    info "Устанавливаем curl..."
    apt-get update -qq && apt-get install -y curl &>/dev/null
fi
ok "curl: OK"

# Создаём директории
info "Создаём директории..."
mkdir -p "$INSTALL_DIR/modules"
mkdir -p "$INSTALL_DIR/lists"
mkdir -p /etc/kalandra
ok "Директории созданы: ${INSTALL_DIR}"

# Скачиваем файлы
info "Загружаем файлы..."

curl -fsSL "$REPO/kalandra.sh" -o "$INSTALL_DIR/kalandra.sh" && ok "kalandra.sh"
curl -fsSL "$REPO/modules/common.sh" -o "$INSTALL_DIR/modules/common.sh" && ok "modules/common.sh"

for module in ssh firewall icmp services sysctl fail2ban ssh_keys hostname ipv6 \
              traffic_guard port_knock telegram logs benchmark backup checklist; do
    curl -fsSL "$REPO/modules/${module}.sh" -o "$INSTALL_DIR/modules/${module}.sh" && \
        ok "modules/${module}.sh" || err "Ошибка загрузки: modules/${module}.sh"
done

curl -fsSL "$REPO/lists/custom.list" -o "$INSTALL_DIR/lists/custom.list" 2>/dev/null || true

# Права
chmod +x "$INSTALL_DIR/kalandra.sh"
chmod +x "$INSTALL_DIR"/modules/*.sh

# Wrapper
cat > "$BIN_PATH" << 'EOF'
#!/bin/bash
exec /opt/kalandra/kalandra.sh "$@"
EOF
chmod +x "$BIN_PATH"

echo
ok "Kalandra установлена!"
echo
echo -e "  ${BOLD}Запуск:${NC}  ${CYAN}kalandra${NC}"
echo
