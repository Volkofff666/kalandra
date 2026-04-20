#!/bin/bash
# Sysctl hardening + BBR

MODULE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
[[ -z "$GREEN" ]] && source "$MODULE_DIR/common.sh"

SYSCTL_FILE="/etc/sysctl.d/99-kalandra.conf"

run_sysctl() {
    check_root

    step "Sysctl hardening + BBR"

    if [[ -f "$SYSCTL_FILE" ]]; then
        warn "Файл ${SYSCTL_FILE} уже существует — будет перезаписан."
        confirm "Продолжить?" || { info "Отменено."; press_enter; return; }
    fi

    step "Записываем ${SYSCTL_FILE}"

    cat > "$SYSCTL_FILE" << 'EOF'
# Kalandra sysctl hardening

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
EOF

    ok "Файл ${SYSCTL_FILE} записан"

    # Применяем
    step "Применяем параметры"
    if sysctl -p "$SYSCTL_FILE" &>/dev/null; then
        ok "Параметры применены"
    else
        warn "sysctl -p вернул ошибки (некоторые параметры могут не поддерживаться ядром)"
        sysctl -p "$SYSCTL_FILE" 2>&1 | grep -i "error\|unknown" | while read -r line; do
            err "$line"
        done
    fi

    # Проверка BBR
    step "Проверка BBR"
    local tcp_cc
    tcp_cc=$(sysctl -n net.ipv4.tcp_congestion_control 2>/dev/null)
    if [[ "$tcp_cc" == "bbr" ]]; then
        ok "BBR активен (net.ipv4.tcp_congestion_control = bbr)"
    else
        warn "BBR не активен: ${tcp_cc}"
        info "Проверь поддержку BBR: lsmod | grep bbr"
    fi

    # Проверка форвардинга
    local ip_fwd
    ip_fwd=$(sysctl -n net.ipv4.ip_forward 2>/dev/null)
    if [[ "$ip_fwd" == "1" ]]; then
        ok "IP форвардинг включён (нужен для VPN)"
    else
        err "IP форвардинг не включён"
    fi

    press_enter
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    source "$(dirname "$0")/common.sh"
    check_root
    run_sysctl
fi
