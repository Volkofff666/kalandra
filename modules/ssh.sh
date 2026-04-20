#!/bin/bash
# SSH Hardening

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
[[ -z "$GREEN" ]] && source "$SCRIPT_DIR/common.sh"

run_ssh() {
    check_root

    local sshd_config="/etc/ssh/sshd_config"
    local current_port
    current_port=$(get_ssh_port)

    step "SSH Hardening"
    info "Текущий SSH порт: ${current_port}"
    echo

    # Отключение socket activation (Ubuntu 22.04+)
    if systemctl list-units --full -all 2>/dev/null | grep -q "ssh.socket"; then
        step "Отключаем ssh.socket (socket activation)"
        systemctl disable --now ssh.socket &>/dev/null && \
            ok "ssh.socket отключён" || warn "Не удалось отключить ssh.socket"
    fi

    # Смена порта
    step "Смена SSH порта"
    echo -en "  ${YELLOW}?${NC} Новый SSH порт (Enter = оставить ${current_port}, рекомендуется 666): "
    read_tty new_port

    if [[ -z "$new_port" ]]; then
        new_port="$current_port"
        info "Порт оставлен: ${new_port}"
    elif [[ ! "$new_port" =~ ^[0-9]+$ ]] || (( new_port < 1 || new_port > 65535 )); then
        err "Некорректный порт. Оставляем ${current_port}."
        new_port="$current_port"
    else
        info "Новый порт: ${new_port}"
    fi

    # Применяем порт
    if grep -q "^Port " "$sshd_config"; then
        sed -i "s/^Port .*/Port ${new_port}/" "$sshd_config"
    else
        sed -i "s/^#Port.*/Port ${new_port}/" "$sshd_config"
        grep -q "^Port " "$sshd_config" || echo "Port ${new_port}" >> "$sshd_config"
    fi

    # Скрыть баннер
    step "Скрываем SSH баннер"
    _sshd_set "DebianBanner" "no"
    _sshd_set "Banner" "none"
    ok "Баннер SSH скрыт (DebianBanner no, Banner none)"

    # PermitRootLogin
    step "PermitRootLogin"
    info "Текущее значение: $(grep -E "^PermitRootLogin|^#PermitRootLogin" "$sshd_config" | head -1 || echo 'не задано')"
    if confirm "Отключить вход root по SSH? (PermitRootLogin no)"; then
        _sshd_set "PermitRootLogin" "no"
        ok "PermitRootLogin no применён"
    else
        info "PermitRootLogin оставлен без изменений"
    fi

    # PasswordAuthentication
    step "Аутентификация по паролю"
    echo
    echo -e "  ${RED}${BOLD}⚠  ВНИМАНИЕ: Убедись что SSH-ключ уже добавлен в authorized_keys"
    echo -e "     и ты можешь войти по ключу В ДРУГОЙ СЕССИИ."
    echo -e "     Иначе потеряешь доступ к серверу!${NC}"
    echo
    if confirm "Отключить вход по паролю? (PasswordAuthentication no)"; then
        _sshd_set "PasswordAuthentication" "no"
        ok "Аутентификация по паролю отключена"
    else
        info "PasswordAuthentication оставлен без изменений"
    fi

    # Открыть новый порт в UFW
    if [[ "$new_port" != "$current_port" ]]; then
        step "Обновляем UFW"
        if command -v ufw &>/dev/null; then
            ufw allow "${new_port}/tcp" &>/dev/null && ok "Порт ${new_port}/tcp открыт в UFW"
            if [[ "$current_port" != "22" ]]; then
                confirm "Закрыть старый порт ${current_port} в UFW?" && \
                    ufw delete allow "${current_port}/tcp" &>/dev/null && \
                    ok "Старый порт ${current_port} закрыт"
            fi
        else
            warn "UFW не найден, порт нужно открыть вручную"
        fi
    fi

    # Перезапуск SSH
    step "Перезапуск SSH"
    echo
    warn "ВАЖНО: Не закрывай текущую сессию! Проверь подключение на порту ${new_port} в другой вкладке."
    echo
    if confirm "Перезапустить SSH сейчас?"; then
        if systemctl restart ssh 2>/dev/null || systemctl restart sshd 2>/dev/null; then
            ok "SSH перезапущен на порту ${new_port}"
            save_conf "SSH_PORT" "$new_port"
        else
            err "Ошибка перезапуска SSH"
        fi
    else
        info "Перезапуск отложен. Запусти вручную: systemctl restart ssh"
    fi

    press_enter
}

# Установить или заменить параметр в sshd_config
_sshd_set() {
    local key="$1" value="$2"
    local sshd_config="/etc/ssh/sshd_config"
    if grep -qE "^${key} " "$sshd_config"; then
        sed -i "s/^${key} .*/${key} ${value}/" "$sshd_config"
    elif grep -qE "^#${key}" "$sshd_config"; then
        sed -i "s/^#${key}.*/${key} ${value}/" "$sshd_config"
    else
        echo "${key} ${value}" >> "$sshd_config"
    fi
}

# Запуск модуля напрямую
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    source "$(dirname "$0")/common.sh"
    check_root
    run_ssh
fi
