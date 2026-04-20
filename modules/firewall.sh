#!/bin/bash
# Firewall — настройка UFW

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
[[ -z "$GREEN" ]] && source "$SCRIPT_DIR/common.sh"

# Порты которые выдают VPN/прокси
DANGEROUS_PORTS=(1194 500 4500 1080 3128 8118 8123 3389 51820)

run_firewall() {
    check_root

    step "Настройка Firewall (UFW)"

    # Установка UFW если нет
    if ! command -v ufw &>/dev/null; then
        info "Устанавливаем UFW..."
        apt-get install -y ufw &>/dev/null && ok "UFW установлен" || { err "Ошибка установки UFW"; press_enter; return; }
    fi

    local ssh_port
    ssh_port=$(get_ssh_port)

    # Дефолтные политики
    step "Устанавливаем политики по умолчанию"
    ufw default deny incoming &>/dev/null && ok "default deny incoming"
    ufw default allow outgoing &>/dev/null && ok "default allow outgoing"

    # SSH порт — открываем первым чтобы не потерять доступ
    step "Открываем SSH порт ${ssh_port}"
    ufw allow "${ssh_port}/tcp" &>/dev/null && ok "SSH порт ${ssh_port}/tcp открыт"

    # Закрываем опасные порты явно
    step "Закрываем VPN/прокси порты"
    for port in "${DANGEROUS_PORTS[@]}"; do
        ufw deny "${port}" &>/dev/null
        info "Закрыт порт ${port}"
    done
    ok "Опасные порты заблокированы"

    # HTTPS
    step "HTTPS (443/tcp)"
    if confirm "Открыть порт 443/tcp (HTTPS)?"; then
        ufw allow 443/tcp &>/dev/null && ok "443/tcp открыт"
    fi

    # Дополнительные порты
    step "Дополнительные порты"
    info "Введи дополнительные порты через запятую (например: 8443,2053) или Enter для пропуска"
    echo -en "  ${YELLOW}→${NC} Порты: "
    read -r extra_ports

    if [[ -n "$extra_ports" ]]; then
        IFS=',' read -ra ports_arr <<< "$extra_ports"
        for p in "${ports_arr[@]}"; do
            p="${p// /}"
            if [[ "$p" =~ ^[0-9]+(/tcp|/udp)?$ ]]; then
                ufw allow "$p" &>/dev/null && ok "Порт $p открыт"
            else
                warn "Некорректный порт: $p — пропущен"
            fi
        done
    fi

    # Включение UFW
    step "Включаем UFW"
    echo
    warn "Убедись что SSH порт ${ssh_port} открыт (выше должно быть 'SSH порт ${ssh_port}/tcp открыт')."
    if confirm "Включить UFW?"; then
        ufw --force enable &>/dev/null && ok "UFW включён" || err "Ошибка включения UFW"
    else
        info "UFW не включён. Запусти 'ufw enable' вручную."
    fi

    # Показать статус
    step "Статус UFW"
    echo
    ufw status numbered
    echo

    press_enter
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    source "$(dirname "$0")/common.sh"
    check_root
    run_firewall
fi
