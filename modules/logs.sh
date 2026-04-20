#!/bin/bash
# Просмотр логов

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
[[ -z "$GREEN" ]] && source "$SCRIPT_DIR/common.sh"

run_logs() {
    check_root

    while true; do
        clear
        echo -e "${BOLD}${WHITE}╔══════════════════ ЛОГИ ══════════════════╗${NC}"
        echo -e "${BOLD}${WHITE}║${NC}  ${CYAN}1.${NC}  SSH — последние подключения"
        echo -e "${BOLD}${WHITE}║${NC}  ${CYAN}2.${NC}  SSH — неудачные попытки (топ по IP)"
        echo -e "${BOLD}${WHITE}║${NC}  ${CYAN}3.${NC}  UFW — заблокированные (топ-10 IP)"
        echo -e "${BOLD}${WHITE}║${NC}  ${CYAN}4.${NC}  Fail2ban — активные баны"
        echo -e "${BOLD}${WHITE}║${NC}  ${CYAN}5.${NC}  Traffic Guard — заблокированные сканеры"
        echo -e "${BOLD}${WHITE}║${NC}  ${CYAN}6.${NC}  Кто сейчас подключён"
        echo -e "${BOLD}${WHITE}║${NC}  ${GRAY}0.${NC}  Назад"
        echo -e "${BOLD}${WHITE}╚══════════════════════════════════════════╝${NC}"
        echo -en "  ${YELLOW}→${NC} Выбор: "
        read -r choice
        choice="$(normalize_input "$choice")"
        choice="${choice//[[:space:]]/}"

        case "$choice" in
            1) _logs_ssh_success ;;
            2) _logs_ssh_fail ;;
            3) _logs_ufw ;;
            4) _logs_fail2ban ;;
            5) _logs_traffic_guard ;;
            6) _logs_who ;;
            0) return ;;
            *) warn "Неверный выбор"; sleep 1 ;;
        esac
    done
}

_logs_ssh_success() {
    step "SSH — последние подключения"
    echo
    if [[ -f /var/log/auth.log ]]; then
        grep "Accepted" /var/log/auth.log | tail -30 | \
            awk '{print $1,$2,$3,"  пользователь:",$9,"  с:",$11,"  порт:",$13}'
    else
        journalctl -u ssh -u sshd --no-pager 2>/dev/null | grep "Accepted" | tail -30
    fi
    echo
    press_enter
}

_logs_ssh_fail() {
    step "SSH — неудачные попытки (группировка по IP)"
    echo
    if [[ -f /var/log/auth.log ]]; then
        echo -e "  ${BOLD}Попыток  IP${NC}"
        echo -e "  ──────── ────────────────"
        grep "Failed password" /var/log/auth.log | \
            grep -oP "from \K[\d.]+" | \
            sort | uniq -c | sort -rn | head -20 | \
            awk '{printf "  %-8s %s\n", $1, $2}'
    else
        journalctl -u ssh -u sshd --no-pager 2>/dev/null | \
            grep "Failed password" | \
            grep -oP "from \K[\d.]+" | \
            sort | uniq -c | sort -rn | head -20
    fi
    echo
    press_enter
}

_logs_ufw() {
    step "UFW — топ-10 атакующих IP"
    echo
    if [[ -f /var/log/ufw.log ]]; then
        echo -e "  ${BOLD}Попыток  IP${NC}"
        echo -e "  ──────── ────────────────"
        grep "UFW BLOCK" /var/log/ufw.log | \
            awk '{print $13}' | cut -d= -f2 | \
            sort | uniq -c | sort -rn | head -10 | \
            awk '{printf "  %-8s %s\n", $1, $2}'
    else
        warn "Лог /var/log/ufw.log не найден"
        info "Включи логирование: ufw logging on"
    fi
    echo
    press_enter
}

_logs_fail2ban() {
    step "Fail2ban — активные баны"
    echo
    if command -v fail2ban-client &>/dev/null && service_active "fail2ban"; then
        fail2ban-client status sshd 2>/dev/null || warn "Jail sshd не активен"
        echo
        # Все активные jails
        fail2ban-client status 2>/dev/null | grep "Jail list" | \
            sed 's/.*Jail list:\s*//' | tr ',' '\n' | \
            while read -r jail; do
                jail="${jail// /}"
                [[ -z "$jail" || "$jail" == "sshd" ]] && continue
                echo -e "\n  ${CYAN}Jail: ${jail}${NC}"
                fail2ban-client status "$jail" 2>/dev/null
            done
    else
        warn "Fail2ban не запущен или не установлен"
    fi
    echo
    press_enter
}

_logs_traffic_guard() {
    step "Traffic Guard — заблокированные сканеры"
    echo
    local log_file="/var/log/traffic-guard.log"
    if [[ -f "$log_file" ]]; then
        tail -50 "$log_file"
    else
        warn "Лог ${log_file} не найден"
        info "Убедись что traffic-guard установлен с --enable-logging"
    fi
    echo
    press_enter
}

_logs_who() {
    step "Кто сейчас подключён"
    echo
    who
    echo
    echo -e "  ${BOLD}Активные SSH сессии:${NC}"
    ss -tnp | grep ":$(get_ssh_port) " | awk '{print "  ",$5}' | sed 's/users:.*//'
    echo
    press_enter
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    source "$(dirname "$0")/common.sh"
    check_root
    run_logs
fi
