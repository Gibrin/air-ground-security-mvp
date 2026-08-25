#!/bin/bash
#
# 02_setup_ssh.sh
# Настройка удалённого доступа по SSH для проекта Air-Ground Security MVP
#
# Использование:
#   chmod +x scripts/02_setup_ssh.sh
#   ./scripts/02_setup_ssh.sh
#
# Что делает:
#   1. Устанавливает и запускает SSH-сервер
#   2. Настраивает безопасный /etc/ssh/sshd_config
#   3. Генерирует SSH-ключи для текущего пользователя (если отсутствуют)
#   4. Настраивает UFW firewall для разрешения SSH
#   5. Выводит инструкции по подключению
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

export DEBIAN_FRONTEND=noninteractive

CURRENT_USER=$(whoami)
SSH_DIR="$HOME/.ssh"
AUTHORIZED_KEYS="$SSH_DIR/authorized_keys"
SSHD_CONFIG="/etc/ssh/sshd_config"
SSHD_BACKUP="/etc/ssh/sshd_config.backup.$(date +%Y%m%d_%H%M%S)"

log_info "=== Настройка удалённого доступа по SSH ==="
log_info "Пользователь: $CURRENT_USER"

# ШАГ 1: Установка openssh-server
log_step "1/5: Проверка и установка openssh-server..."
if ! dpkg -l | grep -q openssh-server; then
    log_info "openssh-server не установлен, устанавливаем..."
    set +e
    sudo apt-get update -y
    sudo apt-get install -y --fix-missing openssh-server openssh-client
    INSTALL_EXIT=$?
    set -e
    if [ $INSTALL_EXIT -ne 0 ]; then
        log_error "Не удалось установить openssh-server"
        exit 1
    fi
else
    log_info "openssh-server уже установлен"
fi

# ШАГ 2: Создание резервной копии sshd_config
log_step "2/5: Создание резервной копии $SSHD_CONFIG..."
if [ -f "$SSHD_CONFIG" ]; then
    sudo cp "$SSHD_CONFIG" "$SSHD_BACKUP"
    log_info "Резервная копия создана: $SSHD_BACKUP"
else
    log_warn "$SSHD_CONFIG не найден, используем конфигурацию по умолчанию"
fi

# ШАГ 3: Настройка sshd_config
log_step "3/5: Настройка $SSHD_CONFIG..."

# Функция для установки параметра в sshd_config
set_ssh_param() {
    local key="$1"
    local value="$2"
    if sudo grep -q "^#*$key" "$SSHD_CONFIG"; then
        sudo sed -i "s|^#*$key.*|$key $value|g" "$SSHD_CONFIG"
    else
        echo "$key $value" | sudo tee -a "$SSHD_CONFIG" > /dev/null
    fi
}

# Применяем безопасные настройки
set_ssh_param "Port" "22"
set_ssh_param "Protocol" "2"
set_ssh_param "PermitRootLogin" "no"
set_ssh_param "PasswordAuthentication" "yes"
set_ssh_param "PubkeyAuthentication" "yes"
set_ssh_param "X11Forwarding" "yes"
set_ssh_param "AllowTcpForwarding" "yes"
set_ssh_param "PermitEmptyPasswords" "no"
set_ssh_param "MaxAuthTries" "3"
set_ssh_param "ClientAliveInterval" "300"
set_ssh_param "ClientAliveCountMax" "2"

log_info "Параметры SSH-сервера настроены"

# ШАГ 4: Генерация SSH-ключей для текущего пользователя
log_step "4/5: Настройка SSH-ключей для пользователя $CURRENT_USER..."

if [ ! -d "$SSH_DIR" ]; then
    mkdir -p "$SSH_DIR"
    chmod 700 "$SSH_DIR"
    log_info "Создан каталог $SSH_DIR"
fi

# Генерация Ed25519 ключа (современный стандарт)
if [ ! -f "$SSH_DIR/id_ed25519" ]; then
    log_info "Генерация Ed25519 ключа..."
    ssh-keygen -t ed25519 -f "$SSH_DIR/id_ed25519" -N "" -C "$CURRENT_USER@$(hostname)" -q
    log_info "Ed25519 ключ создан: $SSH_DIR/id_ed25519"
else
    log_info "Ed25519 ключ уже существует"
fi

# Генерация RSA ключа (для совместимости со старыми системами)
if [ ! -f "$SSH_DIR/id_rsa" ]; then
    log_info "Генерация RSA ключа (4096 бит)..."
    ssh-keygen -t rsa -b 4096 -f "$SSH_DIR/id_rsa" -N "" -C "$CURRENT_USER@$(hostname)" -q
    log_info "RSA ключ создан: $SSH_DIR/id_rsa"
else
    log_info "RSA ключ уже существует"
fi

# Добавление публичного ключа в authorized_keys
if [ -f "$SSH_DIR/id_ed25519.pub" ]; then
    PUB_KEY=$(cat "$SSH_DIR/id_ed25519.pub")
    if [ ! -f "$AUTHORIZED_KEYS" ] || ! grep -q "$PUB_KEY" "$AUTHORIZED_KEYS"; then
        echo "$PUB_KEY" >> "$AUTHORIZED_KEYS"
        log_info "Публичный ключ добавлен в $AUTHORIZED_KEYS"
    fi
fi

# Установка правильных прав
chmod 600 "$SSH_DIR/id_ed25519" "$SSH_DIR/id_rsa" 2>/dev/null || true
chmod 644 "$SSH_DIR/id_ed25519.pub" "$SSH_DIR/id_rsa.pub" 2>/dev/null || true
chmod 600 "$AUTHORIZED_KEYS" 2>/dev/null || true
chmod 700 "$SSH_DIR" 2>/dev/null || true
chown -R "$CURRENT_USER:$CURRENT_USER" "$SSH_DIR" 2>/dev/null || true

log_info "Права на SSH-файлы настроены"

# ШАГ 5: Настройка firewall (UFW)
log_step "5/5: Настройка firewall..."
if command -v ufw >/dev/null 2>&1; then
    log_info "Настройка UFW для разрешения SSH (порт 22)..."
    set +e
    sudo ufw allow 22/tcp >/dev/null 2>&1 || true
    sudo ufw allow ssh >/dev/null 2>&1 || true
    
    # Проверка статуса UFW
    if sudo ufw status | grep -q "inactive"; then
        log_warn "UFW не активен. SSH-трафик не фильтруется."
        log_info "Для активации выполните: sudo ufw enable"
    else
        log_info "UFW активен, порт 22 разрешён"
    fi
    set -e
else
    log_warn "UFW не установлен, пропускаем настройку firewall"
fi

# Перезапуск SSH-сервера для применения настроек
log_info "Перезапуск SSH-сервера..."
set +e
sudo systemctl restart ssh
sudo systemctl enable ssh
RESTART_EXIT=$?
set -e

if [ $RESTART_EXIT -eq 0 ]; then
    log_info "SSH-сервер перезапущен и активирован при загрузке"
else
    log_error "Не удалось перезапустить SSH-сервер"
fi

# Получение IP-адресов
log_info "=== Итоговая информация ==="

IP_LOCAL="127.0.0.1"
IP_LAN=$(ip route get 1.1.1.1 2>/dev/null | awk '{print $7; exit}')
HOSTNAME_STR=$(hostname)

echo ""
echo -e "${CYAN}╔════════════════════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║          НАСТРОЙКА SSH ЗАВЕРШЕНА УСПЕШНО                    ║${NC}"
echo -e "${CYAN}╚════════════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "${GREEN}Пользователь:${NC} $CURRENT_USER"
echo -e "${GREEN}Hostname:${NC}     $HOSTNAME_STR"
echo -e "${GREEN}Локальный IP:${NC} ${IP_LAN:-<не определён>}"
echo -e "${GREEN}Порт SSH:${NC}     22"
echo ""
echo -e "${CYAN}Подключение с другого компьютера (в той же сети):${NC}"
echo "  ssh $CURRENT_USER@${IP_LAN:-<IP-адрес>}"
echo ""
echo -e "${CYAN}Локальная проверка:${NC}"
echo "  ssh $CURRENT_USER@localhost"
echo ""
echo -e "${CYAN}SSH-ключи пользователя:${NC}"
ls -la "$SSH_DIR" 2>/dev/null | grep -E "\.pub$|id_" | awk '{print "  " $NF}'
echo ""
echo -e "${CYAN}Чтобы скопировать публичный ключ на другой сервер:${NC}"
echo "  ssh-copy-id user@remote-host"
echo ""
echo -e "${CYAN}Следующий шаг:${NC} ./scripts/03_setup_devices.sh"
