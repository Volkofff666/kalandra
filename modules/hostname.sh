#!/bin/bash
# Смена hostname

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
[[ -z "$GREEN" ]] && source "$SCRIPT_DIR/common.sh"

run_hostname() {
    check_root

    step "Смена hostname"

    local current_hostname
    current_hostname=$(hostname)
    info "Текущий hostname: ${CYAN}${current_hostname}${NC}"

    # Проверка на дефолтные VPS имена
    if echo "$current_hostname" | grep -qiE "^(ubuntu|debian|localhost|vps|server|host)[0-9]*$"; then
        warn "Дефолтное имя хоста (${current_hostname}) выдаёт VPS-сервер!"
        warn "Рекомендуется сменить на нейтральное имя: router, edge, proxy, gateway..."
    fi

    echo
    echo -en "  ${YELLOW}?${NC} Новый hostname (только буквы/цифры/дефис, без пробелов): "
    read -r new_hostname

    if [[ -z "$new_hostname" ]]; then
        info "Отменено."
        press_enter
        return
    fi

    if ! [[ "$new_hostname" =~ ^[a-zA-Z0-9]([a-zA-Z0-9-]*[a-zA-Z0-9])?$ ]]; then
        err "Некорректный hostname. Используй только буквы, цифры и дефис."
        err "Дефис не может быть первым или последним символом."
        press_enter
        return
    fi

    if [[ ${#new_hostname} -gt 63 ]]; then
        err "Hostname слишком длинный (максимум 63 символа)"
        press_enter
        return
    fi

    step "Применяем новый hostname: ${new_hostname}"

    # hostnamectl
    hostnamectl set-hostname "$new_hostname" && ok "hostnamectl: hostname установлен" || \
        err "Ошибка hostnamectl"

    # Обновляем /etc/hosts
    if grep -q "$current_hostname" /etc/hosts; then
        sed -i "s/$current_hostname/$new_hostname/g" /etc/hosts
        ok "/etc/hosts обновлён"
    else
        echo "127.0.1.1 ${new_hostname}" >> /etc/hosts
        ok "Добавлено в /etc/hosts: 127.0.1.1 ${new_hostname}"
    fi

    info "Новый hostname: ${CYAN}${new_hostname}${NC}"
    info "Вступит в силу полностью после перезапуска сессии."

    press_enter
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    source "$(dirname "$0")/common.sh"
    check_root
    run_hostname
fi
