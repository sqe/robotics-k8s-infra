aws_region  = "us-west-2"
environment = "production"

cluster_name   = "robotics-prod"
cluster_domain = "robotics.local"

vpc_cidr = "10.0.0.0/16"

control_plane_count = 3
worker_node_count   = 3

backup_retention_period = 7

# KubeEdge Configuration
kubeedge_replicas = 1

# ROS 2 Configuration
ros2_image      = "osrf/ros:humble-desktop"
ros2_replicas   = 2
ros_domain_id   = "0"

ros2_cpu_request    = "500m"
ros2_memory_request = "512Mi"
ros2_cpu_limit      = "1000m"
ros2_memory_limit   = "1Gi"

ros2_enable_autoscaling = true
ros2_min_replicas       = 1
ros2_max_replicas       = 5
