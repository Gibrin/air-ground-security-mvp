# Управление дроном — контроль воздушного пространства

## Назначение

Главная функция Фазы 1 — КОНТРОЛЬ ВОЗДУШНОГО ПРОСТРАНСТВА объекта.
Дрон патрулирует воздух, детектирует несанкционированные БПЛА
и выполняет перехват. Управление реализовано как конечный автомат (FSM).

ВАЖНО: контроль воздушного пространства — это ОТДЕЛЬНАЯ функция.
Она НЕ смешивается с контролем периметра и облётом внешнего контура
(см. docs/perimeter.md и docs/patrol.md).

## Архитектура узлов

| Узел | Назначение |
|---|---|
| drone_controller.py | Конечный автомат управления дроном (ядро) |
| drone_simulator.py | Симулятор дрона: публикует /drone/position (Фаза 1) |
| air_patrol_planner.py | Генерация маршрута воздушного патруля |
| intruder_detector.py | Логика обнаружения чужого БПЛА |
| intruder_simulator.py | Симулятор движения чужого БПЛА |

В Фазе 2 drone_simulator.py заменяется реальным драйвером
(MAVROS + PX4), остальные узлы не меняются.

## Конечный автомат (FSM)

Состояния:

- IDLE — дрон на базе, заряжается
- TAKEOFF — взлёт на рабочую высоту
- AIR_PATROL — воздушное патрулирование зоны
- INTERCEPT — перехват чужого БПЛА
- LAND — посадка на базу

Переходы:

- IDLE -> TAKEOFF: команда /drone/command: takeoff
- TAKEOFF -> AIR_PATROL: достигнута целевая высота
- AIR_PATROL -> INTERCEPT: сигнал /intruder/detected = true
- INTERCEPT -> AIR_PATROL: цель достигнута (дистанция < intercept_distance)
- Любое состояние -> LAND: команда /drone/command: land
- LAND -> IDLE: дрон сел (высота ~ 0)
- Любое состояние -> LAND: аварийная посадка при батарее < 10%

Схема:

    IDLE --takeoff--> TAKEOFF --высота--> AIR_PATROL
      ^                                     |   ^
      |                                     |   |
      |                                цель |   | нарушитель
      |                                     v   |
      +--посадка-- LAND <--land-- INTERCEPT ----+

## Топики

| Топик | Тип | Направление | Назначение |
|---|---|---|---|
| /drone/state | std_msgs/String | из контроллера | текущее состояние FSM |
| /drone/position | geometry_msgs/Pose | из симулятора | текущая позиция дрона |
| /drone/command | std_msgs/String | в контроллер | команды takeoff / land |
| /drone/setpoint | geometry_msgs/Point | из контроллера | целевая точка полёта |
| /air_patrol/waypoints | geometry_msgs/PoseArray | из планировщика | маршрут патруля |
| /intruder/detected | std_msgs/Bool | из детектора | флаг обнаружения |
| /intruder/position | geometry_msgs/Point | из симулятора | позиция нарушителя |
| /battery_state | sensor_msgs/BatteryState | из battery_node | заряд батареи |

## Команды управления

Взлёт (запуск патрулирования):

    rostopic pub --once /drone/command std_msgs/String "data: 'takeoff'"

Посадка:

    rostopic pub --once /drone/command std_msgs/String "data: 'land'"

Запуск симуляции вторжения:

    rostopic pub --once /intruder_simulator/command std_msgs/String "data: 'start'"

Остановка симуляции:

    rostopic pub --once /intruder_simulator/command std_msgs/String "data: 'stop'"

Наблюдение за состоянием FSM:

    rostopic echo /drone/state

## Алгоритм перехвата (pursuit guidance)

В состоянии INTERCEPT контроллер непрерывно публикует setpoint
в ТЕКУЩУЮ позицию нарушителя (метод погони). Это позволяет догонять
движущуюся цель, а не лететь в устаревшую точку.

Защита от гонок:

- флаг intruder_pos_received — дрон не летит в (0,0,0),
  пока позиция нарушителя реально не получена
- таймаут перехвата — возврат в AIR_PATROL, если цель потеряна

Успешный перехват: дистанция до цели < intercept_distance (2 м).

## Параметры (rosparam)

| Параметр | Узел | По умолчанию | Описание |
|---|---|---|---|
| target_altitude | drone_controller | 10.0 | рабочая высота (м) |
| intercept_distance | drone_controller | 2.0 | дистанция перехвата (м) |
| critical_battery | drone_controller | 10.0 | аварийная посадка (%) |
| patrol_radius | air_patrol_planner | 50.0 | радиус патруля (м) |
| num_waypoints | air_patrol_planner | 8 | точек в маршруте |
| max_speed | drone_simulator | 5.0 | скорость дрона (м/с) |
| behavior | intruder_simulator | linear | поведение нарушителя |

## Проверенный сценарий (Фаза 1)

Полный цикл FSM проверен на реальной системе:

    IDLE -> TAKEOFF -> AIR_PATROL -> INTERCEPT -> AIR_PATROL

Скриншот визуализации: rviz&rqt.png в корне репозитория.
