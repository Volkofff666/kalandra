#!/bin/bash
# Управление SSH ключами

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
[[ -z "$GREEN" ]] && source "$SCRIPT_DIR/common.sh"

run_ssh_keys() {
    check_root

    while true; do
        clear
        echo -e "${BOLD}${WHITE}╔══════════════════ SSH КЛЮЧИ ══════════════════╗${NC}"
        echo -e "${BOLD}${WHITE}║${NC}  ${CYAN}1.${NC}  Сгенерировать новый Ed25519 ключ"
        echo -e "${BOLD}${WHITE}║${NC}  ${CYAN}2.${NC}  Добавить публичный ключ вручную"
        echo -e "${BOLD}${WHITE}║${NC}  ${CYAN}3.${NC}  Показать authorized_keys"
        echo -e "${BOLD}${WHITE}║${NC}  ${GRAY}0.${NC}  Назад"
        echo -e "${BOLD}${WHITE}╚═══════════════════════════════════════════════╝${NC}"
        echo -en "  ${YELLOW}→${NC} Выбор: "
        read -r choice

        case "$choice" in
            1) _ssh_keys_generate ;;
            2) _ssh_keys_add ;;
            3) _ssh_keys_show ;;
            0) return ;;
            *) warn "Неверный выбор"; sleep 1 ;;
        esac
    done
}

_ssh_keys_generate() {
    step "Генерация Ed25519 ключа"

    local key_path="/root/.ssh/id_ed25519"
    local authorized="/root/.ssh/authorized_keys"

    mkdir -p /root/.ssh
    chmod 700 /root/.ssh

    if [[ -f "$key_path" ]]; then
        warn "Ключ ${key_path} уже существует."
        confirm "Перегенерировать (старый будет удалён)?" || { press_enter; return; }
    fi

    echo -en "  ${YELLOW}?${NC} Комментарий для ключа (Enter = root@$(hostname)): "
    read -r key_comment
    [[ -z "$key_comment" ]] && key_comment="root@$(hostname)"

    ssh-keygen -t ed25519 -C "$key_comment" -f "$key_path" -N "" &>/dev/null && \
        ok "Ключ сгенерирован: ${key_path}" || { err "Ошибка генерации ключа"; press_enter; return; }

    echo
    echo -e "${BOLD}${CYAN}══ ПУБЛИЧНЫЙ КЛЮЧ (добавь в authorized_keys своей машины) ══${NC}"
    cat "${key_path}.pub"
    echo

    echo -e "${BOLD}${CYAN}══ ИНСТРУКЦИЯ ══${NC}"
    echo -e "  ${WHITE}1. Скопируй приватный ключ на свою машину:${NC}"
    echo -e "     ${GRAY}cat ${key_path}${NC}  → скопируй всё содержимое"
    echo
    echo -e "  ${WHITE}2. Сохрани в файл на своей машине:${NC}"
    echo -e "     ${GRAY}~/.ssh/kalandra_key${NC}  (Linux/Mac)"
    echo -e "     ${GRAY}chmod 600 ~/.ssh/kalandra_key${NC}"
    echo
    echo -e "  ${WHITE}3. Добавь в ~/.ssh/config:${NC}"
    echo -e "${GRAY}     Host $(curl -s --max-time 2 https://api.ipify.org 2>/dev/null || echo 'SERVER_IP')"
    echo -e "         HostName SERVER_IP"
    echo -e "         User root"
    echo -e "         Port $(get_ssh_port)"
    echo -e "         IdentityFile ~/.ssh/kalandra_key${NC}"
    echo

    if confirm "Добавить этот публичный ключ в authorized_keys сервера?"; then
        cat "${key_path}.pub" >> "$authorized"
        chmod 600 "$authorized"
        ok "Публичный ключ добавлен в ${authorized}"
    fi

    press_enter
}

_ssh_keys_add() {
    step "Добавление публичного ключа"

    local authorized="/root/.ssh/authorized_keys"
    mkdir -p /root/.ssh
    chmod 700 /root/.ssh

    echo -e "  ${INFO}Вставь публичный ключ (ssh-ed25519 / ssh-rsa) и нажми Enter, затем Ctrl+D:${NC}"
    echo
    local pub_key
    pub_key=$(cat)

    if [[ -z "$pub_key" ]]; then
        err "Ключ не введён"
        press_enter
        return
    fi

    if ! echo "$pub_key" | grep -qE "^(ssh-ed25519|ssh-rsa|ecdsa-sha2|sk-ssh)"; then
        err "Неверный формат ключа. Ожидается ssh-ed25519, ssh-rsa и т.д."
        press_enter
        return
    fi

    echo "$pub_key" >> "$authorized"
    chmod 600 "$authorized"
    ok "Ключ добавлен в ${authorized}"

    press_enter
}

_ssh_keys_show() {
    step "Текущие authorized_keys"
    local authorized="/root/.ssh/authorized_keys"

    if [[ ! -f "$authorized" || ! -s "$authorized" ]]; then
        warn "Файл ${authorized} пуст или не существует"
    else
        echo
        nl "$authorized"
        echo
    fi

    press_enter
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    source "$(dirname "$0")/common.sh"
    check_root
    run_ssh_keys
fi
