#!/usr/bin/env python3

import rospy
import math
from geometry_msgs.msg import Point, Pose, Quaternion


class DroneSimulator:
    """
    Симулятор дрона для Фазы 1 (MVP).
    
    Назначение:
    - Публикует /drone/position на основе /drone/setpoint
    - Симулирует плавное движение дрона к целевой точке
    - Заменяет реальный дрон / PX4 SITL в Фазе 1
    
    Подписывается:
    - /drone/setpoint (Point) — целевая точка полёта
    
    Публикует:
    - /drone/position (Pose) — текущая позиция дрона
    
    В Фазе 2 этот узел будет заменён на реальный драйвер дрона
    (например, mavros + PX4), который будет публиковать реальную позицию.
    """
    
    def __init__(self):
        rospy.init_node('drone_simulator', anonymous=False)
        
        # Параметры симуляции
        self.max_speed = rospy.get_param('~max_speed', 5.0)
        self.update_rate = rospy.get_param('~update_rate', 20.0)
        self.position_tolerance = rospy.get_param('~position_tolerance', 0.1)
        
        # Начальная позиция (дрон на базе, на земле)
        self.current_position = Point(
            rospy.get_param('~start_x', 0.0),
            rospy.get_param('~start_y', 0.0),
            rospy.get_param('~start_z', 0.0)
        )
        
        # Целевая точка (изначально — текущая позиция)
        self.setpoint = Point(
            self.current_position.x,
            self.current_position.y,
            self.current_position.z
        )
        
        # Publisher текущей позиции дрона
        self.position_pub = rospy.Publisher(
            '/drone/position', Pose, queue_size=10
        )
        
        # Subscriber целевой точки
        self.setpoint_sub = rospy.Subscriber(
            '/drone/setpoint', Point, self.setpoint_callback
        )
        
        self.rate = rospy.Rate(self.update_rate)
        
        rospy.loginfo(
            'Drone Simulator initialized at (%.1f, %.1f, %.1f), speed=%.1f m/s',
            self.current_position.x, self.current_position.y,
            self.current_position.z, self.max_speed
        )
        
    def setpoint_callback(self, msg):
        """Обновление целевой точки полёта."""
        self.setpoint = msg
        rospy.loginfo(
            'New setpoint received: (%.1f, %.1f, %.1f)',
            msg.x, msg.y, msg.z
        )
        
    def update_position(self):
        """Плавное движение дрона к целевой точке."""
        dx = self.setpoint.x - self.current_position.x
        dy = self.setpoint.y - self.current_position.y
        dz = self.setpoint.z - self.current_position.z
        
        distance = math.sqrt(dx**2 + dy**2 + dz**2)
        
        # Если уже на месте — не двигаемся
        if distance < self.position_tolerance:
            return
            
        # Вычисляем шаг движения за один тик
        dt = 1.0 / self.update_rate
        step = min(self.max_speed * dt, distance)
        
        # Двигаемся в направлении цели
        if distance > 0:
            ratio = step / distance
            self.current_position.x += dx * ratio
            self.current_position.y += dy * ratio
            self.current_position.z += dz * ratio
            
    def publish_position(self):
        """Публикация текущей позиции как Pose."""
        pose = Pose()
        pose.position = self.current_position
        # Ориентация: нейтральный кватернион (дрон смотрит вперёд)
        pose.orientation = Quaternion(0.0, 0.0, 0.0, 1.0)
        
        self.position_pub.publish(pose)
        
    def run(self):
        """Главный цикл узла."""
        rospy.loginfo('Drone Simulator running at %.1f Hz', self.update_rate)
        
        while not rospy.is_shutdown():
            self.update_position()
            self.publish_position()
            self.rate.sleep()


if __name__ == '__main__':
    try:
        simulator = DroneSimulator()
        simulator.run()
    except rospy.ROSInterruptException:
        pass
    except Exception as e:
        rospy.logerr('Drone Simulator error: %s', str(e))
