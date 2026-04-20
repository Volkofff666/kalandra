#!/bin/bash
# Port Knocking через knockd

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
[[ -z "$GREEN" ]] && source "$SCRIPT_DIR/common.sh"

run_port_knock() {
    check_root

    step "Port Knocking (knockd)"

    info "Концепция: SSH порт не виден снаружи пока не постучишься в нужную последовательность портов."
    echo

    # Установка knockd
    if ! command -v knockd &>/dev/null; then
        info "Устанавливаем knockd..."
        if ! apt-get install -y knockd &>/dev/null; then
            err "Ошибка установки knockd"
            press_enter
            return
        fi
        ok "knockd установлен"
    else
        ok "knockd уже установлен"
    fi

    local ssh_port iface
    ssh_port=$(get_ssh_port)
    iface=$(get_iface)

    # Генерация случайной последовательности
    local p1 p2 p3
    p1=$(( RANDOM % 58976 + 1024 ))
    p2=$(( RANDOM % 58976 + 1024 ))
    p3=$(( RANDOM % 58976 + 1024 ))
    # Убедимся что порты не совпадают
    while [[ "$p2" == "$p1" ]]; do p2=$(( RANDOM % 58976 + 1024 )); done
    while [[ "$p3" == "$p1" || "$p3" == "$p2" ]]; do p3=$(( RANDOM % 58976 + 1024 )); done

    step "Сгенерирована последовательность портов"
    echo -e "  ${MAGENTA}Открытие SSH:  ${BOLD}${p1} → ${p2} → ${p3}${NC}"
    echo -e "  ${MAGENTA}Закрытие SSH:  ${BOLD}${p3} → ${p2} → ${p1}${NC}"
    echo

    if ! confirm "Использовать эту последовательность?"; then
        info "Введи свои порты (1024-60000):"
        echo -en "  Порт 1: "; read -r p1
        echo -en "  Порт 2: "; read -r p2
        echo -en "  Порт 3: "; read -r p3
    fi

    step "Записываем /etc/knockd.conf"

    cat > /etc/knockd.conf << EOF
[options]
    UseSyslog
    Interface = ${iface}

[openSSH]
    sequence    = ${p1},${p2},${p3}
    seq_timeout = 10
    command     = /sbin/iptables -I INPUT -s %IP% -p tcp --dport ${ssh_port} -j ACCEPT
    tcpflags    = syn

[closeSSH]
    sequence    = ${p3},${p2},${p1}
    seq_timeout = 10
    command     = /sbin/iptables -D INPUT -s %IP% -p tcp --dport ${ssh_port} -j ACCEPT
    tcpflags    = syn
EOF

    ok "Конфиг /etc/knockd.conf создан"

    # Включаем knockd
    sed -i 's/START_KNOCKD=0/START_KNOCKD=1/' /etc/default/knockd 2>/dev/null
    systemctl enable --now knockd &>/dev/null && ok "knockd запущен" || warn "Проблема с запуском knockd"

    # Сохраняем последовательность
    save_conf "KNOCK_SEQUENCE" "${p1},${p2},${p3}"

    # Получаем внешний IP
    local server_ip
    server_ip=$(curl -s --max-time 3 https://api.ipify.org 2>/dev/null || echo "SERVER_IP")

    # Инструкция
    step "Команды подключения"
    echo
    echo -e "${BOLD}${CYAN}══ Открыть SSH (стучим, потом коннектимся) ══${NC}"
    echo -e "  ${WHITE}Linux/Mac:${NC}"
    echo -e "  ${GRAY}knock ${server_ip} ${p1} ${p2} ${p3}${NC}"
    echo -e "  ${GRAY}ssh -p ${ssh_port} root@${server_ip}${NC}"
    echo
    echo -e "  ${WHITE}Без knock-клиента (через nmap):${NC}"
    echo -e "  ${GRAY}nmap -Pn --host-timeout 201 --max-retries 0 -p ${p1} ${server_ip}${NC}"
    echo -e "  ${GRAY}nmap -Pn --host-timeout 201 --max-retries 0 -p ${p2} ${server_ip}${NC}"
    echo -e "  ${GRAY}nmap -Pn --host-timeout 201 --max-retries 0 -p ${p3} ${server_ip}${NC}"
    echo
    echo -e "${BOLD}${CYAN}══ Закрыть SSH после работы ══${NC}"
    echo -e "  ${GRAY}knock ${server_ip} ${p3} ${p2} ${p1}${NC}"
    echo
    echo -e "${BOLD}${CYAN}══ Установка knock-клиента ══${NC}"
    echo -e "  ${WHITE}Linux:${NC}   ${GRAY}apt install knockd${NC}"
    echo -e "  ${WHITE}Mac:${NC}     ${GRAY}brew install knock${NC}"
    echo -e "  ${WHITE}Windows:${NC} ${GRAY}https://www.zeroflux.org/projects/knock${NC}"
    echo

    echo -e "  ${RED}${BOLD}⚠  Следующий шаг:${NC}"
    echo -e "  ${RED}Закрой SSH порт ${ssh_port} в UFW — knockd откроет его динамически:${NC}"
    echo -e "  ${GRAY}ufw delete allow ${ssh_port}/tcp${NC}"
    echo

    confirm "Закрыть SSH порт ${ssh_port} в UFW сейчас?" && \
        ufw delete allow "${ssh_port}/tcp" &>/dev/null && \
        ok "Порт ${ssh_port} закрыт в UFW" || \
        warn "Не забудь закрыть порт ${ssh_port} в UFW вручную"

    press_enter
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    source "$(dirname "$0")/common.sh"
    check_root
    run_port_knock
fi
