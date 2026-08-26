#!/bin/bash
# ============================================================
# entrypoint.sh
# Скрипт точки входа для Docker-контейнера проекта
# Air-Ground Security System — MVP
# ============================================================
#
# Что делает:
#   1. Подгружает окружение ROS и рабочего пространства
#   2. Генерирует хост-ключи SSH (если отсутствуют)
#   3. Запускает SSH-сервер
#   4. Выполняет переданную команду или держит контейнер живым
#
# Использование в Docker:
#   ENTRYPOINT ["/entrypoint.sh"]
#   CMD ["bash"]
#
# Запуск контейнера с системой:
#   docker run -it --rm air-ground-mvp \
#     roslaunch air_ground_bringup system.launch rviz:=true
# ============================================================

set -e

# Цвета для логирования
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

log_info() { echo -e "${GREEN}[ENTRYPOINT]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[ENTRYPOINT WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ENTRYPOINT ERROR]${NC} $1"; }

# ============================================================
# 1. Подгрузка окружения ROS
# ============================================================
log_info "Подгрузка окружения ROS..."

if [ -f /opt/ros/noetic/setup.bash ]; then
    source /opt/ros/noetic/setup.bash
    log_info "ROS Noetic окружение подгружено"
else
    log_warn "ROS Noetic не найден в /opt/ros/noetic/"
fi

# Подгрузка рабочего пространства
CATKIN_WS="/root/catkin_ws"
if [ -f "${CATKIN_WS}/devel/setup.bash" ]; then
    source "${CATKIN_WS}/devel/setup.bash"
    log_info "Рабочее пространство подгружено: ${CATKIN_WS}"
else
    log_warn "Рабочее пространство не найдено: ${CATKIN_WS}/devel/setup.bash"
fi

# ============================================================
# 2. Подготовка директории для SSH
# ============================================================
log_info "Подготовка SSH..."

# Создание директории для PID-файла и сокетов
mkdir -p /var/run/sshd

# Генерация хост-ключей, если их нет
if [ ! -f /etc/ssh/ssh_host_rsa_key ]; then
    log_info "Генерация хост-ключей SSH..."
    ssh-keygen -A
    log_info "Хост-ключи сгенерированы"
fi

# ============================================================
# 3. Запуск SSH-сервера
# ============================================================
log_info "Запуск SSH-сервера на порту 22..."

# Проверка конфигурации перед запуском
if ! /usr/sbin/sshd -t; then
    log_warn "Обнаружены проблемы с конфигурацией, исправляем..."
    # Исправление типичных проблем с правами
    mkdir -p /root/.ssh
    chmod 700 /root/.ssh
    touch /root/.ssh/authorized_keys
    chmod 600 /root/.ssh/authorized_keys
    
    # Повторная проверка
    /usr/sbin/sshd -t || log_error "SSH-конфигурация невалидна"
fi

# Запуск демона
/usr/sbin/sshd

if [ $? -eq 0 ]; then
    log_info "SSH-сервер запущен успешно"
else
    log_error "Не удалось запустить SSH-сервер"
    exit 1
fi

# ============================================================
# 4. Вывод информации для подключения
# ============================================================
CONTAINER_IP=$(hostname -I | awk '{print $1}')

echo ""
echo -e "${GREEN}╔════════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║   КОНТЕЙНЕР ЗАПУЩЕН — Air-Ground Security MVP               ║${NC}"
echo -e "${GREEN}╚════════════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "${GREEN}SSH-доступ:${NC}"
echo "  ssh robot@localhost -p <порт>"
echo "  Пароль: robot"
echo ""
echo -e "${GREEN}IP контейнера:${NC} ${CONTAINER_IP:-<не определён>}"
echo ""
echo -e "${GREEN}ROS Master:${NC} http://localhost:11311"
echo ""
echo -e "${GREEN}Запуск системы:${NC}"
echo "  roslaunch air_ground_bringup system.launch rviz:=true"
echo ""

# ============================================================
# 5. Выполнение команды или интерактивный режим
# ============================================================
if [ $# -gt 0 ]; then
    log_info "Выполнение команды: $*"
    exec "$@"
else
    log_info "Команда не передана, контейнер работает в фоновом режиме"
    log_info "Подключитесь через SSH или передайте команду"
    
    # Держим контейнер живым
    exec tail -f /dev/null
fi
