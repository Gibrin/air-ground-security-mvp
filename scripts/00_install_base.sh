#!/bin/bash
#
# 00_install_base.sh
# Установка базовых зависимостей системы для проекта Air-Ground Security MVP
#
# Использование:
#   chmod +x scripts/00_install_base.sh
#   ./scripts/00_install_base.sh
#
# Требования:
#   - Ubuntu 20.04 LTS
#   - Права sudo
#
# ВАЖНО: Мы НЕ делаем полное обновление системы (apt-get upgrade),
# так как это может сломать уже установленные ROS/Gazebo пакеты.
# Устанавливаем только необходимые зависимости.
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

log_info "=== Установка базовых зависимостей ==="

# Обновление списка пакетов (с обработкой ошибок репозиториев)
log_info "Обновление списка пакетов..."
set +e  # Не падаем на ошибках сторонних репозиториев
sudo apt-get update -y
APT_UPDATE_EXIT=$?
set -e

if [ $APT_UPDATE_EXIT -ne 0 ]; then
    log_warn "apt-get update завершился с ошибкой (проблемы со сторонними репозиториями)"
    log_warn "Продолжаем установку базовых пакетов..."
fi

# Установка базовых инструментов разработки
log_info "Установка базовых инструментов разработки..."
set +e
sudo apt-get install -y --fix-missing \
    git \
    curl \
    wget \
    build-essential \
    cmake \
    pkg-config \
    software-properties-common \
    apt-transport-https \
    ca-certificates \
    gnupg \
    lsb-release
INSTALL_DEV_EXIT=$?
set -e

if [ $INSTALL_DEV_EXIT -ne 0 ]; then
    log_error "Ошибка установки инструментов разработки"
    exit 1
fi

# Установка Python 3 и зависимостей
log_info "Установка Python 3 и зависимостей..."
set +e
sudo apt-get install -y --fix-missing \
    python3 \
    python3-dev \
    python3-pip \
    python3-setuptools \
    python3-wheel \
    python3-venv \
    python3-numpy \
    python3-yaml \
    python3-empy \
    python3-defusedxml
INSTALL_PY_EXIT=$?
set -e

if [ $INSTALL_PY_EXIT -ne 0 ]; then
    log_error "Ошибка установки Python зависимостей"
    exit 1
fi

# Установка дополнительных утилит
log_info "Установка дополнительных утилит..."
set +e
sudo apt-get install -y --fix-missing \
    htop \
    tmux \
    vim \
    nano \
    net-tools \
    iputils-ping \
    iproute2 \
    openssh-server \
    openssh-client
INSTALL_UTIL_EXIT=$?
set -e

if [ $INSTALL_UTIL_EXIT -ne 0 ]; then
    log_warn "Некоторые утилиты не установились, продолжаем"
fi

# Активация SSH сервиса
log_info "Активация SSH сервиса..."
sudo systemctl enable ssh || true
sudo systemctl start ssh || true

# Очистка кэша apt (безопасно, не ломает систему)
log_info "Очистка кэша apt..."
sudo apt-get clean
sudo apt-get autoremove -y || true

log_info "=== Установка базовых зависимостей завершена ==="
log_info "Следующий шаг: ./scripts/01_install_ros_packages.sh"
