#!/bin/bash
# Traffic Guard — блокировка ТСПУ и сканеров

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
[[ -z "$GREEN" ]] && source "$SCRIPT_DIR/common.sh"

TG_BASE="https://raw.githubusercontent.com/shadow-netlab/traffic-guard-lists/refs/heads/main/public"
TG_GOV="${TG_BASE}/government_networks.list"
TG_SCAN="${TG_BASE}/antiscanner.list"
TG_CRON="/etc/cron.weekly/kalandra-traffic-guard"

run_traffic_guard() {
    check_root

    while true; do
        clear
        echo -e "${BOLD}${WHITE}╔══════════════ TRAFFIC GUARD ══════════════╗${NC}"
        echo -e "${BOLD}${WHITE}║${NC}  ${CYAN}1.${NC}  Установить traffic-guard"
        echo -e "${BOLD}${WHITE}║${NC}  ${CYAN}2.${NC}  Применить оба списка (gov + antiscanner)"
        echo -e "${BOLD}${WHITE}║${NC}  ${CYAN}3.${NC}  Только government_networks (ТСПУ)"
        echo -e "${BOLD}${WHITE}║${NC}  ${CYAN}4.${NC}  Только antiscanner"
        echo -e "${BOLD}${WHITE}║${NC}  ${CYAN}5.${NC}  Обновить списки вручную"
        echo -e "${BOLD}${WHITE}║${NC}  ${CYAN}6.${NC}  Настроить автообновление (cron еженедельно)"
        echo -e "${BOLD}${WHITE}║${NC}  ${CYAN}7.${NC}  Статус — сколько IP заблокировано"
        echo -e "${BOLD}${WHITE}║${NC}  ${GRAY}0.${NC}  Назад"
        echo -e "${BOLD}${WHITE}╚═══════════════════════════════════════════╝${NC}"
        echo -en "  ${YELLOW}→${NC} Выбор: "
        read_tty choice
        choice="${choice//[[:space:]]/}"

        case "$choice" in
            1) _tg_install ;;
            2) _tg_apply_both ;;
            3) _tg_apply_gov ;;
            4) _tg_apply_scan ;;
            5) _tg_apply_both ;;
            6) _tg_setup_cron ;;
            7) _tg_status ;;
            0) return ;;
            *) warn "Неверный выбор"; sleep 1 ;;
        esac
    done
}

run_traffic_guard_quick() {
    check_root

    step "Traffic Guard"
    _tg_install_if_needed || return 1
    _tg_apply_both_core
}

_tg_install() {
    step "Установка traffic-guard"

    if command -v traffic-guard &>/dev/null; then
        ok "traffic-guard уже установлен: $(traffic-guard --version 2>/dev/null || echo 'версия неизвестна')"
        press_enter
        return
    fi

    _tg_install_if_needed

    press_enter
}

_tg_apply_both() {
    step "Применяем оба списка (gov + antiscanner)"
    _tg_check_installed || return

    _tg_apply_both_core
    _tg_status_brief
    press_enter
}

_tg_apply_gov() {
    step "Применяем только government_networks (ТСПУ)"
    _tg_check_installed || return

    info "Загружаем список ТСПУ..."
    if traffic-guard full -u "$TG_GOV" --enable-logging; then
        ok "Список government_networks применён"
    else
        err "Ошибка применения списка"
    fi

    _tg_status_brief
    press_enter
}

_tg_apply_scan() {
    step "Применяем только antiscanner"
    _tg_check_installed || return

    info "Загружаем список антисканера..."
    if traffic-guard full -u "$TG_SCAN" --enable-logging; then
        ok "Список antiscanner применён"
    else
        err "Ошибка применения списка"
    fi

    _tg_status_brief
    press_enter
}

_tg_setup_cron() {
    step "Автообновление (cron еженедельно)"

    cat > "$TG_CRON" << EOF
#!/bin/bash
# Kalandra — еженедельное обновление traffic-guard списков
traffic-guard full \\
  -u ${TG_GOV} \\
  -u ${TG_SCAN}
EOF

    chmod +x "$TG_CRON"
    ok "Cron задача создана: ${TG_CRON}"
    info "Списки будут обновляться каждую неделю автоматически."

    press_enter
}

_tg_status() {
    step "Статус Traffic Guard"
    _tg_check_installed || return

    echo
    info "Заблокированных IP в ipset:"
    local count_v4 count_v6
    count_v4=$(ipset list SCANNERS-BLOCK-V4 2>/dev/null | grep "Number of entries" | awk '{print $NF}')
    count_v6=$(ipset list SCANNERS-BLOCK-V6 2>/dev/null | grep "Number of entries" | awk '{print $NF}')

    [[ -n "$count_v4" ]] && echo -e "  ${GREEN}IPv4: ${count_v4} IP${NC}" || warn "ipset SCANNERS-BLOCK-V4 не найден"
    [[ -n "$count_v6" ]] && echo -e "  ${GREEN}IPv6: ${count_v6} IP${NC}"

    echo
    info "Последние заблокированные (из лога):"
    local log_file="/var/log/traffic-guard.log"
    if [[ -f "$log_file" ]]; then
        tail -20 "$log_file"
    else
        warn "Лог ${log_file} не найден"
    fi

    [[ -f "$TG_CRON" ]] && ok "Автообновление: настроено" || warn "Автообновление: не настроено"

    press_enter
}

_tg_status_brief() {
    local count_v4
    count_v4=$(ipset list SCANNERS-BLOCK-V4 2>/dev/null | grep "Number of entries" | awk '{print $NF}')
    [[ -n "$count_v4" ]] && info "Заблокировано IPv4: ${count_v4}"
}

_tg_check_installed() {
    if ! command -v traffic-guard &>/dev/null; then
        err "traffic-guard не установлен. Выбери пункт 1."
        press_enter
        return 1
    fi
}

_tg_install_if_needed() {
    if command -v traffic-guard &>/dev/null; then
        ok "traffic-guard уже установлен: $(traffic-guard --version 2>/dev/null || echo 'версия неизвестна')"
        return 0
    fi

    info "Загружаем и устанавливаем traffic-guard..."
    if curl -fsSL https://raw.githubusercontent.com/dotX12/traffic-guard/master/install.sh | bash; then
        ok "traffic-guard установлен"
        return 0
    fi

    err "Ошибка установки traffic-guard"
    info "Проверь: https://github.com/dotX12/traffic-guard"
    return 1
}

_tg_apply_both_core() {
    info "Загружаем и применяем списки — это может занять минуту..."
    if traffic-guard full \
        -u "$TG_GOV" \
        -u "$TG_SCAN" \
        --enable-logging; then
        ok "Оба списка применены"
        return 0
    fi

    err "Ошибка применения списков"
    return 1
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    source "$(dirname "$0")/common.sh"
    check_root
    run_traffic_guard
fi
