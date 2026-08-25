#!/usr/bin/env python3

import rospy
import math
from std_msgs.msg import String, Bool, Empty
from geometry_msgs.msg import Point


class IntruderSimulator:
    """
    Симулятор движения чужого БПЛА для Фазы 1 (MVP).
    
    Назначение:
    - Визуализация движущегося нарушителя в rviz
    - Тестирование алгоритма перехвата (дрон догоняет движущуюся цель)
    - Различные сценарии вторжения: линейный, круговой, зависание
    
    Публикует:
    - /intruder/position (Point) — текущая позиция чужого БПЛА
    - /intruder/detected (Bool) — флаг обнаружения (при авто-триггере)
    
    Подписывается:
    - /intruder_simulator/command (String) — команды: start, stop
    
    Поведение (параметр ~behavior):
    - linear: линейный полёт от стартовой к целевой точке
    - circle: круговое движение вокруг центра зоны патруля
    - hover: зависание в одной точке
    """
    
    BEHAVIOR_LINEAR = 'linear'
    BEHAVIOR_CIRCLE = 'circle'
    BEHAVIOR_HOVER = 'hover'
    
    def __init__(self):
        rospy.init_node('intruder_simulator', anonymous=False)
        
        # Параметры поведения
        self.behavior = rospy.get_param('~behavior', self.BEHAVIOR_LINEAR)
        self.speed = rospy.get_param('~speed', 5.0)
        self.update_rate = rospy.get_param('~update_rate', 10.0)
        
        # Начальная и целевая позиции (для линейного поведения)
        self.start_pos = Point(
            rospy.get_param('~start_x', 100.0),
            rospy.get_param('~start_y', 0.0),
            rospy.get_param('~start_z', 15.0)
        )
        self.target_pos = Point(
            rospy.get_param('~target_x', 0.0),
            rospy.get_param('~target_y', 0.0),
            rospy.get_param('~target_z', 15.0)
        )
        
        # Параметры кругового поведения
        self.circle_radius = rospy.get_param('~circle_radius', 40.0)
        self.circle_altitude = rospy.get_param('~circle_altitude', 15.0)
        self.center_x = rospy.get_param('~center_x', 0.0)
        self.center_y = rospy.get_param('~center_y', 0.0)
        
        # Авто-триггер детектора
        self.auto_trigger = rospy.get_param('~auto_trigger_detector', True)
        
        # Состояние симуляции
        self.active = False
        self.current_pos = Point(0.0, 0.0, 0.0)
        self.circle_angle = 0.0
        self.linear_progress = 0.0
        
        # Publisher'ы
        self.position_pub = rospy.Publisher(
            '/intruder/position', Point, queue_size=10
        )
        self.detected_pub = rospy.Publisher(
            '/intruder/detected', Bool, queue_size=10, latch=True
        )
        self.trigger_pub = rospy.Publisher(
            '/intruder_detector/trigger', Empty, queue_size=1
        )
        
        # Subscriber'ы
        self.command_sub = rospy.Subscriber(
            '/intruder_simulator/command', String, self.command_callback
        )
        
        self.rate = rospy.Rate(self.update_rate)
        
        rospy.loginfo(
            'Intruder Simulator initialized: behavior=%s, speed=%.1f m/s',
            self.behavior, self.speed
        )
        
    def command_callback(self, msg):
        """Обработка команд управления симуляцией."""
        command = msg.data.strip().lower()
        rospy.loginfo('Received command: %s', command)
        
        if command == 'start':
            self.start_simulation()
        elif command == 'stop':
            self.stop_simulation()
        else:
            rospy.logwarn('Unknown command: %s. Valid: start, stop', command)
            
    def start_simulation(self):
        """Запуск симуляции вторжения."""
        if self.active:
            rospy.logwarn('Simulation already active')
            return
            
        self.active = True
        self.current_pos = Point(
            self.start_pos.x, self.start_pos.y, self.start_pos.z
        )
        self.circle_angle = 0.0
        self.linear_progress = 0.0
        
        rospy.logwarn(
            'INTRUDER SIMULATION STARTED at (%.1f, %.1f, %.1f)',
            self.current_pos.x, self.current_pos.y, self.current_pos.z
        )
        
        # Публикуем флаг обнаружения
        self.detected_pub.publish(Bool(data=True))
        
        # Триггерим детектор если включено
        if self.auto_trigger:
            rospy.sleep(0.1)
            self.trigger_pub.publish(Empty())
            rospy.loginfo('Auto-triggered intruder detector')
            
    def stop_simulation(self):
        """Остановка симуляции."""
        if not self.active:
            rospy.logwarn('Simulation not active')
            return
            
        self.active = False
        self.detected_pub.publish(Bool(data=False))
        rospy.loginfo('INTRUDER SIMULATION STOPPED')
        
    def update_position(self):
        """Обновление позиции нарушителя в зависимости от поведения."""
        if not self.active:
            return
            
        dt = 1.0 / self.update_rate
        
        if self.behavior == self.BEHAVIOR_LINEAR:
            self.update_linear(dt)
        elif self.behavior == self.BEHAVIOR_CIRCLE:
            self.update_circle(dt)
        elif self.behavior == self.BEHAVIOR_HOVER:
            pass  # Позиция не меняется
        else:
            rospy.logwarn('Unknown behavior: %s', self.behavior)
            
    def update_linear(self, dt):
        """Линейное движение от стартовой к целевой точке."""
        dx = self.target_pos.x - self.start_pos.x
        dy = self.target_pos.y - self.start_pos.y
        dz = self.target_pos.z - self.start_pos.z
        
        total_distance = math.sqrt(dx**2 + dy**2 + dz**2)
        if total_distance < 0.01:
            rospy.loginfo('Intruder reached target. Stopping simulation')
            self.stop_simulation()
            return
            
        step = self.speed * dt
        self.linear_progress += step
        
        if self.linear_progress >= total_distance:
            self.current_pos = Point(
                self.target_pos.x, self.target_pos.y, self.target_pos.z
            )
            rospy.loginfo('Intruder reached target position')
        else:
            t = self.linear_progress / total_distance
            self.current_pos = Point(
                self.start_pos.x + dx * t,
                self.start_pos.y + dy * t,
                self.start_pos.z + dz * t
            )
            
    def update_circle(self, dt):
        """Круговое движение вокруг центра зоны патруля."""
        angular_speed = self.speed / self.circle_radius
        self.circle_angle += angular_speed * dt
        
        self.current_pos = Point(
            self.center_x + self.circle_radius * math.cos(self.circle_angle),
            self.center_y + self.circle_radius * math.sin(self.circle_angle),
            self.circle_altitude
        )
        
    def run(self):
        """Главный цикл узла."""
        rospy.loginfo(
            'Intruder Simulator running. '
            'Use /intruder_simulator/command to control'
        )
        
        while not rospy.is_shutdown():
            self.update_position()
            
            if self.active:
                self.position_pub.publish(self.current_pos)
                
            self.rate.sleep()


if __name__ == '__main__':
    try:
        simulator = IntruderSimulator()
        simulator.run()
    except rospy.ROSInterruptException:
        pass
    except Exception as e:
        rospy.logerr('Intruder Simulator error: %s', str(e))
