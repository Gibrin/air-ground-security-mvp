cat > README.md << 'EOF'
# 🛡️ Air-Ground Security System — MVP

Гибридное эшелонированное решение контроля земли и воздуха для охраны гражданских объектов (склады, парковки, коттеджные посёлки).

**Стек:** Ubuntu 20.04 LTS · ROS 1 Noetic · Docker · Git · Bash

---

## 📋 Описание

Система объединяет стационарные наземные датчики и автономный дрон:

- **Наземный эшелон**: камеры 360°, PIR-датчики движения, RF-детектор дронов
- **Воздушный эшелон**: дрон с Pixhawk, обзорной камерой, LiDAR
- **Центр управления**: Ubuntu + ROS, RViz, RQT

### Сценарий работы (MVP)

1. Дрон на базе заряжается
2. PIR-датчик или камера фиксирует тревогу → событие /pir/status
3. Дрон автоматически вылетает к точке тревоги
4. Оператор наблюдает видео в RViz и может перехватить управление
5. При низком заряде — возврат на базу

---

## 🧩 Состав системы (проектно)

| Устройство | Интерфейс | Linux-интерфейс | ROS-пакет |
|---|---|---|---|
| Pixhawk (FC) | USB/UART | /dev/ttyACM0 | mavros |
| GPS u-blox M9N | UART (через FC) | — | mavros |
| RPLidar A1 | USB | /dev/ttyUSB0 | rplidar_ros |
| Обзорная камера | USB | /dev/video0 | usb_cam |
| PIR-датчики | GPIO → MCU | — | свой узел (симуляция) |
| Аккумулятор (BMS) | I2C / sysfs | /sys/class/power_supply/BAT0 | свой узел |
| RTL-SDR v3 | USB | /dev/bus/usb/... | gr-osmosdr (опц.) |

---

## 🚀 Быстрый старт

Клонирование:

    git clone git@github.com:Gibrin/air-ground-security-mvp.git
    cd air-ground-security-mvp

Установка зависимостей:

    ./scripts/00_install_base.sh
    ./scripts/01_install_ros_packages.sh
    ./scripts/02_setup_ssh.sh
    ./scripts/03_setup_devices.sh

Сборка и запуск:

    ./scripts/04_build_workspace.sh
    source devel/setup.bash
    roslaunch air_ground_bringup system.launch rviz:=true

---

## 🐳 Docker

Сборка и запуск:

    docker build -t air-ground-security:mvp -f docker/Dockerfile .
    docker run -it --rm --privileged -v /dev:/dev -p 2222:2222 air-ground-security:mvp
    ssh -p 2222 robot@localhost

---

## 📊 Топики ROS

| Топик | Тип | Источник |
|---|---|---|
| /battery_state | sensor_msgs/BatteryState | sysfs BAT0 |
| /camera/image_raw | sensor_msgs/Image | /dev/video0 |
| /pir/status | std_msgs/Bool | симулятор |
| /pir/location | geometry_msgs/Point | симулятор |

---

## 🔄 Отличия ROS 1 ↔ ROS 2

| Элемент | ROS 1 Noetic (этот проект) | ROS 2 Humble |
|---|---|---|
| ОС | Ubuntu 20.04 | Ubuntu 22.04 |
| Сборка | catkin_make | colcon build |
| Source | devel/setup.bash | install/setup.bash |
| Launch | XML | Python |
| CLI | rostopic, roslaunch | ros2 topic, ros2 launch |
| Python | rospy | rclpy |
| Поддержка | EOL май 2025 | до 2027 |

---

## 📜 Лицензия

MIT
EOF
