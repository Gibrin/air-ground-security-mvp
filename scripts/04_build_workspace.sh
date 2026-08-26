#!/bin/bash
#
# 04_build_workspace.sh
# Сборка рабочего пространства (workspace) для проекта Air-Ground Security MVP
#
# Использование:
#   chmod +x scripts/04_build_workspace.sh
#   ./scripts/04_build_workspace.sh
#
# Что делает:
#   1. Проверяет структуру рабочего пространства
#   2. Проверяет наличие файлов пакетов (package.xml, CMakeLists.txt)
#   3. Устанавливает зависимости через rosdep
#   4. Собирает рабочее пространство через catkin_make
#   5. Проверяет результаты сборки
#   6. Настраивает автоподгрузку рабочего пространства в ~/.bashrc
#
# Требования:
#   - Ubuntu 20.04 LTS
#   - ROS 1 Noetic (установлен через 01_install_ros_packages.sh)
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

# Определение пути к корню репозитория
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(dirname "$SCRIPT_DIR")"
WS_SRC="$REPO_ROOT/src"
WS_DEVEL="$REPO_ROOT/devel"
WS_BUILD="$REPO_ROOT/build"

# Проверка ОС
if ! grep -q "Ubuntu" /etc/os-release; then
    log_error "Этот скрипт предназначен только для Ubuntu"
    exit 1
fi

# Проверка установки ROS
if [ ! -f /opt/ros/noetic/setup.bash ]; then
    log_error "ROS Noetic не установлен. Сначала выполните ./scripts/01_install_ros_packages.sh"
    exit 1
fi

# Подгрузка окружения ROS
source /opt/ros/noetic/setup.bash

log_info "=== Сборка рабочего пространства ==="
log_info "Корень репозитория: $REPO_ROOT"
log_info "Каталог исходников: $WS_SRC"

# ------------------------------------------------------------
# ШАГ 1: Проверка структуры рабочего пространства
# ------------------------------------------------------------
log_step "1/6: Проверка структуры рабочего пространства..."

if [ ! -d "$WS_SRC" ]; then
    log_warn "Каталог $WS_SRC не найден, создаём..."
    mkdir -p "$WS_SRC"
fi

# Поиск пакетов в рабочем пространстве
PACKAGE_COUNT=0
for pkg_dir in "$WS_SRC"/*; do
    if [ -d "$pkg_dir" ]; then
        if [ -f "$pkg_dir/package.xml" ] || [ -f "$pkg_dir/CMakeLists.txt" ]; then
            PACKAGE_COUNT=$((PACKAGE_COUNT + 1))
            log_info "Найден пакет: $(basename "$pkg_dir")"
        fi
    fi
done

if [ $PACKAGE_COUNT -eq 0 ]; then
    log_warn "Пакеты не найдены в $WS_SRC"
    log_warn "Рабочее пространство будет создано, но сборка пакетов невозможна"
    log_warn "Добавьте пакеты в $WS_SRC или создайте их через catkin_create_pkg"
fi

# ------------------------------------------------------------
# ШАГ 2: Проверка файлов пакетов
# ------------------------------------------------------------
log_step "2/6: Проверка файлов пакетов..."

MISSING_FILES=0

for pkg_dir in "$WS_SRC"/*; do
    if [ -d "$pkg_dir" ]; then
        PKG_NAME=$(basename "$pkg_dir")
        
        # Проверка package.xml
        PKG_XML="$pkg_dir/package.xml"
        if [ ! -f "$PKG_XML" ]; then
            log_warn "Пакет $PKG_NAME: отсутствует package.xml"
            MISSING_FILES=$((MISSING_FILES + 1))
        elif [ ! -s "$PKG_XML" ]; then
            log_warn "Пакет $PKG_NAME: package.xml ПУСТОЙ"
            MISSING_FILES=$((MISSING_FILES + 1))
        else
            log_info "Пакет $PKG_NAME: package.xml в порядке"
        fi
        
        # Проверка CMakeLists.txt
        CMAKE_FILE="$pkg_dir/CMakeLists.txt"
        if [ ! -f "$CMAKE_FILE" ]; then
            log_warn "Пакет $PKG_NAME: отсутствует CMakeLists.txt"
            MISSING_FILES=$((MISSING_FILES + 1))
        elif [ ! -s "$CMAKE_FILE" ]; then
            log_warn "Пакет $PKG_NAME: CMakeLists.txt ПУСТОЙ"
            MISSING_FILES=$((MISSING_FILES + 1))
        else
            log_info "Пакет $PKG_NAME: CMakeLists.txt в порядке"
        fi
    fi
done

if [ $MISSING_FILES -gt 0 ]; then
    log_warn ""
    log_warn "⚠️  ОБНАРУЖЕНЫ ПРОБЛЕМЫ: $MISSING_FILES файлов отсутствуют или пусты"
    log_warn "Сборка может завершиться с ошибкой."
    log_warn "Рекомендуется наполнить файлы пакетов перед сборкой (Приоритет 3)."
    log_warn ""
    
    # Спрашиваем пользователя о продолжении
    read -p "Продолжить сборку? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        log_info "Сборка отменена пользователем"
        exit 0
    fi
fi

# ------------------------------------------------------------
# ШАГ 3: Установка зависимостей через rosdep
# ------------------------------------------------------------
log_step "3/6: Установка зависимостей через rosdep..."

# Проверка инициализации rosdep
if [ ! -f /etc/ros/rosdep/sources.list.d/20-default.list ]; then
    log_info "Инициализация rosdep..."
    set +e
    sudo rosdep init 2>/dev/null || true
    rosdep update 2>/dev/null || true
    set -e
fi

# Установка зависимостей пакетов
if [ $PACKAGE_COUNT -gt 0 ]; then
    log_info "Установка зависимостей из package.xml..."
    set +e
    rosdep install --from-paths "$WS_SRC" --ignore-src -r -y
    ROSDEP_EXIT=$?
    set -e
    
    if [ $ROSDEP_EXIT -eq 0 ]; then
        log_info "Зависимости установлены успешно"
    else
        log_warn "Некоторые зависимости не удалось установить (код $ROSDEP_EXIT)"
        log_warn "Продолжаем сборку..."
    fi
else
    log_info "Пропускаем установку зависимостей (пакеты не найдены)"
fi

# ------------------------------------------------------------
# ШАГ 4: Сборка рабочего пространства
# ------------------------------------------------------------
log_step "4/6: Сборка рабочего пространства через catkin_make..."

cd "$REPO_ROOT"

# Проверка наличия CMakeLists.txt в корне рабочего пространства
ROOT_CMAKE="$WS_SRC/CMakeLists.txt"
if [ ! -f "$ROOT_CMAKE" ]; then
    log_info "Инициализация рабочего пространства (создание корневого CMakeLists.txt)..."
    cd "$WS_SRC"
    catkin_init_workspace
    cd "$REPO_ROOT"
fi

# Запуск сборки
log_info "Запуск сборки..."
set +e
catkin_make
BUILD_EXIT=$?
set -e

if [ $BUILD_EXIT -ne 0 ]; then
    log_error "❌ Сборка завершилась с ошибкой (код $BUILD_EXIT)"
    log_error "Проверьте файлы пакетов и попробуйте снова"
    
    if [ $MISSING_FILES -gt 0 ]; then
        log_warn "Вероятная причина: пустые или отсутствующие файлы пакетов"
        log_warn "Наполните package.xml и CMakeLists.txt (Приоритет 3)"
    fi
    
    exit 1
fi

log_info "Сборка завершена успешно"

# ------------------------------------------------------------
# ШАГ 5: Проверка результатов сборки
# ------------------------------------------------------------
log_step "5/6: Проверка результатов сборки..."

if [ -d "$WS_DEVEL" ]; then
    log_info "Каталог devel/ создан"
    
    if [ -f "$WS_DEVEL/setup.bash" ]; then
        log_info "setup.bash найден: $WS_DEVEL/setup.bash"
    else
        log_warn "setup.bash не найден в $WS_DEVEL"
    fi
else
    log_warn "Каталог devel/ не создан"
fi

if [ -d "$WS_BUILD" ]; then
    log_info "Каталог build/ создан"
    
    # Подсчёт собранных библиотек и исполняемых файлов
    LIB_COUNT=$(find "$WS_DEVEL/lib" -name "*.so" 2>/dev/null | wc -l)
    BIN_COUNT=$(find "$WS_DEVEL/lib" -type f -executable 2>/dev/null | wc -l)
    
    log_info "Собрано библиотек: $LIB_COUNT"
    log_info "Собрано исполняемых файлов: $BIN_COUNT"
else
    log_warn "Каталог build/ не создан"
fi

# ------------------------------------------------------------
# ШАГ 6: Настройка автоподгрузки рабочего пространства
# ------------------------------------------------------------
log_step "6/6: Настройка автоподгрузки рабочего пространства..."

BASHRC_FILE="$HOME/.bashrc"
WS_SOURCE_LINE="source $WS_DEVEL/setup.bash"

if ! grep -q "$WS_SOURCE_LINE" "$BASHRC_FILE"; then
    log_info "Добавление автоподгрузки рабочего пространства в $BASHRC_FILE..."
    echo "" >> "$BASHRC_FILE"
    echo "# Air-Ground Security MVP workspace (added by 04_build_workspace.sh)" >> "$BASHRC_FILE"
    echo "$WS_SOURCE_LINE" >> "$BASHRC_FILE"
    log_info "Автоподгрузка добавлена"
else
    log_info "Автоподгрузка уже настроена"
fi

# ------------------------------------------------------------
# ИТОГОВАЯ ИНФОРМАЦИЯ
# ------------------------------------------------------------
echo ""
echo -e "${CYAN}╔════════════════════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║       СБОРКА РАБОЧЕГО ПРОСТРАНСТВА ЗАВЕРШЕНА               ║${NC}"
echo -e "${CYAN}╚════════════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "${GREEN}Выполнено:${NC}"
echo "   Проверена структура рабочего пространства"
echo "   Проверены файлы пакетов"
echo "   Установлены зависимости через rosdep"
echo "   Собрано рабочее пространство"
echo "   Настроена автоподгрузка в ~/.bashrc"
echo ""
echo -e "${CYAN}Для применения изменений выполните:${NC}"
echo "  source ~/.bashrc"
echo ""
echo -e "${CYAN}Или вручную:${NC}"
echo "  source $WS_DEVEL/setup.bash"
echo ""
echo -e "${CYAN}Проверка:${NC}"
echo "  rospack list | grep air_ground"
echo "  roscd air_ground_bringup"
echo ""
echo -e "${CYAN}Следующий шаг:${NC} Наполнение файлов пакетов (Приоритет 3)"
echo "  - package.xml"
echo "  - CMakeLists.txt"
echo "  - launch/system.launch"
echo "  - config/default.rviz"
echo "  - scripts/battery_node.py"
