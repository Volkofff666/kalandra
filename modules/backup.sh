#!/bin/bash
# Бэкап конфигов

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
[[ -z "$GREEN" ]] && source "$SCRIPT_DIR/common.sh"

BACKUP_FILES=(
    /etc/ssh/sshd_config
    /etc/ufw/before.rules
    /etc/default/ufw
    /etc/sysctl.d/99-kalandra.conf
    /etc/fail2ban/jail.local
    /etc/knockd.conf
    /etc/kalandra/telegram.conf
    /etc/hosts
)

run_backup() {
    check_root

    step "Бэкап конфигов"

    local backup_dir="/root/kalandra-backup-$(date '+%Y%m%d-%H%M%S')"
    mkdir -p "$backup_dir"
    ok "Директория: ${backup_dir}"

    local saved=0 skipped=0

    for f in "${BACKUP_FILES[@]}"; do
        if [[ -f "$f" ]]; then
            cp "$f" "${backup_dir}/$(basename "$f")" && \
                ok "Сохранён: $f" && (( saved++ )) || \
                err "Ошибка копирования: $f"
        else
            info "Пропущен (не существует): $f"
            (( skipped++ ))
        fi
    done

    echo
    info "Сохранено: ${saved} файлов, пропущено: ${skipped}"
    ok "Бэкап: ${backup_dir}"

    step "Команды восстановления"
    echo
    for f in "${BACKUP_FILES[@]}"; do
        local fname
        fname="$(basename "$f")"
        local dest_dir
        dest_dir="$(dirname "$f")"
        if [[ -f "${backup_dir}/${fname}" ]]; then
            echo -e "  ${GRAY}cp ${backup_dir}/${fname} ${f}${NC}"
        fi
    done
    echo
    echo -e "  ${CYAN}После восстановления sshd_config:${NC}  ${GRAY}systemctl restart ssh${NC}"
    echo -e "  ${CYAN}После восстановления ufw/before.rules:${NC}  ${GRAY}ufw reload${NC}"
    echo -e "  ${CYAN}После восстановления sysctl:${NC}  ${GRAY}sysctl -p /etc/sysctl.d/99-kalandra.conf${NC}"
    echo

    press_enter
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    source "$(dirname "$0")/common.sh"
    check_root
    run_backup
fi
