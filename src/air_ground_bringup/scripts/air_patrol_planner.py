#!/usr/bin/env python3

import rospy
import math
from std_msgs.msg import String
from geometry_msgs.msg import Point, Pose, PoseArray, Quaternion


class AirPatrolPlanner:
    """
    Планировщик маршрута воздушного патрулирования.
    
    Генерирует круговой маршрут из N точек на заданной высоте
    и последовательно отправляет drone_controller целевые точки (setpoint),
    когда дрон находится в состоянии AIR_PATROL.
    
    Публикует:
    - /air_patrol/waypoints (PoseArray) — полный маршрут патруля
    - /drone/setpoint (Point) — текущая целевая точка для дрона
    
    Подписывается:
    - /drone/state (String) — текущее состояние FSM дрона
    - /drone/position (Pose) — текущая позиция дрона
    """
    
    STATE_AIR_PATROL = 'AIR_PATROL'
    
    def __init__(self):
        rospy.init_node('air_patrol_planner', anonymous=False)
        
        # Параметры патрулирования
        self.patrol_radius = rospy.get_param('~patrol_radius', 50.0)
        self.patrol_altitude = rospy.get_param('~patrol_altitude', 10.0)
        self.num_waypoints = rospy.get_param('~num_waypoints', 8)
        self.waypoint_tolerance = rospy.get_param('~waypoint_tolerance', 3.0)
        self.center_x = rospy.get_param('~center_x', 0.0)
        self.center_y = rospy.get_param('~center_y', 0.0)
        
        # Состояние
        self.drone_state = 'IDLE'
        self.current_position = Point(0.0, 0.0, 0.0)
        self.current_waypoint_index = 0
        self.waypoints = []
        self.patrol_active = False
        
        # Генерация маршрута
        self.generate_patrol_route()
        
        # Publisher'ы
        self.waypoints_pub = rospy.Publisher(
            '/air_patrol/waypoints', PoseArray, queue_size=1, latch=True
        )
        self.setpoint_pub = rospy.Publisher(
            '/drone/setpoint', Point, queue_size=10
        )
        
        # Subscriber'ы
        self.state_sub = rospy.Subscriber(
            '/drone/state', String, self.state_callback
        )
        self.position_sub = rospy.Subscriber(
            '/drone/position', Pose, self.position_callback
        )
        
        self.rate = rospy.Rate(5)  # 5 Hz
        rospy.loginfo(
            'Air Patrol Planner initialized: radius=%.1f m, altitude=%.1f m, waypoints=%d',
            self.patrol_radius, self.patrol_altitude, self.num_waypoints
        )
        
    def generate_patrol_route(self):
        """Генерация кругового маршрута патрулирования."""
        self.waypoints = []
        angle_step = 2.0 * math.pi / self.num_waypoints
        
        for i in range(self.num_waypoints):
            angle = i * angle_step
            x = self.center_x + self.patrol_radius * math.cos(angle)
            y = self.center_y + self.patrol_radius * math.sin(angle)
            z = self.patrol_altitude
            self.waypoints.append(Point(x, y, z))
            
        rospy.loginfo(
            'Patrol route generated: %d waypoints in a circle (radius=%.1f m)',
            len(self.waypoints), self.patrol_radius
        )
        
    def publish_waypoints(self):
        """Публикация полного маршрута патруля как PoseArray."""
        pose_array = PoseArray()
        pose_array.header.frame_id = 'map'
        pose_array.header.stamp = rospy.Time.now()
        
        for wp in self.waypoints:
            pose = Pose()
            pose.position = wp
            pose.orientation = Quaternion(0.0, 0.0, 0.0, 1.0)
            pose_array.poses.append(pose)
            
        self.waypoints_pub.publish(pose_array)
        rospy.loginfo('Published patrol route (%d waypoints)', len(self.waypoints))
        
    def state_callback(self, msg):
        """Обработка изменения состояния дрона."""
        old_state = self.drone_state
        self.drone_state = msg.data
        
        if old_state != self.drone_state:
            rospy.loginfo(
                'Air Patrol Planner: drone state changed %s -> %s',
                old_state, self.drone_state
            )
            
        if self.drone_state == self.STATE_AIR_PATROL and not self.patrol_active:
            # Активация патрулирования
            self.patrol_active = True
            self.current_waypoint_index = 0
            self.publish_waypoints()
            rospy.loginfo('Air patrol ACTIVATED. Starting from waypoint 0')
            self.send_current_waypoint()
            
        elif self.drone_state != self.STATE_AIR_PATROL and self.patrol_active:
            # Деактивация патрулирования
            self.patrol_active = False
            rospy.loginfo('Air patrol DEACTIVATED (drone state: %s)', self.drone_state)
            
    def position_callback(self, msg):
        """Обновление позиции дрона и проверка достижения waypoint."""
        self.current_position = msg.position
        
        if not self.patrol_active:
            return
            
        if self.drone_state != self.STATE_AIR_PATROL:
            return
            
        # Проверка достижения текущей точки маршрута
        current_wp = self.waypoints[self.current_waypoint_index]
        distance = math.sqrt(
            (self.current_position.x - current_wp.x) ** 2 +
            (self.current_position.y - current_wp.y) ** 2 +
            (self.current_position.z - current_wp.z) ** 2
        )
        
        if distance < self.waypoint_tolerance:
            # Переход к следующей точке
            self.current_waypoint_index = (self.current_waypoint_index + 1) % len(self.waypoints)
            rospy.loginfo(
                'Waypoint %d reached (dist=%.2f m). Next: waypoint %d',
                (self.current_waypoint_index - 1) % len(self.waypoints),
                distance,
                self.current_waypoint_index
            )
            self.send_current_waypoint()
            
    def send_current_waypoint(self):
        """Отправка текущей целевой точки в drone_controller."""
        wp = self.waypoints[self.current_waypoint_index]
        self.setpoint_pub.publish(wp)
        rospy.loginfo(
            'Sent setpoint: (%.1f, %.1f, %.1f) [waypoint %d/%d]',
            wp.x, wp.y, wp.z,
            self.current_waypoint_index + 1, len(self.waypoints)
        )
        
    def run(self):
        """Главный цикл узла."""
        while not rospy.is_shutdown():
            self.rate.sleep()


if __name__ == '__main__':
    try:
        planner = AirPatrolPlanner()
        planner.run()
    except rospy.ROSInterruptException:
        pass
    except Exception as e:
        rospy.logerr('Air Patrol Planner error: %s', str(e))
