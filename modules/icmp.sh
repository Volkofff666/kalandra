#!/bin/bash
# Блокировка ICMP ping через UFW

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
[[ -z "$GREEN" ]] && source "$SCRIPT_DIR/common.sh"

run_icmp() {
    check_root

    local rules_file="/etc/ufw/before.rules"

    step "Блокировка ICMP ping"

    if [[ ! -f "$rules_file" ]]; then
        err "Файл ${rules_file} не найден. Установи UFW."
        press_enter
        return
    fi

    # Проверить текущий статус
    if grep -q "echo-request -j DROP" "$rules_file"; then
        ok "ICMP ping уже заблокирован"
        press_enter
        return
    fi

    info "Текущий статус: ICMP ping ${RED}включён${NC}"
    info "Будем блокировать только echo-request (ping)."
    info "Оставляем destination-unreachable, time-exceeded, parameter-problem — они нужны для MTU и traceroute."
    echo

    if ! confirm "Заблокировать ICMP ping?"; then
        info "Отменено."
        press_enter
        return
    fi

    # Блокируем echo-request для INPUT и FORWARD
    step "Редактируем ${rules_file}"

    # INPUT chain
    sed -i 's/-A ufw-before-input -p icmp --icmp-type echo-request -j ACCEPT/-A ufw-before-input -p icmp --icmp-type echo-request -j DROP/' "$rules_file"

    # FORWARD chain
    sed -i 's/-A ufw-before-forward -p icmp --icmp-type echo-request -j ACCEPT/-A ufw-before-forward -p icmp --icmp-type echo-request -j DROP/' "$rules_file"

    # Проверка что замена прошла
    if grep -q "echo-request -j DROP" "$rules_file"; then
        ok "Правила DROP для echo-request записаны"
    else
        err "Не удалось найти строки для замены в ${rules_file}"
        warn "Возможно, файл уже изменён вручную или имеет нестандартный формат."
        info "Добавляем правила вручную в начало INPUT chain..."
        _icmp_add_manual "$rules_file"
    fi

    # Перезагрузка UFW
    step "Перезагружаем UFW"
    ufw reload &>/dev/null && ok "UFW перезагружен" || err "Ошибка перезагрузки UFW"

    # Проверка
    step "Проверка"
    if grep -q "echo-request -j DROP" "$rules_file"; then
        ok "ICMP ping заблокирован успешно"
    else
        err "Проверка не прошла — правило не найдено в ${rules_file}"
    fi

    press_enter
}

_icmp_add_manual() {
    local rules_file="$1"
    local insert_after="-A ufw-before-input -p icmp --icmp-type echo-request"
    # Если строки ACCEPT нет совсем — добавляем DROP напрямую
    if ! grep -q "icmp.*echo-request" "$rules_file"; then
        sed -i '/^# ok icmp codes for INPUT/a -A ufw-before-input -p icmp --icmp-type echo-request -j DROP\n-A ufw-before-forward -p icmp --icmp-type echo-request -j DROP' "$rules_file"
    fi
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    source "$(dirname "$0")/common.sh"
    check_root
    run_icmp
fi
