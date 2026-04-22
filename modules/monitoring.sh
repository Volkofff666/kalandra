#!/bin/bash
# monitoring.sh — Grafana + Prometheus + Node Exporter стек

MONITORING_DIR="/opt/kalandra/monitoring"
COMPOSE_FILE="${MONITORING_DIR}/docker-compose.yml"

# ─── Вспомогательные ─────────────────────────────────────────────────────────

_docker_ok() {
    command -v docker &>/dev/null && systemctl is-active --quiet docker 2>/dev/null
}

_compose_cmd() {
    if docker compose version &>/dev/null 2>&1; then
        echo "docker compose"
    elif command -v docker-compose &>/dev/null; then
        echo "docker-compose"
    else
        echo ""
    fi
}

_get_ext_ip() {
    curl -s --max-time 5 https://api.ipify.org 2>/dev/null || hostname -I | awk '{print $1}'
}

# ─── Запись конфигов ─────────────────────────────────────────────────────────

_write_configs() {
    step "Создание конфигурационных файлов"

    mkdir -p "${MONITORING_DIR}/grafana/datasources" \
             "${MONITORING_DIR}/grafana/dashboards"

    cat > "${COMPOSE_FILE}" << 'EOF'
version: '3.8'

services:
  prometheus:
    image: prom/prometheus:latest
    container_name: kalandra-prometheus
    restart: unless-stopped
    ports:
      - "127.0.0.1:9090:9090"
    volumes:
      - /opt/kalandra/monitoring/prometheus.yml:/etc/prometheus/prometheus.yml:ro
      - prometheus_data:/prometheus
    command:
      - '--config.file=/etc/prometheus/prometheus.yml'
      - '--storage.tsdb.retention.time=30d'
      - '--web.enable-lifecycle'

  grafana:
    image: grafana/grafana:latest
    container_name: kalandra-grafana
    restart: unless-stopped
    ports:
      - "3000:3000"
    environment:
      - GF_SECURITY_ADMIN_PASSWORD=kalandra
      - GF_USERS_ALLOW_SIGN_UP=false
    volumes:
      - /opt/kalandra/monitoring/grafana:/etc/grafana/provisioning
      - grafana_data:/var/lib/grafana
    depends_on:
      - prometheus

  node-exporter:
    image: prom/node-exporter:latest
    container_name: kalandra-node-exporter
    restart: unless-stopped
    ports:
      - "127.0.0.1:9100:9100"
    volumes:
      - /proc:/host/proc:ro
      - /sys:/host/sys:ro
      - /:/rootfs:ro
    command:
      - '--path.procfs=/host/proc'
      - '--path.sysfs=/host/sys'
      - '--collector.filesystem.mount-points-exclude=^/(sys|proc|dev|host|etc)($$|/)'

volumes:
  prometheus_data:
  grafana_data:
EOF
    ok "docker-compose.yml"

    cat > "${MONITORING_DIR}/prometheus.yml" << 'EOF'
global:
  scrape_interval: 15s
  evaluation_interval: 15s

scrape_configs:
  - job_name: 'node'
    static_configs:
      - targets: ['node-exporter:9100']

  - job_name: 'prometheus'
    static_configs:
      - targets: ['localhost:9090']
EOF
    ok "prometheus.yml"

    cat > "${MONITORING_DIR}/grafana/datasources/prometheus.yml" << 'EOF'
apiVersion: 1

datasources:
  - name: Prometheus
    type: prometheus
    access: proxy
    url: http://prometheus:9090
    isDefault: true
    editable: false
EOF
    ok "grafana/datasources/prometheus.yml"

    cat > "${MONITORING_DIR}/grafana/dashboards/kalandra.yml" << 'EOF'
apiVersion: 1

providers:
  - name: kalandra
    orgId: 1
    type: file
    disableDeletion: false
    updateIntervalSeconds: 30
    allowUiUpdates: true
    options:
      path: /etc/grafana/provisioning/dashboards
EOF
    ok "grafana/dashboards/kalandra.yml"

    _write_dashboard
    ok "grafana/dashboards/kalandra.json"
}

_write_dashboard() {
    cat > "${MONITORING_DIR}/grafana/dashboards/kalandra.json" << 'DASHBOARD'
{
  "title": "Kalandra Node",
  "uid": "kalandra-node-v1",
  "schemaVersion": 38,
  "version": 1,
  "refresh": "30s",
  "time": { "from": "now-1h", "to": "now" },
  "timezone": "browser",
  "tags": ["kalandra", "node"],
  "panels": [
    {
      "id": 1, "type": "gauge", "title": "CPU",
      "gridPos": { "x": 0, "y": 0, "w": 4, "h": 4 },
      "datasource": { "type": "prometheus", "uid": "PBFA97CFB590B2093" },
      "fieldConfig": {
        "defaults": {
          "unit": "percent", "min": 0, "max": 100,
          "thresholds": { "mode": "absolute", "steps": [
            { "color": "green", "value": null },
            { "color": "yellow", "value": 70 },
            { "color": "red", "value": 90 }
          ]}
        }
      },
      "options": { "reduceOptions": { "calcs": ["lastNotNull"] }, "orientation": "auto", "showThresholdLabels": false, "showThresholdMarkers": true },
      "targets": [{ "datasource": { "type": "prometheus" }, "expr": "100 - (avg by (instance) (irate(node_cpu_seconds_total{mode=\"idle\"}[5m])) * 100)", "legendFormat": "CPU %" }]
    },
    {
      "id": 2, "type": "gauge", "title": "RAM",
      "gridPos": { "x": 4, "y": 0, "w": 4, "h": 4 },
      "datasource": { "type": "prometheus", "uid": "PBFA97CFB590B2093" },
      "fieldConfig": {
        "defaults": {
          "unit": "percent", "min": 0, "max": 100,
          "thresholds": { "mode": "absolute", "steps": [
            { "color": "green", "value": null },
            { "color": "yellow", "value": 70 },
            { "color": "red", "value": 90 }
          ]}
        }
      },
      "options": { "reduceOptions": { "calcs": ["lastNotNull"] }, "orientation": "auto", "showThresholdLabels": false, "showThresholdMarkers": true },
      "targets": [{ "datasource": { "type": "prometheus" }, "expr": "(1 - (node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes)) * 100", "legendFormat": "RAM %" }]
    },
    {
      "id": 3, "type": "gauge", "title": "Disk /",
      "gridPos": { "x": 8, "y": 0, "w": 4, "h": 4 },
      "datasource": { "type": "prometheus", "uid": "PBFA97CFB590B2093" },
      "fieldConfig": {
        "defaults": {
          "unit": "percent", "min": 0, "max": 100,
          "thresholds": { "mode": "absolute", "steps": [
            { "color": "green", "value": null },
            { "color": "yellow", "value": 70 },
            { "color": "red", "value": 90 }
          ]}
        }
      },
      "options": { "reduceOptions": { "calcs": ["lastNotNull"] }, "orientation": "auto", "showThresholdLabels": false, "showThresholdMarkers": true },
      "targets": [{ "datasource": { "type": "prometheus" }, "expr": "100 - ((node_filesystem_avail_bytes{mountpoint=\"/\",fstype!=\"tmpfs\"} / node_filesystem_size_bytes{mountpoint=\"/\",fstype!=\"tmpfs\"}) * 100)", "legendFormat": "Disk %" }]
    },
    {
      "id": 4, "type": "stat", "title": "Uptime",
      "gridPos": { "x": 12, "y": 0, "w": 4, "h": 4 },
      "datasource": { "type": "prometheus", "uid": "PBFA97CFB590B2093" },
      "fieldConfig": {
        "defaults": {
          "unit": "dtdurations",
          "thresholds": { "mode": "absolute", "steps": [{ "color": "green", "value": null }] }
        }
      },
      "options": { "reduceOptions": { "calcs": ["lastNotNull"] }, "orientation": "auto", "colorMode": "value", "graphMode": "none", "justifyMode": "auto", "textMode": "auto" },
      "targets": [{ "datasource": { "type": "prometheus" }, "expr": "time() - node_boot_time_seconds", "legendFormat": "Uptime" }]
    },
    {
      "id": 5, "type": "stat", "title": "Load Average (1m)",
      "gridPos": { "x": 16, "y": 0, "w": 4, "h": 4 },
      "datasource": { "type": "prometheus", "uid": "PBFA97CFB590B2093" },
      "fieldConfig": {
        "defaults": {
          "unit": "short",
          "thresholds": { "mode": "absolute", "steps": [
            { "color": "green", "value": null },
            { "color": "yellow", "value": 2 },
            { "color": "red", "value": 5 }
          ]}
        }
      },
      "options": { "reduceOptions": { "calcs": ["lastNotNull"] }, "colorMode": "background", "graphMode": "area", "justifyMode": "auto", "orientation": "auto", "textMode": "auto" },
      "targets": [{ "datasource": { "type": "prometheus" }, "expr": "node_load1", "legendFormat": "Load 1m" }]
    },
    {
      "id": 6, "type": "stat", "title": "TCP Connections",
      "gridPos": { "x": 20, "y": 0, "w": 4, "h": 4 },
      "datasource": { "type": "prometheus", "uid": "PBFA97CFB590B2093" },
      "fieldConfig": {
        "defaults": {
          "unit": "short",
          "thresholds": { "mode": "absolute", "steps": [
            { "color": "green", "value": null },
            { "color": "yellow", "value": 1000 },
            { "color": "red", "value": 5000 }
          ]}
        }
      },
      "options": { "reduceOptions": { "calcs": ["lastNotNull"] }, "colorMode": "value", "graphMode": "area", "justifyMode": "auto", "orientation": "auto", "textMode": "auto" },
      "targets": [{ "datasource": { "type": "prometheus" }, "expr": "node_netstat_Tcp_CurrEstab", "legendFormat": "Established" }]
    },
    {
      "id": 7, "type": "timeseries", "title": "CPU Usage %",
      "gridPos": { "x": 0, "y": 4, "w": 12, "h": 7 },
      "datasource": { "type": "prometheus", "uid": "PBFA97CFB590B2093" },
      "fieldConfig": { "defaults": { "unit": "percent", "min": 0, "max": 100, "color": { "mode": "palette-classic" } } },
      "options": { "tooltip": { "mode": "multi" }, "legend": { "displayMode": "list", "placement": "bottom" } },
      "targets": [{ "datasource": { "type": "prometheus" }, "expr": "100 - (avg by (instance) (irate(node_cpu_seconds_total{mode=\"idle\"}[5m])) * 100)", "legendFormat": "CPU %" }]
    },
    {
      "id": 8, "type": "timeseries", "title": "Load Average",
      "gridPos": { "x": 12, "y": 4, "w": 12, "h": 7 },
      "datasource": { "type": "prometheus", "uid": "PBFA97CFB590B2093" },
      "fieldConfig": { "defaults": { "unit": "short", "color": { "mode": "palette-classic" } } },
      "options": { "tooltip": { "mode": "multi" }, "legend": { "displayMode": "list", "placement": "bottom" } },
      "targets": [
        { "datasource": { "type": "prometheus" }, "expr": "node_load1",  "legendFormat": "1m" },
        { "datasource": { "type": "prometheus" }, "expr": "node_load5",  "legendFormat": "5m" },
        { "datasource": { "type": "prometheus" }, "expr": "node_load15", "legendFormat": "15m" }
      ]
    },
    {
      "id": 9, "type": "timeseries", "title": "Network Traffic",
      "gridPos": { "x": 0, "y": 11, "w": 12, "h": 7 },
      "datasource": { "type": "prometheus", "uid": "PBFA97CFB590B2093" },
      "fieldConfig": { "defaults": { "unit": "Bps", "color": { "mode": "palette-classic" } } },
      "options": { "tooltip": { "mode": "multi" }, "legend": { "displayMode": "list", "placement": "bottom" } },
      "targets": [
        { "datasource": { "type": "prometheus" }, "expr": "irate(node_network_receive_bytes_total{device!=\"lo\"}[5m])",  "legendFormat": "In  {{device}}" },
        { "datasource": { "type": "prometheus" }, "expr": "irate(node_network_transmit_bytes_total{device!=\"lo\"}[5m])", "legendFormat": "Out {{device}}" }
      ]
    },
    {
      "id": 10, "type": "timeseries", "title": "RAM Usage",
      "gridPos": { "x": 12, "y": 11, "w": 12, "h": 7 },
      "datasource": { "type": "prometheus", "uid": "PBFA97CFB590B2093" },
      "fieldConfig": { "defaults": { "unit": "decmbytes", "color": { "mode": "palette-classic" } } },
      "options": { "tooltip": { "mode": "multi" }, "legend": { "displayMode": "list", "placement": "bottom" } },
      "targets": [
        { "datasource": { "type": "prometheus" }, "expr": "(node_memory_MemTotal_bytes - node_memory_MemAvailable_bytes) / 1024 / 1024", "legendFormat": "Used MB" },
        { "datasource": { "type": "prometheus" }, "expr": "node_memory_MemTotal_bytes / 1024 / 1024", "legendFormat": "Total MB" }
      ]
    },
    {
      "id": 11, "type": "timeseries", "title": "Active TCP Connections",
      "gridPos": { "x": 0, "y": 18, "w": 12, "h": 7 },
      "datasource": { "type": "prometheus", "uid": "PBFA97CFB590B2093" },
      "fieldConfig": { "defaults": { "unit": "short", "color": { "mode": "palette-classic" } } },
      "options": { "tooltip": { "mode": "multi" }, "legend": { "displayMode": "list", "placement": "bottom" } },
      "targets": [{ "datasource": { "type": "prometheus" }, "expr": "node_netstat_Tcp_CurrEstab", "legendFormat": "Established" }]
    },
    {
      "id": 12, "type": "timeseries", "title": "Disk I/O",
      "gridPos": { "x": 12, "y": 18, "w": 12, "h": 7 },
      "datasource": { "type": "prometheus", "uid": "PBFA97CFB590B2093" },
      "fieldConfig": { "defaults": { "unit": "Bps", "color": { "mode": "palette-classic" } } },
      "options": { "tooltip": { "mode": "multi" }, "legend": { "displayMode": "list", "placement": "bottom" } },
      "targets": [
        { "datasource": { "type": "prometheus" }, "expr": "irate(node_disk_read_bytes_total[5m])",    "legendFormat": "Read  {{device}}" },
        { "datasource": { "type": "prometheus" }, "expr": "irate(node_disk_written_bytes_total[5m])", "legendFormat": "Write {{device}}" }
      ]
    }
  ]
}
DASHBOARD
}

# ─── Функции подменю ─────────────────────────────────────────────────────────

monitoring_install() {
    step "Установка стека мониторинга"

    if ! _docker_ok; then
        err "Docker не установлен или не запущен."
        info "Установи Docker сначала через пункт 14 главного меню."
        press_enter
        return 1
    fi

    local compose_cmd
    compose_cmd=$(_compose_cmd)
    if [[ -z "$compose_cmd" ]]; then
        err "docker-compose не найден."
        info "Установи: apt-get install -y docker-compose-plugin"
        press_enter
        return 1
    fi

    if docker ps 2>/dev/null | grep -q "kalandra-grafana"; then
        warn "Grafana уже запущена."
        info "Используй пункт 2 для просмотра статуса."
        press_enter
        return
    fi

    warn "Будет установлено:"
    info "  • Prometheus    — порт 9090 (только localhost)"
    info "  • Grafana       — порт 3000 (публичный)"
    info "  • Node Exporter — порт 9100 (только localhost)"
    echo
    confirm "Продолжить?" || { info "Отменено."; return; }

    _write_configs

    step "Запуск стека"
    cd "${MONITORING_DIR}" || { err "Директория ${MONITORING_DIR} недоступна"; return 1; }

    if $compose_cmd up -d 2>/tmp/kalandra-compose.log; then
        ok "Стек запущен"
    else
        err "Ошибка запуска:"
        cat /tmp/kalandra-compose.log
        press_enter
        return 1
    fi

    step "Открытие порта Grafana"
    if command -v ufw &>/dev/null && ufw status 2>/dev/null | grep -q "Status: active"; then
        ufw allow 3000/tcp &>/dev/null && ok "UFW: порт 3000 открыт"
    else
        info "UFW не активен — порт уже доступен"
    fi

    local ext_ip
    ext_ip=$(_get_ext_ip)

    echo
    echo -e "${BOLD}${GREEN}╔══════════════════════════════════════════╗${NC}"
    echo -e "${BOLD}${GREEN}║  ✅ Grafana установлена!${NC}"
    echo -e "${BOLD}${GREEN}║${NC}"
    echo -e "${BOLD}${GREEN}║${NC}  URL    : ${CYAN}http://${ext_ip}:3000${NC}"
    echo -e "${BOLD}${GREEN}║${NC}  Логин  : ${WHITE}admin${NC}"
    echo -e "${BOLD}${GREEN}║${NC}  Пароль : ${WHITE}kalandra${NC}"
    echo -e "${BOLD}${GREEN}║${NC}"
    echo -e "${BOLD}${GREEN}║${NC}  ${YELLOW}⚠  Смени пароль после первого входа!${NC}"
    echo -e "${BOLD}${GREEN}╚══════════════════════════════════════════╝${NC}"
    press_enter
}

monitoring_status() {
    step "Статус стека мониторинга"

    local -a services=("kalandra-grafana" "kalandra-prometheus" "kalandra-node-exporter")
    local -a labels=("Grafana       " "Prometheus    " "Node Exporter ")

    for i in "${!services[@]}"; do
        local svc="${services[$i]}" label="${labels[$i]}"
        if docker ps 2>/dev/null | grep -q "$svc"; then
            local uptime
            uptime=$(docker ps --format "{{.Status}}" --filter "name=${svc}" 2>/dev/null | head -1)
            ok "${label}: ${uptime}"
        elif docker ps -a 2>/dev/null | grep -q "$svc"; then
            err "${label}: остановлен"
        else
            warn "${label}: не установлен"
        fi
    done

    if docker ps 2>/dev/null | grep -q "kalandra-grafana"; then
        local ext_ip
        ext_ip=$(_get_ext_ip)
        echo
        info "Grafana: ${CYAN}http://${ext_ip}:3000${NC}"
    fi
    press_enter
}

monitoring_restart() {
    step "Перезапуск стека"

    if [[ ! -f "${COMPOSE_FILE}" ]]; then
        err "Стек не установлен. Сначала пункт 1."
        press_enter
        return 1
    fi

    local compose_cmd
    compose_cmd=$(_compose_cmd)
    cd "${MONITORING_DIR}" || return 1

    $compose_cmd restart 2>/dev/null && ok "Стек перезапущен" || err "Ошибка перезапуска"
    press_enter
}

monitoring_url() {
    echo
    if docker ps 2>/dev/null | grep -q "kalandra-grafana"; then
        local ext_ip
        ext_ip=$(_get_ext_ip)
        echo -e "  ${BOLD}${MAGENTA}[ 📊 GRAFANA ]${NC}"
        echo
        info "URL    : ${CYAN}http://${ext_ip}:3000${NC}"
        info "Логин  : admin"
        info "Пароль : kalandra (если не менял)"
    else
        err "Grafana не запущена. Установи через пункт 1."
    fi
    press_enter
}

monitoring_update() {
    step "Обновление стека мониторинга"

    if [[ ! -f "${COMPOSE_FILE}" ]]; then
        err "Стек не установлен."
        press_enter
        return 1
    fi

    local compose_cmd
    compose_cmd=$(_compose_cmd)
    cd "${MONITORING_DIR}" || return 1

    info "Получаем последние образы..."
    $compose_cmd pull 2>/dev/null && ok "Образы обновлены" || err "Ошибка загрузки образов"

    info "Перезапускаем контейнеры..."
    $compose_cmd up -d 2>/dev/null && ok "Стек обновлён и запущен" || err "Ошибка запуска"
    press_enter
}

monitoring_remove() {
    step "Удаление стека мониторинга"

    warn "Будут удалены контейнеры и тома (данные Grafana)."
    echo
    confirm "Уверен что хочешь удалить?" || { info "Отменено."; return; }

    local compose_cmd
    compose_cmd=$(_compose_cmd)

    if [[ -f "${COMPOSE_FILE}" ]]; then
        cd "${MONITORING_DIR}" || return 1
        $compose_cmd down -v 2>/dev/null && ok "Стек удалён" || err "Ошибка удаления"
    else
        for c in kalandra-grafana kalandra-prometheus kalandra-node-exporter; do
            docker stop "$c" 2>/dev/null
            docker rm "$c" 2>/dev/null
            ok "Контейнер ${c} удалён"
        done
    fi

    if command -v ufw &>/dev/null && ufw status 2>/dev/null | grep -q "Status: active"; then
        ufw delete allow 3000/tcp &>/dev/null && ok "UFW: порт 3000 закрыт"
    fi
    press_enter
}

# ─── Точка входа ─────────────────────────────────────────────────────────────

run_monitoring() {
    while true; do
        clear
        show_banner
        echo -e "  ${BOLD}${MAGENTA}[ 📊 МОНИТОРИНГ — Grafana + Prometheus ]${NC}\n"

        echo -e "${BOLD}${WHITE}╔══════════════════════════════════════════╗${NC}"
        echo -e "${BOLD}${WHITE}║${NC}  ${CYAN}1.${NC}  🚀 Установить стек"
        echo -e "${BOLD}${WHITE}║${NC}  ${CYAN}2.${NC}  📊 Статус стека"
        echo -e "${BOLD}${WHITE}║${NC}  ${CYAN}3.${NC}  🔄 Перезапустить стек"
        echo -e "${BOLD}${WHITE}║${NC}  ${CYAN}4.${NC}  🌐 Открыть Grafana (URL)"
        echo -e "${BOLD}${WHITE}║${NC}  ${CYAN}5.${NC}  ⬆️  Обновить стек"
        echo -e "${BOLD}${WHITE}║${NC}  ${CYAN}6.${NC}  ❌ Удалить стек"
        echo -e "${BOLD}${WHITE}║${NC}   ${GRAY}0.${NC}  ← Назад"
        echo -e "${BOLD}${WHITE}╚══════════════════════════════════════════╝${NC}"
        echo -en "  ${YELLOW}→${NC} Выбор: "
        read_tty choice
        choice="${choice//[[:space:]]/}"
        echo

        case "$choice" in
            1) monitoring_install ;;
            2) monitoring_status ;;
            3) monitoring_restart ;;
            4) monitoring_url ;;
            5) monitoring_update ;;
            6) monitoring_remove ;;
            0) return ;;
            *) warn "Введи число от 0 до 6."; sleep 1 ;;
        esac
    done
}
