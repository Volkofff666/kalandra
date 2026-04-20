#!/bin/bash
# Kalandra by nocto — главный скрипт

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/modules/common.sh"

check_root

# Загрузка всех модулей
for mod in ssh firewall icmp services sysctl fail2ban ssh_keys hostname ipv6 \
           traffic_guard port_knock telegram logs benchmark backup checklist; do
    source "$SCRIPT_DIR/modules/${mod}.sh"
done

# ─── Дашборд ───────────────────────────────────────────────────────────────

show_dashboard() {
    local ext_ip ssh_port ufw_status icmp_status ovpn_status \
          f2b_status tg_status tg_status_color \
          cpu_usage mem_used mem_total mem_pct disk_pct \
          icmp_color ovpn_color f2b_color tg_color guard_status guard_color

    ext_ip=$(curl -s --max-time 3 https://api.ipify.org 2>/dev/null || echo "недоступен")
    ssh_port=$(get_ssh_port)

    # UFW
    if ufw status 2>/dev/null | grep -q "Status: active"; then
        ufw_status="${GREEN}active${NC}"
    else
        ufw_status="${RED}inactive${NC}"
    fi

    # ICMP
    if grep -q "echo-request -j DROP" /etc/ufw/before.rules 2>/dev/null; then
        icmp_status="${GREEN}заблокирован${NC}"
    else
        icmp_status="${RED}включён${NC}"
    fi

    # OpenVPN
    if service_active "openvpn" || service_active "openvpn@server"; then
        ovpn_status="${RED}ЗАПУЩЕН!${NC}"
    else
        ovpn_status="${GREEN}не запущен${NC}"
    fi

    # Fail2ban
    if service_active "fail2ban"; then
        f2b_status="${GREEN}активен${NC}"
    else
        f2b_status="${RED}не установлен${NC}"
    fi

    # Traffic Guard
    if command -v traffic-guard &>/dev/null; then
        guard_status="${GREEN}активен${NC}"
    else
        guard_status="${RED}не установлен${NC}"
    fi

    # Telegram
    if [[ -f "$KALANDRA_CONF" ]] && grep -q "^TELEGRAM_TOKEN=" "$KALANDRA_CONF"; then
        tg_status="${GREEN}настроен${NC}"
    else
        tg_status="${YELLOW}не настроен${NC}"
    fi

    # CPU
    cpu_usage=$(top -bn1 | grep "Cpu(s)" | awk '{print int($2)}')
    [[ -z "$cpu_usage" || ! "$cpu_usage" =~ ^[0-9]+$ ]] && cpu_usage=0

    # RAM
    read -r mem_total mem_used <<< "$(free -m | awk '/^Mem:/ {print $2, $3}')"
    [[ -z "$mem_total" || "$mem_total" -eq 0 ]] && mem_total=1
    mem_pct=$(( mem_used * 100 / mem_total ))

    # Диск
    disk_pct=$(df / | awk 'NR==2 {print int($5)}')
    [[ -z "$disk_pct" || ! "$disk_pct" =~ ^[0-9]+$ ]] && disk_pct=0

    echo -e "${BOLD}${WHITE}╔══════════════════ СТАТУС СЕРВЕРА ══════════════════╗${NC}"
    echo -e "${BOLD}${WHITE}║${NC}  🌐 IP адрес    : ${CYAN}${ext_ip}${NC}"
    echo -e "${BOLD}${WHITE}║${NC}  🖥  Hostname    : ${CYAN}$(hostname)${NC}"
    echo -e "${BOLD}${WHITE}║${NC}  🔑 SSH порт    : ${CYAN}${ssh_port}${NC}"
    echo -e "${BOLD}${WHITE}║${NC}  🔥 UFW         : $(echo -e "${ufw_status}")"
    echo -e "${BOLD}${WHITE}║${NC}  📡 ICMP ping   : $(echo -e "${icmp_status}")"
    echo -e "${BOLD}${WHITE}║${NC}  🚫 OpenVPN     : $(echo -e "${ovpn_status}")"
    echo -e "${BOLD}${WHITE}║${NC}  🛡  Fail2ban    : $(echo -e "${f2b_status}")"
    echo -e "${BOLD}${WHITE}║${NC}  🔺 TrafficGuard: $(echo -e "${guard_status}")"
    echo -e "${BOLD}${WHITE}║${NC}  🔔 Telegram    : $(echo -e "${tg_status}")"
    echo -e "${BOLD}${WHITE}║${NC}"
    echo -en "${BOLD}${WHITE}║${NC}  CPU  ["; bar "$cpu_usage";  echo -e "] ${cpu_usage}%"
    echo -en "${BOLD}${WHITE}║${NC}  RAM  ["; bar "$mem_pct";   echo -e "] ${mem_used}/${mem_total} MB"
    echo -en "${BOLD}${WHITE}║${NC}  DISK ["; bar "$disk_pct";  echo -e "] ${disk_pct}%"
    echo -e "${BOLD}${WHITE}╚════════════════════════════════════════════════════╝${NC}"
    echo
}

# ─── Главное меню ──────────────────────────────────────────────────────────

show_menu() {
    echo -e "${BOLD}${WHITE}╔══════════════════════ KALANDRA ══════════════════════╗${NC}"
    echo -e "${BOLD}${WHITE}║${NC}   ${CYAN}1.${NC}  SSH Hardening"
    echo -e "${BOLD}${WHITE}║${NC}   ${CYAN}2.${NC}  Настроить Firewall (UFW)"
    echo -e "${BOLD}${WHITE}║${NC}   ${CYAN}3.${NC}  Заблокировать ICMP ping"
    echo -e "${BOLD}${WHITE}║${NC}   ${CYAN}4.${NC}  Убрать детектируемые сервисы"
    echo -e "${BOLD}${WHITE}║${NC}   ${CYAN}5.${NC}  Sysctl hardening + BBR"
    echo -e "${BOLD}${WHITE}║${NC}   ${CYAN}6.${NC}  Установить Fail2ban"
    echo -e "${BOLD}${WHITE}║${NC}   ${CYAN}7.${NC}  SSH ключи"
    echo -e "${BOLD}${WHITE}║${NC}   ${CYAN}8.${NC}  Сменить hostname"
    echo -e "${BOLD}${WHITE}║${NC}   ${CYAN}9.${NC}  Отключить IPv6"
    echo -e "${BOLD}${WHITE}║${NC}  ${CYAN}10.${NC}  Traffic Guard (блокировка сканеров/ТСПУ)"
    echo -e "${BOLD}${WHITE}║${NC}  ${CYAN}11.${NC}  Port Knocking"
    echo -e "${BOLD}${WHITE}║${NC}  ${CYAN}12.${NC}  Telegram алерты"
    echo -e "${BOLD}${WHITE}║${NC}  ${CYAN}13.${NC}  Просмотр логов"
    echo -e "${BOLD}${WHITE}║${NC}  ${CYAN}14.${NC}  Бенчмарк скорости"
    echo -e "${BOLD}${WHITE}║${NC}  ${CYAN}15.${NC}  Бэкап конфигов"
    echo -e "${BOLD}${WHITE}║${NC}  ${GRAY}──────────────────────────────────────────${NC}"
    echo -e "${BOLD}${WHITE}║${NC}  ${MAGENTA}16.${NC}  ${BOLD}★ Полный hardening (всё сразу)${NC}"
    echo -e "${BOLD}${WHITE}║${NC}  ${CYAN}17.${NC}  Чеклист антидетекта"
    echo -e "${BOLD}${WHITE}║${NC}   ${GRAY}0.${NC}  Выход"
    echo -e "${BOLD}${WHITE}╚══════════════════════════════════════════════════════╝${NC}"
    echo -en "  ${YELLOW}→${NC} Выбор: "
}

# ─── Полный hardening ──────────────────────────────────────────────────────

full_hardening() {
    clear
    show_banner
    echo -e "${BOLD}${MAGENTA}★ ПОЛНЫЙ HARDENING — запуск всех модулей${NC}\n"

    warn "Этот режим последовательно применит все настройки безопасности."
    warn "Убедись что у тебя есть доступ к серверу через консоль/KVM на случай ошибки."
    echo
    confirm "Начать полный hardening?" || { info "Отменено."; return; }

    step "Шаг 1/11 — Бэкап конфигов"
    run_backup

    step "Шаг 2/11 — Убираем детектируемые сервисы"
    run_services

    step "Шаг 3/11 — SSH Hardening"
    run_ssh

    step "Шаг 4/11 — Firewall (UFW)"
    run_firewall

    step "Шаг 5/11 — Блокировка ICMP"
    run_icmp

    step "Шаг 6/11 — Sysctl + BBR"
    run_sysctl

    step "Шаг 7/11 — Fail2ban"
    run_fail2ban

    step "Шаг 8/11 — Traffic Guard"
    run_traffic_guard_quick

    step "Шаг 9/11 — Port Knocking"
    confirm "Настроить Port Knocking?" && run_port_knock

    step "Шаг 10/11 — Telegram алерты"
    confirm "Настроить Telegram алерты?" && run_telegram

    step "Шаг 11/11 — Чеклист антидетекта"
    run_checklist

    echo
    ok "Полный hardening завершён!"
    press_enter
}

run_menu_action() {
    local action="$1"

    if ! declare -F "$action" >/dev/null; then
        err "Действие ${action} не загружено. Проверь установку модулей в $SCRIPT_DIR/modules"
        press_enter
        return 1
    fi

    clear
    show_banner
    "$action"
}

# ─── Основной цикл ─────────────────────────────────────────────────────────

main() {
    while true; do
        clear
        show_banner
        show_dashboard
        show_menu
        read -r choice
        choice="$(normalize_input "$choice")"
        choice="${choice//[[:space:]]/}"
        echo

        case "$choice" in
            1)  run_menu_action run_ssh ;;
            2)  run_menu_action run_firewall ;;
            3)  run_menu_action run_icmp ;;
            4)  run_menu_action run_services ;;
            5)  run_menu_action run_sysctl ;;
            6)  run_menu_action run_fail2ban ;;
            7)  run_menu_action run_ssh_keys ;;
            8)  run_menu_action run_hostname ;;
            9)  run_menu_action run_ipv6 ;;
            10) run_menu_action run_traffic_guard ;;
            11) run_menu_action run_port_knock ;;
            12) run_menu_action run_telegram ;;
            13) run_menu_action run_logs ;;
            14) run_menu_action run_benchmark ;;
            15) run_menu_action run_backup ;;
            16) full_hardening ;;
            17) run_menu_action run_checklist ;;
            0)
                echo -e "  ${MAGENTA}Kalandra завершена. Your server has no reflection.${NC}\n"
                exit 0
                ;;
            *)
                warn "Неверный выбор. Введи число от 0 до 17."
                sleep 1
                ;;
        esac
    done
}

main
