#!/usr/bin/env python3

import rospy
import math
import random
from std_msgs.msg import String, Bool, Empty
from geometry_msgs.msg import Point


class IntruderDetector:
    """
    Симулятор детектора чужих БПЛА для Фазы 1 (MVP).
    
    Назначение:
    - Тестирование FSM drone_controller (переход AIR_PATROL -> INTERCEPT)
    - Эмуляция работы реального детектора БПЛА (появится в Фазе 2)
    - Ручной триггер обнаружения для отладки
    
    Публикует:
    - /intruder/detected (Bool) — флаг обнаружения нарушителя
    - /intruder/position (Point) — координаты нарушителя
    
    Подписывается:
    - /drone/state (String) — текущее состояние дрона
    - /drone/position (Pose) — текущая позиция дрона
    - /intruder_detector/trigger (Empty) — ручной триггер обнаружения
    
    Логика:
    - В автоматическом режиме нарушитель появляется в зоне патрулирования
      с заданной вероятностью, только когда дрон в AIR_PATROL
    - Ручной триггер работает в любом состоянии дрона
    - Нарушитель размещается в случайной точке на радиусе патруля
    """
    
    STATE_AIR_PATROL = 'AIR_PATROL'
    
    def __init__(self):
        rospy.init_node('intruder_detector', anonymous=False)
        
        # Параметры симуляции
        self.simulation_enabled = rospy.get_param('~simulation_enabled', False)
        self.detection_probability = rospy.get_param('~detection_probability', 0.1)
        self.check_interval = rospy.get_param('~check_interval', 2.0)
        self.intruder_radius_min = rospy.get_param('~intruder_radius_min', 30.0)
        self.intruder_radius_max = rospy.get_param('~intruder_radius_max', 70.0)
        self.intruder_altitude_min = rospy.get_param('~intruder_altitude_min', 5.0)
        self.intruder_altitude_max = rospy.get_param('~intruder_altitude_max', 20.0)
        self.center_x = rospy.get_param('~center_x', 0.0)
        self.center_y = rospy.get_param('~center_y', 0.0)
        self.alert_duration = rospy.get_param('~alert_duration', 2.0)
        
        # Состояние
        self.drone_state = 'IDLE'
        self.drone_position = Point(0.0, 0.0, 0.0)
        self.detection_active = False
        self.detection_timer = None
        
        # Publisher'ы
        self.detected_pub = rospy.Publisher(
            '/intruder/detected', Bool, queue_size=10, latch=True
        )
        self.position_pub = rospy.Publisher(
            '/intruder/position', Point, queue_size=10
        )
        
        # Subscriber'ы
        self.state_sub = rospy.Subscriber(
            '/drone/state', String, self.state_callback
        )
        self.position_sub = rospy.Subscriber(
            '/drone/position', Point, self.position_callback
        )
        self.trigger_sub = rospy.Subscriber(
            '/intruder_detector/trigger', Empty, self.trigger_callback
        )
        
        # Таймер автоматической детекции
        if self.simulation_enabled:
            rospy.Timer(
                rospy.Duration(self.check_interval),
                self.auto_detection_callback
            )
            rospy.loginfo(
                'Auto-detection ENABLED: probability=%.2f every %.1fs',
                self.detection_probability, self.check_interval
            )
        else:
            rospy.loginfo(
                'Auto-detection DISABLED. Use /intruder_detector/trigger for manual detection'
            )
            
        rospy.loginfo(
            'Intruder Detector initialized: radius=[%.1f..%.1f] m, altitude=[%.1f..%.1f] m',
            self.intruder_radius_min, self.intruder_radius_max,
            self.intruder_altitude_min, self.intruder_altitude_max
        )
        
    def state_callback(self, msg):
        """Отслеживание состояния дрона."""
        self.drone_state = msg.data
        
    def position_callback(self, msg):
        """Отслеживание позиции дрона (используется как опорная точка)."""
        self.drone_position = msg
        
    def trigger_callback(self, msg):
        """Обработка ручного триггера обнаружения."""
        rospy.loginfo('MANUAL TRIGGER received')
        self.trigger_detection(manual=True)
        
    def auto_detection_callback(self, event):
        """Автоматическая проверка детекции (только в AIR_PATROL)."""
        if self.drone_state != self.STATE_AIR_PATROL:
            return
            
        # Вероятностная генерация обнаружения
        if random.random() < self.detection_probability:
            rospy.loginfo('Auto-detection triggered (random event)')
            self.trigger_detection(manual=False)
            
    def trigger_detection(self, manual=False):
        """
        Генерация события обнаружения нарушителя.
        
        Args:
            manual: True если триггер ручной, False если автоматический
        """
        # Генерация позиции нарушителя
        intruder_position = self.generate_intruder_position()
        
        # Публикация флага обнаружения
        self.detected_pub.publish(Bool(data=True))
        self.position_pub.publish(intruder_position)
        
        source = 'MANUAL' if manual else 'AUTO'
        rospy.logwarn(
            'INTRUDER DETECTED [%s] at (%.1f, %.1f, %.1f)',
            source,
            intruder_position.x, intruder_position.y, intruder_position.z
        )
        
        # Сброс флага через alert_duration секунд
        if self.detection_timer is not None:
            self.detection_timer.shutdown()
            
        self.detection_timer = rospy.Timer(
            rospy.Duration(self.alert_duration),
            self.clear_detection,
            oneshot=True
        )
        
    def generate_intruder_position(self):
        """Генерация позиции нарушителя в зоне патрулирования."""
        # Случайный угол
        angle = random.uniform(0.0, 2.0 * math.pi)
        
        # Случайный радиус в пределах зоны патруля
        radius = random.uniform(
            self.intruder_radius_min,
            self.intruder_radius_max
        )
        
        # Случайная высота
        altitude = random.uniform(
            self.intruder_altitude_min,
            self.intruder_altitude_max
        )
        
        x = self.center_x + radius * math.cos(angle)
        y = self.center_y + radius * math.sin(angle)
        z = altitude
        
        return Point(x, y, z)
        
    def clear_detection(self, event):
        """Сброс флага обнаружения по истечении alert_duration."""
        self.detected_pub.publish(Bool(data=False))
        rospy.loginfo('Intruder detection cleared (alert expired)')
        
    def run(self):
        """Главный цикл узла."""
        rospy.loginfo('Intruder Detector running. Press Ctrl+C to stop')
        rospy.spin()


if __name__ == '__main__':
    try:
        detector = IntruderDetector()
        detector.run()
    except rospy.ROSInterruptException:
        pass
    except Exception as e:
        rospy.logerr('Intruder Detector error: %s', str(e))
