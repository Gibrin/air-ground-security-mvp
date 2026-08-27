# ============================================================
# Dockerfile для проекта Air-Ground Security System — MVP
# ============================================================
FROM ros:noetic-ros-base

LABEL maintainer="Gibrin <gibrin@users.noreply.github.com>"
LABEL description="Air-Ground Security System MVP - Phase 1"
LABEL version="1.0"

ENV DEBIAN_FRONTEND=noninteractive
ENV ROS_DISTRO=noetic
ENV CATKIN_WS=/root/catkin_ws
ENV SHELL=/bin/bash

# ============================================================
# Добавление стабильного репозитория ROS
# ============================================================
RUN apt-get update && apt-get install -y --no-install-recommends \
    gnupg \
    curl \
    lsb-release \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/* \
    && curl -fsSL https://raw.githubusercontent.com/ros/rosdistro/master/ros.asc \
       | gpg --dearmor -o /usr/share/keyrings/ros-archive-keyring.gpg \
    && echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/ros-archive-keyring.gpg] http://packages.ros.org/ros/ubuntu $(lsb_release -cs) main" \
       > /etc/apt/sources.list.d/ros-latest.list

# ============================================================
# Установка базовых зависимостей
# ============================================================
RUN apt-get update && apt-get install -y --no-install-recommends --fix-missing \
    git \
    wget \
    build-essential \
    cmake \
    python3-pip \
    python3-dev \
    python3-catkin-pkg \
    python3-rospkg \
    python3-rosdep \
    python3-wstool \
    python3-empy \
    python3-defusedxml \
    python3-numpy \
    python3-yaml \
    openssh-server \
    openssh-client \
    sudo \
    nano \
    vim \
    tmux \
    htop \
    net-tools \
    iproute2 \
    && rm -rf /var/lib/apt/lists/*

# ============================================================
# Установка ROS-пакетов для проекта
# ============================================================
RUN apt-get update \
    && (apt-get install -y --no-install-recommends --fix-missing \
        ros-noetic-rviz \
        ros-noetic-rqt \
        ros-noetic-rqt-common-plugins \
        ros-noetic-rqt-gui \
        ros-noetic-rqt-gui-py \
        ros-noetic-rqt-plot \
        ros-noetic-rqt-console \
        ros-noetic-rqt-topic \
        ros-noetic-joy \
        ros-noetic-usb-cam \
        ros-noetic-tf2 \
        ros-noetic-tf2-ros \
        ros-noetic-mavros \
        ros-noetic-mavros-extras \
        ros-noetic-xacro \
        ros-noetic-robot-state-publisher \
    || apt-get install -y -f) \
    && rm -rf /var/lib/apt/lists/*

# ============================================================
# Инициализация rosdep (не критично для сборки)
# ============================================================
RUN (rosdep init 2>/dev/null || true) \
    && (rosdep update 2>/dev/null || echo "rosdep update skipped due to network issues")

# ============================================================
# Настройка SSH-сервера
# ============================================================
RUN mkdir -p /var/run/sshd \
    && sed -i 's/#PermitRootLogin prohibit-password/PermitRootLogin yes/' /etc/ssh/sshd_config \
    && sed -i 's/#PasswordAuthentication yes/PasswordAuthentication yes/' /etc/ssh/sshd_config \
    && sed -i 's/#PubkeyAuthentication yes/PubkeyAuthentication yes/' /etc/ssh/sshd_config

# ============================================================
# Создание пользователя robot
# ============================================================
RUN useradd -m -s /bin/bash robot \
    && echo "robot:robot" | chpasswd \
    && usermod -aG sudo robot \
    && echo "robot ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers

# ============================================================
# Создание рабочего пространства
# ============================================================
RUN mkdir -p ${CATKIN_WS}/src

# ============================================================
# Копирование пакета напрямую в src/
# ============================================================
COPY src/air_ground_bringup ${CATKIN_WS}/src/air_ground_bringup/

# ============================================================
# Копирование скриптов установки для справки
# ============================================================
RUN mkdir -p /opt/robot_scripts
COPY scripts /opt/robot_scripts/

# ============================================================
# Установка зависимостей пакета через rosdep (не критично)
# ============================================================
RUN (rosdep install --from-paths ${CATKIN_WS}/src --ignore-src -r -y || true)

# ============================================================
# Сборка рабочего пространства
# ============================================================
RUN /bin/bash -c "source /opt/ros/${ROS_DISTRO}/setup.bash \
    && cd ${CATKIN_WS} \
    && catkin_make -DCATKIN_ENABLE_TESTING=OFF"

# ============================================================
# Настройка автоподгрузки окружения
# ============================================================
RUN echo "source /opt/ros/${ROS_DISTRO}/setup.bash" >> /root/.bashrc \
    && echo "source ${CATKIN_WS}/devel/setup.bash" >> /root/.bashrc \
    && echo "source /opt/ros/${ROS_DISTRO}/setup.bash" >> /home/robot/.bashrc \
    && echo "source ${CATKIN_WS}/devel/setup.bash" >> /home/robot/.bashrc

# ============================================================
# Копирование конфигурационных файлов Docker
# ============================================================
COPY docker/entrypoint.sh /entrypoint.sh
COPY docker/ssh/sshd_config /etc/ssh/sshd_config
RUN chmod +x /entrypoint.sh \
    && chmod 600 /etc/ssh/sshd_config

# ============================================================
# Порты
# ============================================================
EXPOSE 22 11311

# ============================================================
# Точка входа
# ============================================================
ENTRYPOINT ["/entrypoint.sh"]
CMD ["bash"]
