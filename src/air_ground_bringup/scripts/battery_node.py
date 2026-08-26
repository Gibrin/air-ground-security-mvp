#!/usr/bin/env python3

import rospy
import os
from sensor_msgs.msg import BatteryState
from std_msgs.msg import String


class BatteryNode:
    """
    Узел мониторинга батареи ноутбука для проекта Air-Ground Security MVP.
    
    Читает данные из /sys/class/power_supply/BAT0/ и публикует
    в топик /battery_state (sensor_msgs/BatteryState).
    
    Это РЕАЛЬНОЕ устройство (встроенная батарея ноутбука),
    используемое для выполнения требования курсовой:
    "Подключить и проверить работу одного из датчиков".
    
    Публикует:
    - /battery_state (sensor_msgs/BatteryState) — состояние батареи
    - /battery_state_string (std_msgs/String) — человекочитаемый статус
    
    Параметры:
    - ~battery_path: путь к sysfs батареи (по умолчанию /sys/class/power_supply/BAT0)
    - ~publish_rate: частота публикации (Гц, по умолчанию 1.0)
    - ~critical_level: критический уровень заряда (%, по умолчанию 10.0)
    - ~warning_level: уровень предупреждения (%, по умолчанию 25.0)
    """
    
    # Константы статусов батареи (из sensor_msgs/BatteryState)
    STATUS_UNKNOWN = 0
    STATUS_CHARGING = 1
    STATUS_DISCHARGING = 2
    STATUS_NOT_CHARGING = 3
    STATUS_FULL = 4
    
    # Соответствие строк из sysfs константам
    STATUS_MAP = {
        'Unknown': STATUS_UNKNOWN,
        'Charging': STATUS_CHARGING,
        'Discharging': STATUS_DISCHARGING,
        'Not charging': STATUS_NOT_CHARGING,
        'Full': STATUS_FULL,
    }
    
    def __init__(self):
        rospy.init_node('battery_node', anonymous=False)
        
        # Параметры
        self.battery_path = rospy.get_param(
            '~battery_path', '/sys/class/power_supply/BAT0'
        )
        self.publish_rate = rospy.get_param('~publish_rate', 1.0)
        self.critical_level = rospy.get_param('~critical_level', 10.0)
        self.warning_level = rospy.get_param('~warning_level', 25.0)
        
        # Поиск батареи, если стандартный путь не работает
        if not os.path.exists(self.battery_path):
            rospy.logwarn(
                'Батарея не найдена по пути %s, ищу альтернативы...',
                self.battery_path
            )
            self.battery_path = self.find_battery()
            
        if self.battery_path is None:
            rospy.logerr('Батарея не найдена! Узел будет публиковать пустые данные')
            self.battery_found = False
        else:
            self.battery_found = True
            rospy.loginfo('Батарея найдена: %s', self.battery_path)
            
        # Publisher'ы
        self.battery_pub = rospy.Publisher(
            '/battery_state', BatteryState, queue_size=10
        )
        self.battery_string_pub = rospy.Publisher(
            '/battery_state_string', String, queue_size=10
        )
        
        # Предыдущий статус для логирования изменений
        self.last_percentage = None
        self.last_status = None
        
        self.rate = rospy.Rate(self.publish_rate)
        
        rospy.loginfo(
            'Battery Node initialized: rate=%.1f Hz, critical=%.1f%%, warning=%.1f%%',
            self.publish_rate, self.critical_level, self.warning_level
        )
        
    def find_battery(self):
        """Поиск батареи в /sys/class/power_supply/."""
        power_supply_path = '/sys/class/power_supply'
        
        if not os.path.exists(power_supply_path):
            return None
            
        for entry in os.listdir(power_supply_path):
            if entry.startswith('BAT'):
                candidate = os.path.join(power_supply_path, entry)
                if os.path.isdir(candidate):
                    rospy.loginfo('Найдена батарея: %s', candidate)
                    return candidate
                    
        return None
        
    def read_sysfs_value(self, filename, default=None):
        """Чтение значения из файла sysfs."""
        filepath = os.path.join(self.battery_path, filename)
        try:
            with open(filepath, 'r') as f:
                value = f.read().strip()
                return value
        except (IOError, OSError):
            return default
            
    def read_sysfs_float(self, filename, default=0.0):
        """Чтение числового значения из файла sysfs."""
        value_str = self.read_sysfs_value(filename, None)
        if value_str is None:
            return default
        try:
            return float(value_str)
        except (ValueError, TypeError):
            return default
            
    def read_battery_state(self):
        """Чтение полного состояния батареи из sysfs."""
        state = BatteryState()
        state.header.stamp = rospy.Time.now()
        
        if not self.battery_found:
            # Батарея не найдена — публикуем пустые данные
            state.present = False
            state.power_supply_status = self.STATUS_UNKNOWN
            return state
            
        # Наличие батареи
        present_str = self.read_sysfs_value('present', '1')
        state.present = (present_str == '1')
        
        if not state.present:
            state.power_supply_status = self.STATUS_UNKNOWN
            return state
            
        # Статус зарядки
        status_str = self.read_sysfs_value('status', 'Unknown')
        state.power_supply_status = self.STATUS_MAP.get(
            status_str, self.STATUS_UNKNOWN
        )
        
        # Процент заряда (0-100 в sysfs -> 0.0-1.0 в BatteryState)
        capacity = self.read_sysfs_float('capacity', 0.0)
        state.percentage = capacity / 100.0
        
        # Напряжение (микровольты -> вольты)
        voltage_uv = self.read_sysfs_float('voltage_now', 0.0)
        state.voltage = voltage_uv / 1000000.0
        
        # Ток (микроамперы -> амперы)
        current_ua = self.read_sysfs_float('current_now', 0.0)
        state.current = current_ua / 1000000.0
        
        # Ёмкость (микроампер-часы -> ампер-часы)
        charge_now = self.read_sysfs_float('charge_now', 0.0)
        charge_full = self.read_sysfs_float('charge_full', 0.0)
        charge_full_design = self.read_sysfs_float('charge_full_design', 0.0)
        
        state.charge = charge_now / 1000000.0
        state.capacity = charge_full / 1000000.0
        state.design_capacity = charge_full_design / 1000000.0
        
        # Технология батареи
        technology = self.read_sysfs_value('technology', 'Unknown')
        if 'Li-ion' in technology:
            state.power_supply_technology = BatteryState.POWER_SUPPLY_TECHNOLOGY_LION
        elif 'Li-poly' in technology:
            state.power_supply_technology = BatteryState.POWER_SUPPLY_TECHNOLOGY_LIPO
        elif 'NiMH' in technology:
            state.power_supply_technology = BatteryState.POWER_SUPPLY_TECHNOLOGY_NIMH
        else:
            state.power_supply_technology = BatteryState.POWER_SUPPLY_TECHNOLOGY_UNKNOWN
            
        # Здоровье батареи (предполагаем хорошее)
        state.power_supply_health = BatteryState.POWER_SUPPLY_HEALTH_GOOD
        
        # Проверка критического уровня
        if capacity <= self.critical_level:
            rospy.logwarn_throttle(
                10,
                'CRITICAL: Battery level %.1f%% <= %.1f%%',
                capacity, self.critical_level
            )
        elif capacity <= self.warning_level:
            rospy.logwarn_throttle(
                30,
                'WARNING: Battery level %.1f%% <= %.1f%%',
                capacity, self.warning_level
            )
            
        # Логирование изменений статуса
        if self.last_status != status_str:
            rospy.loginfo(
                'Battery status changed: %s -> %s (%.1f%%)',
                self.last_status or 'UNKNOWN', status_str, capacity
            )
            self.last_status = status_str
            
        if self.last_percentage is not None:
            if abs(capacity - self.last_percentage) >= 1.0:
                rospy.loginfo('Battery level: %.1f%% (%s)', capacity, status_str)
        self.last_percentage = capacity
        
        return state
        
    def format_battery_string(self, state):
        """Форматирование человекочитаемой строки состояния."""
        if not state.present:
            return "Battery: NOT PRESENT"
            
        status_names = {
            self.STATUS_UNKNOWN: 'Unknown',
            self.STATUS_CHARGING: 'Charging',
            self.STATUS_DISCHARGING: 'Discharging',
            self.STATUS_NOT_CHARGING: 'Not charging',
            self.STATUS_FULL: 'Full',
        }
        
        status = status_names.get(state.power_supply_status, 'Unknown')
        percentage = state.percentage * 100.0
        
        return "Battery: {:.1f}% | Status: {} | Voltage: {:.2f}V".format(
            percentage, status, state.voltage
        )
        
    def run(self):
        """Главный цикл узла."""
        rospy.loginfo('Battery Node running at %.1f Hz', self.publish_rate)
        
        while not rospy.is_shutdown():
            state = self.read_battery_state()
            
            # Публикация основного топика
            self.battery_pub.publish(state)
            
            # Публикация человекочитаемой строки
            state_string = self.format_battery_string(state)
            self.battery_string_pub.publish(String(data=state_string))
            
            self.rate.sleep()


if __name__ == '__main__':
    try:
        node = BatteryNode()
        node.run()
    except rospy.ROSInterruptException:
        pass
    except Exception as e:
        rospy.logerr('Battery Node error: %s', str(e))
