cmake_minimum_required(VERSION 3.0.2)
project(air_ground_bringup)

## ============================================================
## Поиск зависимостей через catkin
## ============================================================
find_package(catkin REQUIRED COMPONENTS
  rospy
  roslaunch
  std_msgs
  geometry_msgs
  sensor_msgs
  nav_msgs
  diagnostic_msgs
  tf2
  tf2_ros
  joy
  mavros
)

## ============================================================
## Объявление пакета (без C++ библиотек, только Python-узлы)
## ============================================================
catkin_package()

## ============================================================
## Установка Python-узлов
## ============================================================
## Все исполняемые скрипты из папки scripts/ будут установлены
## в ${CATKIN_PACKAGE_BIN_DESTINATION} и станут доступны через
## 'rosrun air_ground_bringup <имя_узла>'
## ============================================================
catkin_install_python(PROGRAMS
  scripts/battery_node.py
  scripts/pir_simulator_node.py
  scripts/drone_controller.py
  scripts/drone_simulator.py
  scripts/air_patrol_planner.py
  scripts/intruder_detector.py
  scripts/intruder_simulator.py
  scripts/telegram_alert_node.py
  DESTINATION ${CATKIN_PACKAGE_BIN_DESTINATION}
)

## ============================================================
## Установка launch-файлов
## ============================================================
## После установки доступны через:
##   roslaunch air_ground_bringup system.launch
## ============================================================
install(DIRECTORY launch/
  DESTINATION ${CATKIN_PACKAGE_SHARE_DESTINATION}/launch
  PATTERN "*.launch"
)

## ============================================================
## Установка конфигурационных файлов (для rviz)
## ============================================================
## После установки доступны через:
##   $(find air_ground_bringup)/config/default.rviz
## ============================================================
install(DIRECTORY config/
  DESTINATION ${CATKIN_PACKAGE_SHARE_DESTINATION}/config
)

## ============================================================
## Установка документации (опционально)
## ============================================================
## Документация будет доступна в установленном пакете
## ============================================================
install(DIRECTORY docs/
  DESTINATION ${CATKIN_PACKAGE_SHARE_DESTINATION}/docs
  OPTIONAL
)

## ============================================================
## Установка дополнительных файлов (udev-правила, скрипты)
## ============================================================
## Если в будущем появятся дополнительные файлы конфигурации,
## добавьте их сюда
## ============================================================

## ============================================================
## Тесты (опционально, для будущей фазы)
## ============================================================
## Если будут добавлены тесты, раскомментируйте:
## if(CATKIN_ENABLE_TESTING)
##   find_package(rostest REQUIRED)
##   add_rostest(test/test_system.test)
## endif()
