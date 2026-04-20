#!/bin/bash
# Отключение IPv6

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
[[ -z "$GREEN" ]] && source "$SCRIPT_DIR/common.sh"

SYSCTL_FILE="/etc/sysctl.d/99-kalandra.conf"

run_ipv6() {
    check_root

    step "Отключение IPv6"

    # Текущий статус
    local ipv6_status
    if [[ -f /proc/sys/net/ipv6/conf/all/disable_ipv6 ]] && \
       [[ "$(cat /proc/sys/net/ipv6/conf/all/disable_ipv6)" == "1" ]]; then
        ok "IPv6 уже отключён"
        press_enter
        return
    else
        warn "IPv6 в данный момент ${RED}включён${NC}"
    fi

    echo
    echo -e "  ${YELLOW}${BOLD}⚠  ВНИМАНИЕ:${NC}"
    echo -e "  ${YELLOW}Не отключай IPv6 если Remnanode работает через IPv6-адрес.${NC}"
    echo -e "  ${YELLOW}Проверь: ip -6 addr show и конфиги Xray/VLESS перед отключением.${NC}"
    echo

    confirm "Отключить IPv6?" || { info "Отменено."; press_enter; return; }

    # Добавляем в sysctl
    step "Добавляем параметры в ${SYSCTL_FILE}"

    mkdir -p "$(dirname "$SYSCTL_FILE")"

    # Убираем старые записи если есть
    sed -i '/net\.ipv6\.conf.*disable_ipv6/d' "$SYSCTL_FILE" 2>/dev/null

    cat >> "$SYSCTL_FILE" << 'EOF'

# Отключение IPv6
net.ipv6.conf.all.disable_ipv6 = 1
net.ipv6.conf.default.disable_ipv6 = 1
net.ipv6.conf.lo.disable_ipv6 = 1
EOF

    sysctl -p "$SYSCTL_FILE" &>/dev/null && ok "Параметры sysctl применены" || warn "Ошибки при применении sysctl"

    # Обновляем UFW
    step "Обновляем /etc/default/ufw"
    if [[ -f /etc/default/ufw ]]; then
        sed -i 's/^IPV6=yes/IPV6=no/' /etc/default/ufw
        ok "/etc/default/ufw: IPV6=no"

        if command -v ufw &>/dev/null && ufw status | grep -q "Status: active"; then
            ufw reload &>/dev/null && ok "UFW перезагружен"
        fi
    else
        warn "/etc/default/ufw не найден"
    fi

    # Проверка
    step "Проверка"
    sleep 1
    local disabled
    disabled=$(cat /proc/sys/net/ipv6/conf/all/disable_ipv6 2>/dev/null)
    if [[ "$disabled" == "1" ]]; then
        ok "IPv6 успешно отключён"
    else
        warn "IPv6 ещё активен — может потребоваться перезагрузка сервера"
    fi

    press_enter
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    source "$(dirname "$0")/common.sh"
    check_root
    run_ipv6
fi
