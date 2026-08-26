#!/bin/bash
#
# 03_setup_devices.sh
# Настройка устройств (датчиков и исполнительных механизмов)
# для проекта Air-Ground Security MVP
#
# Использование:
#   chmod +x scripts/03_setup_devices.sh
#   ./scripts/03_setup_devices.sh
#
# Что делает:
#   1. Добавляет пользователя в необходимые группы
#   2. Устанавливает udev-правила из udev/99-robot.rules
#   3. Перезагружает udev
#   4. Проверяет доступные устройства (камера, джойстик, батарея)
#   5. Настраивает сеть для Ethernet (опционально)
#
# Требования:
#   - Ubuntu 20.04 LTS
#   - Права sudo
#

set -o pipefail

# Цвета для логирования
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }
log_step() { echo -e "${CYAN}[STEP]${NC} $1"; }

# Определение пути к репозиторию
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(dirname "$SCRIPT_DIR")"

# Проверка ОС
if ! grep -q "Ubuntu" /etc/os-release; then
    log_error "Этот скрипт предназначен только для Ubuntu"
    exit 1
fi

# Проверка прав sudo
if ! sudo -v; then
    log_error "Не удалось получить права sudo"
    exit 1
fi

CURRENT_USER=$(whoami)
UDEV_RULES_SRC="$REPO_ROOT/udev/99-robot.rules"
UDEV_RULES_DST="/etc/udev/rules.d/99-robot.rules"

log_info "=== Настройка устройств для робота ==="
log_info "Пользователь: $CURRENT_USER"
log_info "Корень репозитория: $REPO_ROOT"

# ------------------------------------------------------------
# ШАГ 1: Добавление пользователя в необходимые группы
# ------------------------------------------------------------
log_step "1/5: Добавление пользователя в группы..."

GROUPS_TO_ADD=(
    "dialout"    # Последовательные порты (дрон, лидар, контроллеры)
    "video"      # Камеры
    "plugdev"    # USB-устройства, CAN
    "input"      # Джойстики, геймпады
    "netdev"     # Сетевые устройства
    "audio"      # Аудио (опционально, для динамиков)
    "gpio"       # GPIO (если есть)
    "i2c"        # I2C устройства (если есть)
    "spi"        # SPI устройства (если есть)
)

for group in "${GROUPS_TO_ADD[@]}"; do
    # Проверяем, существует ли группа
    if ! getent group "$group" > /dev/null 2>&1; then
        log_warn "Группа '$group' не существует, создаём..."
        sudo groupadd "$group" 2>/dev/null || true
    fi
    
    # Проверяем, входит ли пользователь в группу
    if ! groups "$CURRENT_USER" | grep -q "\b$group\b"; then
        log_info "Добавляем $CURRENT_USER в группу $group"
        sudo usermod -aG "$group" "$CURRENT_USER"
    else
        log_info "Пользователь уже в группе $group"
    fi
done

log_info "Текущие группы пользователя:"
groups "$CURRENT_USER" | tr ' ' '\n' | grep -v "^$" | awk '{print "  - " $1}'

# ------------------------------------------------------------
# ШАГ 2: Установка udev-правил
# ------------------------------------------------------------
log_step "2/5: Установка udev-правил..."

if [ -f "$UDEV_RULES_SRC" ]; then
    log_info "Копирование $UDEV_RULES_SRC -> $UDEV_RULES_DST"
    sudo cp "$UDEV_RULES_SRC" "$UDEV_RULES_DST"
    sudo chmod 644 "$UDEV_RULES_DST"
    sudo chown root:root "$UDEV_RULES_DST"
    log_info "Udev-правила установлены"
else
    log_warn "Файл $UDEV_RULES_SRC не найден, пропускаем установку правил"
    log_warn "Создайте файл вручную или запустите скрипт из корня репозитория"
fi

# ------------------------------------------------------------
# ШАГ 3: Перезагрузка udev
# ------------------------------------------------------------
log_step "3/5: Перезагрузка udev..."

set +e
sudo udevadm control --reload-rules
sudo udevadm trigger
UDEV_EXIT=$?
set -e

if [ $UDEV_EXIT -eq 0 ]; then
    log_info "Udev правила перезагружены"
else
    log_warn "Не удалось перезагрузить udev, может потребоваться перезагрузка системы"
fi

# ------------------------------------------------------------
# ШАГ 4: Проверка доступных устройств
# ------------------------------------------------------------
log_step "4/5: Проверка доступных устройств..."

echo ""
echo -e "${CYAN}─── КАМЕРЫ ────────────────────────────────────────────${NC}"
CAMERAS=$(ls /dev/video* 2>/dev/null)
if [ -n "$CAMERAS" ]; then
    log_info "Найденные камеры:"
    for cam in $CAMERAS; do
        if [ -e "$cam" ]; then
            # Получаем имя камеры из sysfs
            CAM_NAME=$(cat /sys/class/video4linux/$(basename $cam)/name 2>/dev/null || echo "Неизвестная")
            echo "  ✅ $cam — $CAM_NAME"
        fi
    done
else
    log_warn "Камеры не найдены"
    echo "  ❌ /dev/video* не найдены"
fi

echo ""
echo -e "${CYAN}─── ДЖОЙСТИКИ / ГЕЙМПАДЫ ──────────────────────────────${NC}"
JOYSTICKS=$(ls /dev/input/js* 2>/dev/null)
if [ -n "$JOYSTICKS" ]; then
    log_info "Найденные джойстики:"
    for js in $JOYSTICKS; do
        echo "  ✅ $js"
    done
    # Показываем информацию о джойстиках
    if command -v jstest >/dev/null 2>&1; then
        jstest /dev/input/js0 2>/dev/null | head -1 || true
    fi
else
    log_warn "Джойстики не найдены (/dev/input/js*)"
    echo "  ❌ Джойстики не подключены"
fi

echo ""
echo -e "${CYAN}─── БАТАРЕЯ ───────────────────────────────────────────${NC}"
BAT_PATH="/sys/class/power_supply/BAT0"
if [ -d "$BAT_PATH" ]; then
    BAT_STATUS=$(cat "$BAT_PATH/status" 2>/dev/null || echo "Unknown")
    BAT_CAPACITY=$(cat "$BAT_PATH/capacity" 2>/dev/null || echo "N/A")
    BAT_VOLTAGE=$(cat "$BAT_PATH/voltage_now" 2>/dev/null || echo "0")
    BAT_VOLTAGE_V=$(echo "scale=2; $BAT_VOLTAGE / 1000000" | bc 2>/dev/null || echo "N/A")
    
    log_info "Батарея найдена:"
    echo "  ✅ Путь: $BAT_PATH"
    echo "  ✅ Статус: $BAT_STATUS"
    echo "  ✅ Заряд: ${BAT_CAPACITY}%"
    echo "  ✅ Напряжение: ${BAT_VOLTAGE_V}V"
else
    log_warn "Батарея не найдена ($BAT_PATH)"
    # Проверяем другие варианты
    for bat in /sys/class/power_supply/BAT*; do
        if [ -d "$bat" ]; then
            log_info "Найдена батарея: $bat"
        fi
    done
fi

echo ""
echo -e "${CYAN}─── ПОСЛЕДОВАТЕЛЬНЫЕ УСТРОЙСТВА ───────────────────────${NC}"
SERIAL_DEVICES=$(ls /dev/ttyACM* /dev/ttyUSB* 2>/dev/null)
if [ -n "$SERIAL_DEVICES" ]; then
    log_info "Найденные последовательные устройства:"
    for dev in $SERIAL_DEVICES; do
        echo "  ✅ $dev"
    done
else
    log_warn "Последовательные устройства не найдены (/dev/ttyACM*, /dev/ttyUSB*)"
fi

echo ""
echo -e "${CYAN}─── СЕТЕВЫЕ ИНТЕРФЕЙСЫ ────────────────────────────────${NC}"
log_info "Доступные сетевые интерфейсы:"
ip -brief link show | while read -r line; do
    echo "  $line"
done

# ------------------------------------------------------------
# ШАГ 5: Настройка сети (опционально)
# ------------------------------------------------------------
log_step "5/5: Настройка сетевых параметров для датчиков..."

# Настройка размера буфера для Ethernet (полезно для LIDAR Velodyne)
log_info "Настройка сетевых буферов для высокопроизводительных датчиков..."
set +e
sudo sysctl -w net.core.rmem_max=26214400 2>/dev/null || true
sudo sysctl -w net.core.rmem_default=26214400 2>/dev/null || true
sudo sysctl -w net.core.netdev_max_backlog=2000 2>/dev/null || true
set -e

# Сохранение настроек для постоянства
SYSCTL_FILE="/etc/sysctl.d/99-robot-network.conf"
if [ ! -f "$SYSCTL_FILE" ]; then
    log_info "Создание $SYSCTL_FILE для постоянных настроек сети..."
    echo "# Network settings for robot sensors (Air-Ground Security MVP)" | sudo tee "$SYSCTL_FILE" > /dev/null
    echo "net.core.rmem_max = 26214400" | sudo tee -a "$SYSCTL_FILE" > /dev/null
    echo "net.core.rmem_default = 26214400" | sudo tee -a "$SYSCTL_FILE" > /dev/null
    echo "net.core.netdev_max_backlog = 2000" | sudo tee -a "$SYSCTL_FILE" > /dev/null
fi

# ------------------------------------------------------------
# ИТОГОВАЯ ИНФОРМАЦИЯ
# ------------------------------------------------------------
echo ""
echo -e "${CYAN}╔════════════════════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║       НАСТРОЙКА УСТРОЙСТВ ЗАВЕРШЕНА                          ║${NC}"
echo -e "${CYAN}╚════════════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "${GREEN}Выполнено:${NC}"
echo "  ✅ Пользователь добавлен в группы: ${GROUPS_TO_ADD[*]}"
echo "  ✅ Udev-правила установлены: $UDEV_RULES_DST"
echo "  ✅ Udev перезагружен"
echo "  ✅ Проверены устройства"
echo "  ✅ Настроены сетевые параметры"
echo ""
echo -e "${YELLOW}ВАЖНО:${NC} Для применения изменений групп необходимо:"
echo "  1. Выйти из системы и войти заново, ИЛИ"
echo "  2. Перезагрузить компьютер: sudo reboot"
echo ""
echo -e "${CYAN}Проверка после перезагрузки:${NC}"
echo "  groups                          # показать все группы"
echo "  ls -la /dev/video*              # камеры"
echo "  ls -la /dev/input/js*           # джойстики"
echo "  cat /sys/class/power_supply/BAT0/status  # батарея"
echo ""
echo -e "${CYAN}Следующий шаг:${NC} ./scripts/04_build_workspace.sh"
