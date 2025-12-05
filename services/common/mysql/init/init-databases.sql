-- 博物馆管理系统数据库初始化脚本
-- 此脚本用于创建所有必要的数据库

-- 创建认证服务数据库
CREATE DATABASE IF NOT EXISTS `mseek_auth` DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci;

-- 创建用户服务数据库
CREATE DATABASE IF NOT EXISTS `mseek_user` DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci;

-- 创建博物馆信息服务数据库
CREATE DATABASE IF NOT EXISTS `mseek_museum` DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci;

-- 创建文件服务数据库
CREATE DATABASE IF NOT EXISTS `mseek_file` DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci;

-- 创建Nacos配置数据库
CREATE DATABASE IF NOT EXISTS `nacos_config` DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci;

-- 显示创建的数据库
SHOW DATABASES;
