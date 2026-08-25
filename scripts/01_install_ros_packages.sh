#!/bin/bash
#
# 01_install_ros_packages.sh
# Установка ROS-пакетов и библиотек для проекта Air-Ground Security MVP
#
# Использование:
#   chmod +x scripts/01_install_ros_packages.sh
#   ./scripts/01_install_ros_packages.sh
#
# Требования:
#   - Ubuntu 20.04 LTS
#   - ROS 1 Noetic (установится, если отсутствует)
#   - Права sudo
#

set -o pipefail

# Цвета для логирования
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# Проверка ОС
if ! grep -q "Ubuntu" /etc/os-release; then
    log_error "Этот скрипт предназначен только для Ubuntu"
    exit 1
fi

UBUNTU_VERSION=$(lsb_release -rs)
if [ "$UBUNTU_VERSION" != "20.04" ]; then
    log_warn "Ожидается Ubuntu 20.04, обнаружена $UBUNTU_VERSION"
fi

# Проверка прав sudo
if ! sudo -v; then
    log_error "Не удалось получить права sudo"
    exit 1
fi

export DEBIAN_FRONTEND=noninteractive

log_info "=== Установка ROS Noetic и пакетов ==="

# Настройка репозиториев Ubuntu
log_info "Настройка репозиториев Ubuntu (universe, restricted, multiverse)..."
sudo add-apt-repository -y universe 2>/dev/null || true
sudo add-apt-repository -y restricted 2>/dev/null || true
sudo add-apt-repository -y multiverse 2>/dev/null || true

# Добавление репозитория ROS Noetic (если отсутствует)
ROS_KEYRING=/usr/share/keyrings/ros-archive-keyring.gpg
ROS_SOURCE=/etc/apt/sources.list.d/ros2.list

if [ ! -f "$ROS_KEYRING" ]; then
    log_info "Добавление репозитория ROS Noetic..."
    sudo apt-get update -y || true
    sudo apt-get install -y curl gnupg lsb-release || true
    
    sudo curl -sSL https://raw.githubusercontent.com/ros/rosdistro/master/ros.key \
        -o "$ROS_KEYRING"
    
    echo "deb [arch=$(dpkg --print-architecture) signed-by=$ROS_KEYRING] \
http://packages.ros.org/ros/ubuntu $(lsb_release -cs) main" | \
        sudo tee "$ROS_SOURCE" > /dev/null
else
    log_info "Репозиторий ROS уже добавлен"
fi

# Обновление списка пакетов (без критического падения на ошибках OSRF)
log_info "Обновление списка пакетов..."
set +e
sudo apt-get update -y
APT_UPDATE_EXIT=$?
set -e

if [ $APT_UPDATE_EXIT -ne 0 ]; then
    log_warn "apt-get update завершился с ошибкой (проблемы со сторонними репозиториями)"
    log_warn "Продолжаем установку ROS-пакетов..."
fi

# Проверка установки ROS
log_info "Проверка установки ROS..."
if [ ! -f /opt/ros/noetic/setup.bash ]; then
    log_info "ROS Noetic не найден, устанавливаем ROS Noetic Desktop-Full..."
    set +e
    sudo apt-get install -y --fix-missing ros-noetic-desktop-full
    ROS_INSTALL_EXIT=$?
    set -e
    
    if [ $ROS_INSTALL_EXIT -ne 0 ]; {
        log_error "Не удалось установить ROS Noetic Desktop-Full"
        log_info "Попробуем установить ROS Noetic Desktop (минимальный набор)..."
        set +e
        sudo apt-get install -y --fix-missing ros-noetic-desktop
        ROS_INSTALL_EXIT=$?
        set -e
    }
    
    if [ $ROS_INSTALL_EXIT -ne 0 ]; then
        log_error "Не удалось установить ROS Noetic"
        exit 1
    fi
else
    log_info "ROS Noetic уже установлен"
fi

# Подгрузка окружения ROS для дальнейших команд
set +a
source /opt/ros/noetic/setup.bash
set -a

# Установка базовых инструментов разработки для ROS
log_info "Установка инструментов разработки ROS..."
set +e
sudo apt-get install -y --fix-missing \
    python3-rosdep \
    python3-rosinstall \
    python3-rosinstall-generator \
    python3-wstool \
    build-essential \
    python3-catkin-tools \
    python3-osrf-pycommon
ROS_DEV_EXIT=$?
set -e

if [ $ROS_DEV_EXIT -ne 0 ]; then
    log_warn "Некоторые ROS dev-инструменты не установились"
fi

# Установка ROS-пакетов, необходимых для работы с дроном и датчиками
log_info "Установка ROS-пакетов для управления дроном (MAVROS)..."
set +e
sudo apt-get install -y --fix-missing \
    ros-noetic-mavros \
    ros-noetic-mavros-extras \
    ros-noetic-mavlink \
    ros-noetic-control-toolbox
MAVROS_EXIT=$?
set -e

if [ $MAVROS_EXIT -ne 0 ]; then
    log_warn "Некоторые MAVROS пакеты не установились, пробуем альтернативные"
fi

log_info "Установка MAVROS geographic libs (для географических сообщений)..."
set +e
sudo apt-get install -y --fix-missing geographiclib-tools
GEO_EXIT=$?
set -e

if [ $GEO_EXIT -eq 0 ]; then
    # Установка рекомендованных датчиков GeographicLib для MAVROS
    if [ -x /opt/ros/noetic/lib/mavros/install_geographiclib_datasets.sh ]; then
        log_info "Установка датасетов GeographicLib для MAVROS..."
        sudo /opt/ros/noetic/lib/mavros/install_geographiclib_datasets.sh || true
    fi
fi

log_info "Установка ROS-пакетов для трансформаций и сообщений..."
set +e
sudo apt-get install -y --fix-missing \
    ros-noetic-tf2 \
    ros-noetic-tf2-ros \
    ros-noetic-tf2-geometry-msgs \
    ros-noetic-geometry-msgs \
    ros-noetic-sensor-msgs \
    ros-noetic-std-msgs \
    ros-noetic-nav-msgs \
    ros-noetic-diagnostic-msgs \
    ros-noetic-diagnostic-updater
TF_EXIT=$?
set -e

if [ $TF_EXIT -ne 0 ]; then
    log_warn "Некоторые пакеты трансформаций не установились"
fi

log_info "Установка пакетов для визуализации (rviz, rqt)..."
set +e
sudo apt-get install -y --fix-missing \
    ros-noetic-rviz \
    ros-noetic-rqt \
    ros-noetic-rqt-common-plugins \
    ros-noetic-rqt-robot-plugins \
    ros-noetic-rqt-gui \
    ros-noetic-rqt-gui-py \
    ros-noetic-rqt-plot \
    ros-noetic-rqt-console \
    ros-noetic-rqt-logger-level \
    ros-noetic-rqt-topic
RVIZ_EXIT=$?
set -e

if [ $RVIZ_EXIT -ne 0 ]; then
    log_warn "Некоторые пакеты визуализации не установились"
fi

log_info "Установка пакетов для работы с моделями роботов..."
set +e
sudo apt-get install -y --fix-missing \
    ros-noetic-xacro \
    ros-noetic-urdf \
    ros-noetic-joint-state-publisher \
    ros-noetic-joint-state-publisher-gui \
    ros-noetic-robot-state-publisher
URDF_EXIT=$?
set -e

if [ $URDF_EXIT -ne 0 ]; then
    log_warn "Некоторые URDF-пакеты не установились"
fi

log_info "Установка пакетов для подключения джойстика и камер..."
set +e
sudo apt-get install -y --fix-missing \
    ros-noetic-joy \
    ros-noetic-joy-teleop \
    ros-noetic-usb-cam \
    ros-noetic-v4l2-camera \
    ros-noetic-image-transport \
    ros-noetic-cv-bridge \
    ros-noetic-image-geometry
INPUT_EXIT=$?
set -e

if [ $INPUT_EXIT -ne 0 ]; then
    log_warn "Некоторые пакеты ввода не установились"
fi

log_info "Установка пакетов для симуляции в Gazebo..."
set +e
sudo apt-get install -y --fix-missing \
    ros-noetic-gazebo-ros \
    ros-noetic-gazebo-ros-pkgs \
    ros-noetic-gazebo-ros-control \
    ros-noetic-gazebo-plugins
GAZEBO_EXIT=$?
set -e

if [ $GAZEBO_EXIT -ne 0 ]; then
    log_warn "Некоторые Gazebo-пакеты не установились"
fi

log_info "Установка пакета для локализации и навигации (опционально)..."
set +e
sudo apt-get install -y --fix-missing \
    ros-noetic-robot-localization \
    ros-noetic-navigation \
    ros-noetic-move-base \
    ros-noetic-amcl
NAV_EXIT=$?
set -e

if [ $NAV_EXIT -ne 0 ]; then
    log_warn "Навигационные пакеты не установились (не критично для Фазы 1)"
fi

# Установка Python-пакетов
log_info "Установка Python-пакетов для ROS..."
set +e
pip3 install --user --upgrade \
    catkin_pkg \
    rospkg \
    empy==3.3.4 \
    defusedxml \
    pyserial \
    numpy \
    pyyaml
PIP_EXIT=$?
set -e

if [ $PIP_EXIT -ne 0 ]; then
    log_warn "Некоторые Python-пакеты не установились"
fi

# Установка и инициализация rosdep
log_info "Инициализация rosdep..."
set +e
sudo rosdep init 2>/dev/null || true
rosdep update 2>/dev/null || true
set -e

# Настройка автоподгрузки ROS в bashrc
BASHRC_FILE="$HOME/.bashrc"
ROS_SOURCE_LINE="source /opt/ros/noetic/setup.bash"

if ! grep -q "$ROS_SOURCE_LINE" "$BASHRC_FILE"; then
    log_info "Добавление автоподгрузки ROS в $BASHRC_FILE..."
    echo "" >> "$BASHRC_FILE"
    echo "# ROS Noetic setup (added by 01_install_ros_packages.sh)" >> "$BASHRC_FILE"
    echo "$ROS_SOURCE_LINE" >> "$BASHRC_FILE"
fi

# Очистка кэша apt
log_info "Очистка кэша apt..."
sudo apt-get clean
sudo apt-get autoremove -y || true

log_info "=== Установка ROS-пакетов завершена ==="
log_info "Следующий шаг: ./scripts/02_setup_ssh.sh"
log_info "Перезапустите терминал или выполните: source ~/.bashrc"
