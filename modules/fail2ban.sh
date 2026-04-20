#!/bin/bash
# Установка и настройка Fail2ban

MODULE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
[[ -z "$GREEN" ]] && source "$MODULE_DIR/common.sh"

run_fail2ban() {
    check_root

    step "Fail2ban"

    # Если уже установлен — показать статус
    if command -v fail2ban-client &>/dev/null; then
        ok "Fail2ban уже установлен"
        _fail2ban_status
        press_enter
        return
    fi

    info "Устанавливаем fail2ban..."
    if ! apt-get install -y fail2ban &>/dev/null; then
        err "Ошибка установки fail2ban"
        press_enter
        return
    fi
    ok "Fail2ban установлен"

    local ssh_port
    ssh_port=$(get_ssh_port)

    step "Создаём /etc/fail2ban/jail.local"

    cat > /etc/fail2ban/jail.local << EOF
[DEFAULT]
bantime  = 3600
findtime = 600
maxretry = 5
ignoreip = 127.0.0.1/8

[sshd]
enabled  = true
port     = ${ssh_port}
filter   = sshd
logpath  = /var/log/auth.log
maxretry = 4
bantime  = 7200
EOF

    ok "Конфиг jail.local создан (SSH порт: ${ssh_port})"

    step "Запускаем fail2ban"
    systemctl enable --now fail2ban &>/dev/null && ok "Fail2ban запущен и добавлен в автозапуск" || \
        err "Ошибка запуска fail2ban"

    _fail2ban_status
    press_enter
}

_fail2ban_status() {
    step "Статус Fail2ban"
    echo
    if service_active "fail2ban"; then
        systemctl status fail2ban --no-pager -l 2>/dev/null | head -10
        echo
        step "Забаненные IP (SSH)"
        fail2ban-client status sshd 2>/dev/null || info "Jail sshd не активен"
    else
        warn "Fail2ban не запущен"
    fi
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    source "$(dirname "$0")/common.sh"
    check_root
    run_fail2ban
fi
