#!/bin/bash
# Убрать детектируемые сервисы

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
[[ -z "$GREEN" ]] && source "$SCRIPT_DIR/common.sh"

# Сервисы которые выдают VPN/прокси сервер
DETECT_SERVICES=(
    openvpn
    "openvpn@server"
    xl2tpd
    strongswan
    pptpd
    squid
    3proxy
    dante-server
    microsocks
)

run_services() {
    check_root

    step "Убираем детектируемые сервисы"

    local found=0

    for svc in "${DETECT_SERVICES[@]}"; do
        if systemctl list-units --full -all 2>/dev/null | grep -q "$(echo "$svc" | sed 's/@.*//')"; then
            if systemctl is-active --quiet "$svc" 2>/dev/null; then
                warn "АКТИВЕН: ${svc}"
                if confirm "Остановить и отключить ${svc}?"; then
                    systemctl stop "$svc" &>/dev/null
                    systemctl disable "$svc" &>/dev/null
                    ok "${svc} остановлен и отключён"
                fi
                (( found++ ))
            elif systemctl is-enabled --quiet "$svc" 2>/dev/null; then
                warn "ВКЛЮЧЁН (не запущен): ${svc}"
                if confirm "Отключить автозапуск ${svc}?"; then
                    systemctl disable "$svc" &>/dev/null
                    ok "${svc} отключён из автозапуска"
                fi
                (( found++ ))
            fi
        fi
    done

    if (( found == 0 )); then
        ok "Детектируемые сервисы не обнаружены"
    else
        info "Обработано сервисов: ${found}"
    fi

    # Показать открытые публичные порты
    step "Открытые порты (только публичные, без 127.x)"
    echo
    ss -tlnp | grep -v "127\." | grep -v "::1"
    echo

    press_enter
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    source "$(dirname "$0")/common.sh"
    check_root
    run_services
fi
