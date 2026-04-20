#!/bin/bash
# Бенчмарк скорости

MODULE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
[[ -z "$GREEN" ]] && source "$MODULE_DIR/common.sh"

run_benchmark() {
    check_root

    step "Бенчмарк скорости"

    # Установка speedtest-cli
    if ! command -v speedtest-cli &>/dev/null && ! command -v speedtest &>/dev/null; then
        info "Устанавливаем speedtest-cli..."
        if apt-get install -y speedtest-cli &>/dev/null; then
            ok "speedtest-cli установлен"
        else
            # Пробуем через pip
            if command -v pip3 &>/dev/null; then
                pip3 install speedtest-cli &>/dev/null && ok "speedtest-cli установлен через pip3" || \
                    { err "Ошибка установки speedtest-cli"; press_enter; return; }
            else
                err "Не удалось установить speedtest-cli"
                press_enter
                return
            fi
        fi
    fi

    info "Запускаем тест скорости... (30-60 секунд)"
    echo

    local output
    if command -v speedtest-cli &>/dev/null; then
        output=$(speedtest-cli --simple 2>/dev/null)
    else
        output=$(speedtest --simple 2>/dev/null)
    fi

    if [[ -z "$output" ]]; then
        err "Тест не выполнен — нет ответа от speedtest"
        press_enter
        return
    fi

    echo -e "${BOLD}${CYAN}══ РЕЗУЛЬТАТЫ SPEEDTEST ══${NC}"
    echo "$output" | while read -r line; do
        echo -e "  $line"
    done
    echo

    # Парсим download скорость (Mbit/s)
    local down_mbps
    down_mbps=$(echo "$output" | grep -i "Download" | grep -oP '[\d.]+' | head -1)
    down_mbps="${down_mbps%.*}"  # убираем дробную часть

    if [[ -n "$down_mbps" && "$down_mbps" -gt 0 ]]; then
        step "Оценка мощности ноды"
        echo -e "  ${WHITE}Пропускная способность: ${CYAN}${down_mbps} Мбит/с${NC}"
        echo

        # Средняя нагрузка 5 Мбит/с на пользователя
        local users_avg5 users_avg2 users_avg10
        users_avg5=$(( down_mbps / 5 ))
        users_avg2=$(( down_mbps / 2 ))
        users_avg10=$(( down_mbps / 10 ))

        echo -e "  При средней нагрузке ${BOLD}2 Мбит/с${NC} на человека:  ${GREEN}~${users_avg2} пользователей${NC}"
        echo -e "  При средней нагрузке ${BOLD}5 Мбит/с${NC} на человека:  ${GREEN}~${users_avg5} пользователей${NC}"
        echo -e "  При средней нагрузке ${BOLD}10 Мбит/с${NC} на человека: ${GREEN}~${users_avg10} пользователей${NC}"
        echo

        if (( down_mbps >= 1000 )); then
            ok "Отличная нода — 1 Гбит/с и выше"
        elif (( down_mbps >= 500 )); then
            ok "Хорошая нода — 500+ Мбит/с"
        elif (( down_mbps >= 100 )); then
            info "Нормальная нода — 100+ Мбит/с"
        else
            warn "Слабый канал — менее 100 Мбит/с"
        fi
    fi

    press_enter
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    source "$(dirname "$0")/common.sh"
    check_root
    run_benchmark
fi
