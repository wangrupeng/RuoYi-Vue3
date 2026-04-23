-- ----------------------------
-- 机器人模块菜单 SQL
-- ----------------------------

-- 查询最大的菜单ID，用于设置新菜单的ID
-- 假设当前最大菜单ID为2000，请根据实际情况调整

-- ----------------------------
-- 1. 机器人目录（一级菜单）
-- ----------------------------
INSERT INTO `sys_menu` (`menu_id`, `menu_name`, `parent_id`, `order_num`, `path`, `component`, `query`, `route_name`, `is_frame`, `is_cache`, `menu_type`, `visible`, `status`, `perms`, `icon`, `create_by`, `create_time`, `update_by`, `update_time`, `remark`)
VALUES (2000, '机器人', 0, 10, 'robot', NULL, '', '', 1, 0, 'M', '0', '0', '', 'tree', 'admin', NOW(), '', NULL, '机器人模块目录');

-- ----------------------------
-- 2. 柱体模型菜单（二级菜单）
-- ----------------------------
INSERT INTO `sys_menu` (`menu_id`, `menu_name`, `parent_id`, `order_num`, `path`, `component`, `query`, `route_name`, `is_frame`, `is_cache`, `menu_type`, `visible`, `status`, `perms`, `icon`, `create_by`, `create_time`, `update_by`, `update_time`, `remark`)
VALUES (2001, '柱体模型', 2000, 1, 'cylinder', 'robot/cylinder', '', 'CylinderModel', 1, 0, 'C', '0', '0', 'robot:cylinder:list', 'cylinder', 'admin', NOW(), '', NULL, '柱体模型页面');

-- ----------------------------
-- 3. 墙面模型菜单（二级菜单）
-- ----------------------------
INSERT INTO `sys_menu` (`menu_id`, `menu_name`, `parent_id`, `order_num`, `path`, `component`, `query`, `route_name`, `is_frame`, `is_cache`, `menu_type`, `visible`, `status`, `perms`, `icon`, `create_by`, `create_time`, `update_by`, `update_time`, `remark`)
VALUES (2002, '墙面模型', 2000, 2, 'wall', 'robot/wall', '', 'WallModel', 1, 0, 'C', '0', '0', 'robot:wall:list', 'wall', 'admin', NOW(), '', NULL, '墙面模型页面');

-- ----------------------------
-- 4. 柱体模型按钮权限（新增）
-- ----------------------------
INSERT INTO `sys_menu` (`menu_id`, `menu_name`, `parent_id`, `order_num`, `path`, `component`, `query`, `route_name`, `is_frame`, `is_cache`, `menu_type`, `visible`, `status`, `perms`, `icon`, `create_by`, `create_time`, `update_by`, `update_time`, `remark`)
VALUES (2003, '柱体模型查询', 2001, 1, '#', '', '', '', 1, 0, 'F', '0', '0', 'robot:cylinder:query', '#', 'admin', NOW(), '', NULL, '');

INSERT INTO `sys_menu` (`menu_id`, `menu_name`, `parent_id`, `order_num`, `path`, `component`, `query`, `route_name`, `is_frame`, `is_cache`, `menu_type`, `visible`, `status`, `perms`, `icon`, `create_by`, `create_time`, `update_by`, `update_time`, `remark`)
VALUES (2004, '柱体模型导出', 2001, 2, '#', '', '', '', 1, 0, 'F', '0', '0', 'robot:cylinder:export', '#', 'admin', NOW(), '', NULL, '');

-- ----------------------------
-- 5. 墙面模型按钮权限（新增）
-- ----------------------------
INSERT INTO `sys_menu` (`menu_id`, `menu_name`, `parent_id`, `order_num`, `path`, `component`, `query`, `route_name`, `is_frame`, `is_cache`, `menu_type`, `visible`, `status`, `perms`, `icon`, `create_by`, `create_time`, `update_by`, `update_time`, `remark`)
VALUES (2005, '墙面模型查询', 2002, 1, '#', '', '', '', 1, 0, 'F', '0', '0', 'robot:wall:query', '#', 'admin', NOW(), '', NULL, '');

INSERT INTO `sys_menu` (`menu_id`, `menu_name`, `parent_id`, `order_num`, `path`, `component`, `query`, `route_name`, `is_frame`, `is_cache`, `menu_type`, `visible`, `status`, `perms`, `icon`, `create_by`, `create_time`, `update_by`, `update_time`, `remark`)
VALUES (2006, '墙面模型导出', 2002, 2, '#', '', '', '', 1, 0, 'F', '0', '0', 'robot:wall:export', '#', 'admin', NOW(), '', NULL, '');

-- ----------------------------
-- 字段说明：
-- menu_id: 菜单ID（唯一标识）
-- menu_name: 菜单名称
-- parent_id: 父菜单ID（0表示一级菜单）
-- order_num: 显示顺序
-- path: 路由地址
-- component: 组件路径
-- query: 路由参数
-- route_name: 路由名称
-- is_frame: 是否外链（1是 0否）
-- is_cache: 是否缓存（1缓存 0不缓存）
-- menu_type: 菜单类型（M目录 C菜单 F按钮）
-- visible: 显示状态（0显示 1隐藏）
-- status: 菜单状态（0正常 1停用）
-- perms: 权限标识
-- icon: 菜单图标
-- create_by: 创建者
-- create_time: 创建时间
-- update_by: 更新者
-- update_time: 更新时间
-- remark: 备注
-- ----------------------------

-- ----------------------------
-- 注意事项：
-- 1. 执行前请确认当前数据库中最大的menu_id，避免ID冲突
-- 2. 如果menu_id已存在，请修改为其他未使用的ID
-- 3. 执行后需要重新登录系统或刷新菜单缓存才能看到新菜单
-- 4. 如果需要给特定角色分配权限，需要在sys_role_menu表中添加关联
-- ----------------------------

-- ----------------------------
-- 可选：将菜单权限分配给超级管理员角色（角色ID=1）
-- ----------------------------
INSERT INTO `sys_role_menu` (`role_id`, `menu_id`) VALUES (1, 2000);
INSERT INTO `sys_role_menu` (`role_id`, `menu_id`) VALUES (1, 2001);
INSERT INTO `sys_role_menu` (`role_id`, `menu_id`) VALUES (1, 2002);
INSERT INTO `sys_role_menu` (`role_id`, `menu_id`) VALUES (1, 2003);
INSERT INTO `sys_role_menu` (`role_id`, `menu_id`) VALUES (1, 2004);
INSERT INTO `sys_role_menu` (`role_id`, `menu_id`) VALUES (1, 2005);
INSERT INTO `sys_role_menu` (`role_id`, `menu_id`) VALUES (1, 2006);
