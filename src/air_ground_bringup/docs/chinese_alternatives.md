git add src/air_ground_bringup/docs/mobile_integration.md
git commit -m "docs: add mobile integration and alerting documentation"
git push origin main# Альтернативные компоненты (в том числе китайские) с поддержкой ROS/Linux

## Назначение

В условиях санкций, импортозамещения и логистических ограничений
важно иметь возможность заменить западные компоненты на китайские
аналоги с сопоставимым функционалом и поддержкой ROS/Linux.

Этот документ описывает альтернативы для основных компонентов
робота Air-Ground Security MVP. Все указанные компоненты имеют
открытые драйверы, ROS-пакеты или хорошо документированные API.

## Принцип выбора альтернатив

- Наличие ROS-пакета или готового драйвера под Linux
- Открытый протокол взаимодействия (UART, CAN, Ethernet)
- Доступность на AliExpress / Taobao / китайских складах
- Поддержка сообществом (GitHub, ROS Discourse)
- Наличие документации на английском или китайском

## 1. Вычислитель (мозг робота)

| Оригинал | Альтернатива | Комментарий |
|---|---|---|
| NVIDIA Jetson Nano | Rock Pi 4, Orange Pi 5, Radxa Rock 5B | ARM SBC с Mali GPU, Ubuntu 20.04 |
| Intel NUC | LattePanda Sigma, Minisforum (AMD Ryzen) | x86-совместимые SBC |
| Raspberry Pi 4 | Orange Pi 5 Plus, Banana Pi BPI-M5 | Полная совместимость с Ubuntu |
| BeagleBone | LicheePi, Sipeed MAix | Для задач с малым энергопотреблением |

**ROS-совместимость**: все указанные платы поддерживают Ubuntu 20.04
и ROS Noetic. Для ARM требуется сборка пакетов из исходников
(catkin_make с --platform arm64).

## 2. Полётные контроллеры (для дрона)

| Оригинал | Альтернатива | Комментарий |
|---|---|---|
| Pixhawk 4 (3DR/Holybro) | Cube Orange (CUBEPILOT) | Австралийский, но производится в Китае |
| Pixhawk 6C | Matek H743-Wing, SpeedyBee F405 | Open-source прошивка ArduPilot/PX4 |
| CUAV V5+ | mRo Pixracer, Holybro Kakute H7 | Совместимы с MAVROS |
| DJI A3/N3 | Нет открытой замены | DJI закрытая экосистема |

**ROS-совместимость**: все альтернативы поддерживают MAVLink + MAVROS.
Прошивки ArduPilot и PX4 работают из коробки.

## 3. LIDAR

| Оригинал | Альтернатива | Комментарий |
|---|---|---|
| Velodyne VLP-16 | Livox Mid-360, Leishen C16 | Китайские 3D LIDAR |
| RPLIDAR A2/A3 | Slamtec RPLIDAR S2, YDLIDAR X4 | 2D LIDAR, есть ROS-пакеты |
| Ouster OS1 | Hesai Pandar XT-32 | 3D LIDAR высокого разрешения |
| SICK TiM | Leishen CH32R | Промышленный 2D LIDAR |

**ROS-совместимость**:
- Livox: `livox_ros_driver` (официальный пакет от DJI/Livox)
- YDLIDAR: `ydlidar_ros_driver`
- Leishen: `lslidar_ros` (есть для большинства моделей)
- Slamtec: `rplidar_ros` (стандартный пакет)

## 4. IMU-датчики

| Оригинал | Альтернатива | Комментарий |
|---|---|---|
| XSens MTI-1 | WitMotion WT901, BNO055 (Bosch) | I2C/UART, есть ROS-драйверы |
| VectorNav VN-100 | MPU9250 модули, ICM-42688 | Дешёвые MEMS-IMU |
| ST IMU | HiPNUC CH10x | Китайские промышленные IMU |

**ROS-совместимость**: `imu_filter_madgwick`, `robot_localization`
работают с любым стандартным sensor_msgs/Imu сообщением.

## 5. Камеры

| Оригинал | Альтернатива | Комментарий |
|---|---|---|
| Intel RealSense | Orbbec Astra, Gemini 2 | 3D-камеры глубины |
| FLIR Blackfly | Dahua, Hikvision USB-камеры | Промышленные камеры |
| Logitech C920 | Любые UVC-совместимые камеры | Стандарт V4L2 |
| StereoLabs ZED | Orbbec Femto, MYNT EYE | Стерео-камеры |

**ROS-совместимость**:
- Orbbec: `orbbec_camera` (официальный ROS 1/2 пакет)
- UVC-камеры: `usb_cam`, `v4l2_camera` (уже в зависимостях)

## 6. Контроллеры двигателей

| Оригинал | Альтернатива | Комментарий |
|---|---|---|
| ODrive | Moteus (mjbots), VESC 6 | Open-source контроллеры |
| RoboClaw | TReX motor controller, Cytron MD30C | UART/CAN управление |
| Pololu | Dagu MD49 | Дешёвые драйверы |

**ROS-совместимость**:
- VESC: `vesc` ROS-пакет (CAN/UART)
- Moteus: `moteus_ros` (CAN через fdcanusb)
- ODrive: `odrive_ros` (USB/UART)

## 7. Связь и интерфейсы

| Оригинал | Альтернатива | Комментарий |
|---|---|---|
| PCAN-USB (Peak Systems) | Innomaker USB-CAN, CANable | USB-CAN адаптеры |
| Ublox GPS | Beitian BN-880, Quectel L76 | GPS/ГЛОНАСС модули |
| XBee | Ebyte E32, LoRa RA-02 | Беспроводные модули |
| WiFi Intel | ESP32 в режиме моста | Дешёвый WiFi-мост |

**ROS-сов совместимость**: SocketCAN в Linux работает со всеми
USB-CAN адаптерами. GPS через `nmea_navsat_driver`.

## 8. Аккумуляторы и питание

| Оригинал | Альтернатива | Комментарий |
|---|---|---|
| Turnigy / ZIPP | Tattu, CNHL (China Hobby Line) | LiPo для дронов |
| Samsung / LG 18650 | EVE, BAK, Hithium | Li-ion для наземных роботов |
| Victron BMS | Daly BMS, JBD (Jiabaida) | Smart BMS с UART |

**ROS-совместимость**: Daly BMS имеет UART-протокол, можно написать
свой узел `battery_node` (аналогично существующему).

## 9. Рамы и механика

| Оригинал | Альтернатива | Комментарий |
|---|---|---|
| Tarot, DJI | iFlight, GEPRC, T-Motor | Рамы для дронов |
| Clearpath Husky | RobotShop Rover, китайские платформы | Наземные платформы |
| Pololu шасси | Waveshare, DFRobot шасси | Для малых роботов |

## Стратегия применения в проекте

### Фаза 1 (текущая)
- Используем имеющееся железо (ноутбук ASUS Vivobook)
- Все компоненты симулированы или уже есть в наличии
- Альтернативы рассматриваются на будущее

### Фаза 2 (интеграция железа)
- Замена симуляторов на реальные датчики
- Приоритет: Livox Mid-360 (LIDAR), WitMotion IMU, Orbbec камера
- Вычислитель: Orange Pi 5 Plus вместо ноутбука

### Фаза 3 (полная система)
- Все компоненты — доступные китайские аналоги
- Возможность серийного производства в РФ/СНГ
- Независимость от поставок западных компонентов

## Риски использования китайских компонентов

1. **Качество**: возможен брак, требуется входной контроль
2. **Документация**: часто только на китайском (нужен переводчик)
3. **Прошивки**: иногда закрытые, сложно модифицировать
4. **Поддержка**: сложнее получить официальную техподдержку
5. **Лицензии**: некоторые производители нарушают open-source лицензии

## Меры по снижению рисков

- Заказ образцов для тестирования перед партией
- Участие в сообществах (ROS Discourse, китайские форсы)
- Форк драйверов в собственный репозиторий
- Тестирование на резервных компонентах

## Источники информации

- ROS Index: https://index.ros.org/
- ROS Discourse: https://discourse.ros.org/
- GitHub поиск по тегам: `ros`, `china`, `lidar`, `imu`
- Taobao / AliExpress (поиск по моделям)
- Китайские форумы: https://www.amovlab.com/ (Amov — Livox/Orbbec)
