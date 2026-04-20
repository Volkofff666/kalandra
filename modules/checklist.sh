#!/bin/bash
# Чеклист антидетекта

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
[[ -z "$GREEN" ]] && source "$SCRIPT_DIR/common.sh"

run_checklist() {
    check_root

    step "Чеклист антидетекта"
    echo

    local score=0 total=18
    local checks=()  # массив строк для вывода

    _check() {
        local label="$1" result="$2"
        if [[ "$result" == "ok" ]]; then
            checks+=("  ${GREEN}[✓]${NC} ${label}")
            (( score++ ))
        else
            checks+=("  ${RED}[✗]${NC} ${label}")
        fi
    }

    local ssh_port
    ssh_port=$(get_ssh_port)

    # 1. SSH на нестандартном порту
    [[ "$ssh_port" != "22" ]] && _check "SSH на нестандартном порту (${ssh_port})" "ok" || \
        _check "SSH на нестандартном порту (сейчас: 22)" "fail"

    # 2. SSH баннер скрыт
    if grep -qE "^DebianBanner no" /etc/ssh/sshd_config 2>/dev/null && \
       grep -qE "^Banner none" /etc/ssh/sshd_config 2>/dev/null; then
        _check "SSH баннер скрыт" "ok"
    else
        _check "SSH баннер скрыт" "fail"
    fi

    # 3. Парольная аутентификация отключена
    if grep -qE "^PasswordAuthentication no" /etc/ssh/sshd_config 2>/dev/null; then
        _check "Парольная аутентификация отключена" "ok"
    else
        _check "Парольная аутентификация отключена" "fail"
    fi

    # 4. UFW включён
    if ufw status 2>/dev/null | grep -q "Status: active"; then
        _check "UFW включён" "ok"
    else
        _check "UFW включён" "fail"
    fi

    # 5. UFW default deny incoming
    if ufw status verbose 2>/dev/null | grep -q "Default:.*deny.*incoming"; then
        _check "UFW: default deny incoming" "ok"
    else
        _check "UFW: default deny incoming" "fail"
    fi

    # 6. ICMP ping заблокирован
    if grep -q "echo-request -j DROP" /etc/ufw/before.rules 2>/dev/null; then
        _check "ICMP ping заблокирован" "ok"
    else
        _check "ICMP ping заблокирован" "fail"
    fi

    # 7. OpenVPN не запущен
    if ! (service_active "openvpn" || service_active "openvpn@server"); then
        _check "OpenVPN не запущен" "ok"
    else
        _check "OpenVPN НЕ ЗАПУЩЕН (детектируется!)" "fail"
    fi

    # 8. Порт 1194 закрыт
    if ! ss -tlnp 2>/dev/null | grep -q ":1194 "; then
        _check "Порт 1194 (OpenVPN) закрыт" "ok"
    else
        _check "Порт 1194 (OpenVPN) закрыт" "fail"
    fi

    # 9. Порт 3389 закрыт
    if ! ss -tlnp 2>/dev/null | grep -q ":3389 "; then
        _check "Порт 3389 (RDP) закрыт" "ok"
    else
        _check "Порт 3389 (RDP) закрыт" "fail"
    fi

    # 10. Порт 1080 закрыт
    if ! ss -tlnp 2>/dev/null | grep -q ":1080 "; then
        _check "Порт 1080 (SOCKS5) закрыт" "ok"
    else
        _check "Порт 1080 (SOCKS5) закрыт" "fail"
    fi

    # 11. Fail2ban активен
    service_active "fail2ban" && _check "Fail2ban активен" "ok" || \
        _check "Fail2ban активен" "fail"

    # 12. Sysctl hardening применён
    if [[ -f /etc/sysctl.d/99-kalandra.conf ]]; then
        _check "Sysctl hardening применён" "ok"
    else
        _check "Sysctl hardening применён" "fail"
    fi

    # 13. BBR активен
    local tcp_cc
    tcp_cc=$(sysctl -n net.ipv4.tcp_congestion_control 2>/dev/null)
    [[ "$tcp_cc" == "bbr" ]] && _check "BBR активен" "ok" || \
        _check "BBR активен (сейчас: ${tcp_cc:-unknown})" "fail"

    # 14. IPv6 отключён (опционально)
    local ipv6_disabled
    ipv6_disabled=$(cat /proc/sys/net/ipv6/conf/all/disable_ipv6 2>/dev/null)
    if [[ "$ipv6_disabled" == "1" ]]; then
        _check "IPv6 отключён [опционально]" "ok"
    else
        _check "IPv6 отключён [опционально — пропустить если используется]" "fail"
    fi

    # 15. Traffic Guard установлен и активен
    if command -v traffic-guard &>/dev/null; then
        _check "Traffic Guard установлен" "ok"
    else
        _check "Traffic Guard установлен" "fail"
    fi

    # 16. Port Knocking настроен (опционально)
    if [[ -f /etc/knockd.conf ]] && service_active "knockd"; then
        _check "Port Knocking настроен [опционально]" "ok"
    else
        _check "Port Knocking настроен [опционально]" "fail"
    fi

    # 17. Telegram алерты настроены (опционально)
    if [[ -f "$KALANDRA_CONF" ]] && grep -q "^TELEGRAM_TOKEN=" "$KALANDRA_CONF"; then
        _check "Telegram алерты настроены [опционально]" "ok"
    else
        _check "Telegram алерты настроены [опционально]" "fail"
    fi

    # 18. Автообновление списков
    if [[ -f /etc/cron.weekly/kalandra-traffic-guard ]]; then
        _check "Автообновление Traffic Guard списков" "ok"
    else
        _check "Автообновление Traffic Guard списков" "fail"
    fi

    # Вывод результатов
    echo -e "${BOLD}${WHITE}╔══════════════════ ЧЕКЛИСТ ══════════════════╗${NC}"
    for line in "${checks[@]}"; do
        echo -e "${BOLD}${WHITE}║${NC} ${line}"
    done
    echo -e "${BOLD}${WHITE}╚═════════════════════════════════════════════╝${NC}"
    echo

    # Итоговый счёт
    local pct=$(( score * 100 / total ))
    echo -en "  ${BOLD}Итог: "
    if (( score >= 15 )); then
        echo -en "${GREEN}"
    elif (( score >= 10 )); then
        echo -en "${YELLOW}"
    else
        echo -en "${RED}"
    fi
    echo -e "${score}/${total}${NC}  ["
    echo -en "  "; bar "$pct"; echo -e "] ${pct}%"
    echo

    # Рекомендации
    if (( score < total )); then
        step "Рекомендации"
        if ! ufw status 2>/dev/null | grep -q "Status: active"; then
            warn "Запусти модуль 2 — Firewall (UFW)"
        fi
        if ! grep -q "echo-request -j DROP" /etc/ufw/before.rules 2>/dev/null; then
            warn "Запусти модуль 3 — блокировка ICMP ping"
        fi
        if ! command -v traffic-guard &>/dev/null; then
            warn "Запусти модуль 10 — установи Traffic Guard (ключевой для защиты от ТСПУ)"
        fi
        if ! service_active "fail2ban"; then
            warn "Запусти модуль 6 — Fail2ban"
        fi
        if ! [[ -f /etc/sysctl.d/99-kalandra.conf ]]; then
            warn "Запусти модуль 5 — Sysctl + BBR"
        fi
    else
        ok "Отличная работа! Сервер максимально защищён."
    fi

    press_enter
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    source "$(dirname "$0")/common.sh"
    check_root
    run_checklist
fi
