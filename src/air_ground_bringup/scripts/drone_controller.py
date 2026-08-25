#!/usr/bin/env python3

import rospy
import math
from std_msgs.msg import String, Bool
from geometry_msgs.msg import Pose, Point, PoseArray
from sensor_msgs.msg import BatteryState


class DroneController:
    """
    Конечный автомат управления дроном для контроля воздушного пространства.
    
    Состояния FSM:
    - IDLE: дрон на базе, заряжается
    - TAKEOFF: взлёт на рабочую высоту
    - AIR_PATROL: воздушное патрулирование зоны
    - INTERCEPT: перехват чужого БПЛА
    - LAND: посадка на базу
    """
    
    # Константы состояний
    STATE_IDLE = 'IDLE'
    STATE_TAKEOFF = 'TAKEOFF'
    STATE_AIR_PATROL = 'AIR_PATROL'
    STATE_INTERCEPT = 'INTERCEPT'
    STATE_LAND = 'LAND'
    
    def __init__(self):
        rospy.init_node('drone_controller', anonymous=False)
        
        # Текущее состояние FSM
        self.state = self.STATE_IDLE
        
        # Параметры
        self.target_altitude = rospy.get_param('~target_altitude', 10.0)
        self.intercept_distance = rospy.get_param('~intercept_distance', 2.0)
        self.altitude_tolerance = rospy.get_param('~altitude_tolerance', 0.5)
        self.landing_tolerance = rospy.get_param('~landing_tolerance', 0.1)
        self.critical_battery = rospy.get_param('~critical_battery', 10.0)
        
        # Текущие данные
        self.current_position = Point(0.0, 0.0, 0.0)
        self.intruder_position = Point(0.0, 0.0, 0.0)
        self.intruder_detected = False
        self.battery_level = 100.0
        
        # Publisher'ы
        self.state_pub = rospy.Publisher('/drone/state', String, queue_size=10)
        self.setpoint_pub = rospy.Publisher('/drone/setpoint', Point, queue_size=10)
        
        # Subscriber'ы
        self.command_sub = rospy.Subscriber(
            '/drone/command', String, self.command_callback
        )
        self.intruder_sub = rospy.Subscriber(
            '/intruder/detected', Bool, self.intruder_callback
        )
        self.intruder_pos_sub = rospy.Subscriber(
            '/intruder/position', Point, self.intruder_pos_callback
        )
        self.position_sub = rospy.Subscriber(
            '/drone/position', Pose, self.position_callback
        )
        self.battery_sub = rospy.Subscriber(
            '/battery_state', BatteryState, self.battery_callback
        )
        
        self.rate = rospy.Rate(10)  # 10 Hz
        rospy.loginfo('Drone Controller initialized. State: %s', self.state)
        
    def command_callback(self, msg):
        """Обработка команд управления от пользователя/системы."""
        command = msg.data.strip().lower()
        rospy.loginfo('Received command: "%s" (current state: %s)', command, self.state)
        
        if command == 'takeoff':
            if self.state == self.STATE_IDLE:
                self.transition_to(self.STATE_TAKEOFF)
                setpoint = Point(
                    self.current_position.x,
                    self.current_position.y,
                    self.target_altitude
                )
                self.setpoint_pub.publish(setpoint)
                rospy.loginfo('Taking off to altitude %.1f m', self.target_altitude)
            else:
                rospy.logwarn('Cannot takeoff from state: %s (only from IDLE)', self.state)
                
        elif command == 'land':
            if self.state != self.STATE_LAND and self.state != self.STATE_IDLE:
                self.transition_to(self.STATE_LAND)
                setpoint = Point(
                    self.current_position.x,
                    self.current_position.y,
                    0.0
                )
                self.setpoint_pub.publish(setpoint)
                rospy.loginfo('Landing at current position')
            elif self.state == self.STATE_LAND:
                rospy.logwarn('Already landing')
            else:
                rospy.logwarn('Already landed (IDLE)')
        else:
            rospy.logwarn('Unknown command: "%s". Valid: takeoff, land', command)
            
    def intruder_callback(self, msg):
        """Обработка сигнала об обнаружении чужого БПЛА."""
        self.intruder_detected = msg.data
        
        if msg.data and self.state == self.STATE_AIR_PATROL:
            rospy.logwarn('INTRUDER DETECTED! Transitioning to INTERCEPT')
            self.transition_to(self.STATE_INTERCEPT)
            # Летим к позиции нарушителя
            self.setpoint_pub.publish(self.intruder_position)
            rospy.loginfo(
                'Intercepting target at (%.1f, %.1f, %.1f)',
                self.intruder_position.x,
                self.intruder_position.y,
                self.intruder_position.z
            )
            
    def intruder_pos_callback(self, msg):
        """Обновление позиции нарушителя."""
        self.intruder_position = msg
        
    def position_callback(self, msg):
        """Обновление текущей позиции и проверка переходов FSM."""
        self.current_position = msg.position
        
        # Переход: TAKEOFF -> AIR_PATROL (достигнута целевая высота)
        if self.state == self.STATE_TAKEOFF:
            if self.current_position.z >= self.target_altitude - self.altitude_tolerance:
                rospy.loginfo(
                    'Target altitude reached (%.1f m). Starting AIR_PATROL',
                    self.current_position.z
                )
                self.transition_to(self.STATE_AIR_PATROL)
                
        # Переход: LAND -> IDLE (посадка завершена)
        elif self.state == self.STATE_LAND:
            if self.current_position.z <= self.landing_tolerance:
                rospy.loginfo('Landing complete. Returning to IDLE')
                self.transition_to(self.STATE_IDLE)
                
        # Переход: INTERCEPT -> AIR_PATROL (цель достигнута)
        elif self.state == self.STATE_INTERCEPT:
            distance = self.calculate_distance(
                self.current_position, self.intruder_position
            )
            if distance < self.intercept_distance:
                rospy.loginfo(
                    'Intercept successful (distance: %.2f m). Returning to AIR_PATROL',
                    distance
                )
                self.transition_to(self.STATE_AIR_PATROL)
                
    def battery_callback(self, msg):
        """Мониторинг батареи и аварийная посадка при низком заряде."""
        if hasattr(msg, 'percentage') and msg.percentage is not None:
            self.battery_level = msg.percentage * 100.0
        elif hasattr(msg, 'voltage') and msg.voltage > 0:
            # Приблизительный расчёт для LiPo (пример)
            self.battery_level = min(100.0, (msg.voltage / 16.8) * 100.0)
            
        # Аварийная посадка при критическом заряде
        if (self.battery_level < self.critical_battery and 
            self.state not in [self.STATE_LAND, self.STATE_IDLE]):
            rospy.logerr(
                'CRITICAL: Battery level %.1f%% < %.1f%%. EMERGENCY LANDING!',
                self.battery_level,
                self.critical_battery
            )
            self.transition_to(self.STATE_LAND)
            self.setpoint_pub.publish(Point(
                self.current_position.x,
                self.current_position.y,
                0.0
            ))
            
    def calculate_distance(self, p1, p2):
        """Расчёт евклидова расстояния между двумя точками."""
        return math.sqrt(
            (p1.x - p2.x) ** 2 +
            (p1.y - p2.y) ** 2 +
            (p1.z - p2.z) ** 2
        )
        
    def transition_to(self, new_state):
        """Выполнение перехода FSM с логированием."""
        old_state = self.state
        self.state = new_state
        rospy.loginfo('FSM Transition: %s -> %s', old_state, new_state)
        
    def run(self):
        """Главный цикл узла."""
        while not rospy.is_shutdown():
            # Публикуем текущее состояние
            self.state_pub.publish(String(data=self.state))
            self.rate.sleep()


if __name__ == '__main__':
    try:
        controller = DroneController()
        controller.run()
    except rospy.ROSInterruptException:
        pass
    except Exception as e:
        rospy.logerr('Drone Controller error: %s', str(e))
