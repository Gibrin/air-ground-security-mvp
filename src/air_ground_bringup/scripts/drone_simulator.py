#!/usr/bin/env python3

import rospy
import math
from geometry_msgs.msg import Point, Pose, Quaternion
from visualization_msgs.msg import Marker


class DroneSimulator:
    """
    Симулятор дрона для Фазы 1 (MVP).
    
    Публикует:
    - /drone/position (Pose)   — текущая позиция дрона
    - /drone/marker   (Marker) — визуализация дрона в RViz (зелёная сфера)
    
    Подписывается:
    - /drone/setpoint (Point)  — целевая точка полёта
    
    В Фазе 2 заменяется реальным драйвером дрона (mavros + PX4).
    """
    
    def __init__(self):
        rospy.init_node('drone_simulator', anonymous=False)
        
        # Параметры симуляции
        self.max_speed = rospy.get_param('~max_speed', 5.0)
        self.update_rate = rospy.get_param('~update_rate', 20.0)
        self.position_tolerance = rospy.get_param('~position_tolerance', 0.1)
        self.marker_size = rospy.get_param('~marker_size', 6.0)
        
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
        
        # Publisher'ы
        self.position_pub = rospy.Publisher(
            '/drone/position', Pose, queue_size=10
        )
        self.marker_pub = rospy.Publisher(
            '/drone/marker', Marker, queue_size=10
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
        
    def update_position(self):
        """Плавное движение дрона к целевой точке."""
        dx = self.setpoint.x - self.current_position.x
        dy = self.setpoint.y - self.current_position.y
        dz = self.setpoint.z - self.current_position.z
        
        distance = math.sqrt(dx**2 + dy**2 + dz**2)
        
        if distance < self.position_tolerance:
            return
            
        dt = 1.0 / self.update_rate
        step = min(self.max_speed * dt, distance)
        
        if distance > 0:
            ratio = step / distance
            self.current_position.x += dx * ratio
            self.current_position.y += dy * ratio
            self.current_position.z += dz * ratio
            
    def publish_position(self):
        """Публикация позиции (Pose) и визуализации (Marker)."""
        # --- Pose ---
        pose = Pose()
        pose.position = self.current_position
        pose.orientation = Quaternion(0.0, 0.0, 0.0, 1.0)
        self.position_pub.publish(pose)
        
        # --- Marker (зелёная сфера для RViz) ---
        marker = Marker()
        marker.header.frame_id = 'map'
        marker.header.stamp = rospy.Time.now()
        marker.ns = 'drone'
        marker.id = 0
        marker.type = Marker.SPHERE
        marker.action = Marker.ADD
        marker.pose.position = self.current_position
        marker.pose.orientation = Quaternion(0.0, 0.0, 0.0, 1.0)
        marker.scale.x = self.marker_size
        marker.scale.y = self.marker_size
        marker.scale.z = self.marker_size
        marker.color.r = 0.0
        marker.color.g = 1.0
        marker.color.b = 0.0
        marker.color.a = 1.0
        self.marker_pub.publish(marker)
        
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
