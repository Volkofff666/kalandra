#!/bin/bash
# Telegram алерты

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
[[ -z "$GREEN" ]] && source "$SCRIPT_DIR/common.sh"

TG_CONF="/etc/kalandra/telegram.conf"
SSH_MONITOR="/etc/kalandra/ssh-monitor.sh"
SSH_MONITOR_SERVICE="/etc/systemd/system/kalandra-ssh-monitor.service"
LOAD_MONITOR_SERVICE="/etc/systemd/system/kalandra-load-monitor.service"
LOAD_MONITOR="/etc/kalandra/load-monitor.sh"
REBOOT_ALERT="/etc/kalandra/reboot-alert.sh"
REBOOT_ALERT_SERVICE="/etc/systemd/system/kalandra-reboot-alert.service"

run_telegram() {
    check_root

    step "Telegram алерты"

    # Проверка существующей конфигурации
    if [[ -f "$TG_CONF" ]] && grep -q "^TELEGRAM_TOKEN=" "$TG_CONF"; then
        local existing_token
        existing_token=$(grep "^TELEGRAM_TOKEN=" "$TG_CONF" | cut -d= -f2-)
        info "Telegram уже настроен (токен: ${existing_token:0:10}...)"
        confirm "Перенастроить?" || { press_enter; return; }
    fi

    # Принимаем токен
    step "Настройка бота"
    echo -e "  ${CYAN}Инструкция:${NC}"
    echo -e "  1. Открой @BotFather в Telegram"
    echo -e "  2. /newbot → получи Bot Token"
    echo -e "  3. Напиши своему боту любое сообщение"
    echo -e "  4. Открой: https://api.telegram.org/bot<TOKEN>/getUpdates — найди chat_id"
    echo

    echo -en "  ${YELLOW}?${NC} Bot Token: "
    read_tty bot_token

    echo -en "  ${YELLOW}?${NC} Chat ID: "
    read_tty chat_id

    if [[ -z "$bot_token" || -z "$chat_id" ]]; then
        err "Токен и Chat ID не могут быть пустыми"
        press_enter
        return
    fi

    # Тестовое сообщение
    step "Отправляем тестовое сообщение"
    local test_msg
    test_msg="🔐 [Kalandra] Тест алертов
Сервер: $(hostname) ($(curl -s --max-time 3 https://api.ipify.org 2>/dev/null || echo 'неизвестен'))
Время: $(date '+%Y-%m-%d %H:%M:%S')
Статус: Настройка завершена ✓"

    local result
    result=$(curl -s --max-time 10 \
        "https://api.telegram.org/bot${bot_token}/sendMessage" \
        -d "chat_id=${chat_id}" \
        -d "text=${test_msg}" 2>/dev/null)

    if echo "$result" | grep -q '"ok":true'; then
        ok "Тестовое сообщение отправлено!"
    else
        err "Ошибка отправки. Проверь токен и Chat ID."
        info "Ответ сервера: $result"
        press_enter
        return
    fi

    # Сохраняем
    mkdir -p /etc/kalandra
    cat > "$TG_CONF" << EOF
TELEGRAM_TOKEN=${bot_token}
TELEGRAM_CHAT_ID=${chat_id}
EOF
    chmod 600 "$TG_CONF"
    save_conf "TELEGRAM_TOKEN" "$bot_token"
    save_conf "TELEGRAM_CHAT_ID" "$chat_id"
    ok "Конфиг сохранён: ${TG_CONF}"

    # SSH монитор
    step "Создаём SSH монитор"
    _create_ssh_monitor
    _create_load_monitor
    _create_reboot_alert
    _install_services

    press_enter
}

_tg_send() {
    local token="$1" chat_id="$2" msg="$3"
    curl -s --max-time 5 \
        "https://api.telegram.org/bot${token}/sendMessage" \
        -d "chat_id=${chat_id}" \
        -d "text=${msg}" &>/dev/null
}

_create_ssh_monitor() {
    cat > "$SSH_MONITOR" << 'SCRIPT'
#!/bin/bash
source /etc/kalandra/telegram.conf

server_ip=$(hostname -I 2>/dev/null | awk '{print $1}')
[[ -z "$server_ip" ]] && server_ip=$(hostname)

send_alert() {
    curl -s --max-time 5 \
        "https://api.telegram.org/bot${TELEGRAM_TOKEN}/sendMessage" \
        -d "chat_id=${TELEGRAM_CHAT_ID}" \
        -d "text=$1" &>/dev/null
}

declare -A fail_counts

journalctl -n 0 -u ssh -u sshd -u fail2ban -f --no-pager 2>/dev/null | while read -r line; do
    ts=$(date '+%Y-%m-%d %H:%M:%S')
    hostname=$(hostname)

    # Успешный вход
    if echo "$line" | grep -q "Accepted"; then
        user=$(echo "$line" | grep -oP "for \K\S+")
        from_ip=$(echo "$line" | grep -oP "from \K[\d.]+")
        send_alert "🔐 [Kalandra] SSH подключение
Сервер: ${hostname} (${server_ip})
Пользователь: ${user}
Откуда: ${from_ip}
Время: ${ts}"
    fi

    # Неудачная попытка
    if echo "$line" | grep -q "Failed password"; then
        from_ip=$(echo "$line" | grep -oP "from \K[\d.]+")
        fail_counts[$from_ip]=$(( ${fail_counts[$from_ip]:-0} + 1 ))
        if (( fail_counts[$from_ip] >= 5 )) && (( fail_counts[$from_ip] % 5 == 0 )); then
            send_alert "⚠️ [Kalandra] Брутфорс SSH
Сервер: ${hostname}
IP атакующего: ${from_ip}
Попыток: ${fail_counts[$from_ip]}"
        fi
    fi

    # Fail2ban бан
    if echo "$line" | grep -q "Ban "; then
        banned_ip=$(echo "$line" | grep -oP "Ban \K[\d.]+")
        send_alert "🚨 [Kalandra] Fail2ban бан
Сервер: ${hostname}
Заблокирован IP: ${banned_ip}
Причина: SSH брутфорс"
    fi
done
SCRIPT

    chmod +x "$SSH_MONITOR"
    ok "SSH монитор создан: ${SSH_MONITOR}"
}

_create_load_monitor() {
    cat > "$LOAD_MONITOR" << 'SCRIPT'
#!/bin/bash
source /etc/kalandra/telegram.conf

send_alert() {
    curl -s --max-time 5 \
        "https://api.telegram.org/bot${TELEGRAM_TOKEN}/sendMessage" \
        -d "chat_id=${TELEGRAM_CHAT_ID}" \
        -d "text=$1" &>/dev/null
}

while true; do
    cpu=$(top -bn1 | grep "Cpu(s)" | awk '{print int($2)}')
    mem_total=$(free -m | awk '/^Mem:/ {print $2}')
    mem_used=$(free -m | awk '/^Mem:/ {print $3}')
    mem_pct=$(( mem_used * 100 / mem_total ))

    if (( cpu > 90 || mem_pct > 90 )); then
        send_alert "⚠️ [Kalandra] Высокая нагрузка
Сервер: $(hostname)
CPU: ${cpu}%
RAM: ${mem_pct}% (${mem_used}/${mem_total} MB)"
    fi

    sleep 60
done
SCRIPT

    chmod +x "$LOAD_MONITOR"
    ok "Монитор нагрузки создан: ${LOAD_MONITOR}"
}

_create_reboot_alert() {
    cat > "$REBOOT_ALERT" << 'SCRIPT'
#!/bin/bash
source /etc/kalandra/telegram.conf

server_ip=$(hostname -I 2>/dev/null | awk '{print $1}')
[[ -z "$server_ip" ]] && server_ip=$(hostname)

curl -s --max-time 10 \
    "https://api.telegram.org/bot${TELEGRAM_TOKEN}/sendMessage" \
    -d "chat_id=${TELEGRAM_CHAT_ID}" \
    -d "text=🔄 [Kalandra] Сервер перезагружен
Hostname: $(hostname)
IP: ${server_ip}
Время: $(date '+%Y-%m-%d %H:%M:%S')" &>/dev/null
SCRIPT

    chmod +x "$REBOOT_ALERT"
    ok "Скрипт reboot-алерта создан: ${REBOOT_ALERT}"
}

_install_services() {
    step "Устанавливаем systemd сервисы"

    cat > "$SSH_MONITOR_SERVICE" << EOF
[Unit]
Description=Kalandra SSH Monitor
After=network.target ssh.service

[Service]
ExecStart=${SSH_MONITOR}
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

    cat > "$LOAD_MONITOR_SERVICE" << EOF
[Unit]
Description=Kalandra Load Monitor
After=network.target

[Service]
ExecStart=${LOAD_MONITOR}
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

    cat > "$REBOOT_ALERT_SERVICE" << EOF
[Unit]
Description=Kalandra Reboot Alert
After=network-online.target
Wants=network-online.target

[Service]
Type=oneshot
ExecStart=${REBOOT_ALERT}

[Install]
WantedBy=multi-user.target
EOF

    systemctl daemon-reload &>/dev/null
    systemctl enable --now kalandra-ssh-monitor &>/dev/null && ok "SSH монитор запущен" || warn "Ошибка запуска SSH монитора"
    systemctl enable --now kalandra-load-monitor &>/dev/null && ok "Монитор нагрузки запущен" || warn "Ошибка запуска монитора нагрузки"
    rm -f /etc/cron.d/kalandra-reboot-alert 2>/dev/null
    systemctl enable kalandra-reboot-alert &>/dev/null && ok "Алерт при перезагрузке настроен" || warn "Ошибка настройки reboot-алерта"
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    source "$(dirname "$0")/common.sh"
    check_root
    run_telegram
fi
