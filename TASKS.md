# 三维模型重建系统 - 详细任务清单

> 本清单按模块逐层展开，共 10 大模块、90+ 细项任务，覆盖从路由配置到全场景异常处理的完整开发路径。

---

## 一、基础框架搭建（10 项）

- [x] 1.1 在 `src/router/index.js` 的 `/robot` 路由下新增 `threeModelBuilder` 子路由
- [x] 1.2 配置路由 meta 信息（title: 塔型三维重建, icon: tree）
- [x] 1.3 编写 `robot_menu.sql`：新增二级菜单 ID 2007（塔型三维重建）
- [x] 1.4 编写 `robot_menu.sql`：新增按钮权限 ID 2008（query）
- [x] 1.5 编写 `robot_menu.sql`：新增按钮权限 ID 2009（export）
- [x] 1.6 编写 `robot_menu.sql`：新增按钮权限 ID 2010（remove）
- [x] 1.7 编写 `robot_menu.sql`：将菜单权限分配给超级管理员角色（role_id=1）
- [x] 1.8 创建 `src/views/robot/threeModelBuilder.vue` 基础框架（Template 部分）
- [x] 1.9 设计 16:8 两栏布局（左侧 3D 画布 + 右侧控制面板）
- [x] 1.10 设计下部全宽历史模型管理表格区域
- [x] 1.11 参考 `cylinder.vue` 实现 `el-card`、`el-divider`、`canvas-container` 风格
- [x] 1.12 参考 `system/user/index.vue` 实现查询表单、表格、分页、操作按钮行
- [x] 1.13 定义 Script setup 结构，引入 Three.js 和 OrbitControls
- [x] 1.14 定义 Style 部分，包含 `app-container`、`canvas-container`、状态栏样式

---

## 二、数据协议与三层架构（12 项）

- [x] 2.1 定义 `Mission` 数据结构（missionId, towerId, towerBaseLocation, status, createTime）
- [x] 2.2 定义 `Device` 数据结构（deviceId, robotId, deviceType, calibration, bindTime）
- [x] 2.3 定义 `Trajectory` 数据结构（subTrajectories[], allPoints[], status, currentDeviceId）
- [x] 2.4 设计 GPS 数据协议字段（missionId, deviceId, robotId, sequence, timestamp, receiveTime, longitude, latitude, altitude, status, signalQuality, battery）
- [x] 2.5 实现 `missionMap`（Map 结构，missionId -> Mission）
- [x] 2.6 实现 `deviceMap`（Map 结构，deviceId -> Device）
- [x] 2.7 实现 `trajectoryCache`（Map 结构，robotId -> Trajectory）
- [x] 2.8 实现 `rawPointBuffer` 原始点接收缓冲区
- [x] 2.9 实现 `pendingRetransmission` 断网待补传缓存（Map 结构，robotId -> []）
- [x] 2.10 实现 `currentMission` 当前任务响应式引用
- [x] 2.11 实现 `robotStatusList` 机器人状态列表响应式引用
- [x] 2.12 定义 `simulatorState` 模拟器内部非响应式状态（robots[], tickCount, baseLng, baseLat, baseAlt）

---

## 三、前端模拟器与轨迹生成（18 项）

- [x] 3.1 定义 `simParams` 模拟参数响应式对象（modelType, towerProfile, height, bottomRadius, topRadius, robotCount, speed, noiseLevel）
- [x] 3.2 实现 `initMission` 任务初始化函数
- [x] 3.3 实现 `simulationTick` 模拟驱动引擎（200ms/tick）
- [x] 3.4 实现多机器人同时爬升（循环遍历 simulatorState.robots）
- [x] 3.5 设计垂直扫描轨迹：垂直向上到顶
- [x] 3.6 设计垂直扫描轨迹：到达顶部后水平偏移
- [x] 3.7 设计垂直扫描轨迹：垂直向下到底
- [x] 3.8 设计垂直扫描轨迹：到达底部后水平偏移
- [x] 3.9 实现塔/风机的角度步进逻辑（horizontalStep 弧度制）
- [x] 3.10 实现立面的水平步进逻辑（horizontalStep 米制）
- [x] 3.11 实现塔/风机完成条件判断（累计旋转角度 >= 360°）
- [x] 3.12 实现立面完成条件判断（累计水平扫描 >= 墙面宽度）
- [x] 3.13 实现 `generateIdealPosition` 理想位置生成（塔/风机：极坐标转笛卡尔；立面：平面坐标）
- [x] 3.14 实现 `getModelRadiusAtHeight` 模型半径随高度变化函数（simple/tapered/platform/tilted/dumbbell）
- [x] 3.15 实现 `localToGPS` 局部坐标转 GPS 坐标
- [x] 3.16 实现 `createGPSPoint` GPS 点封装（含 sequence 自增、timestamp 计算）
- [x] 3.17 实现多台机器人起始角度/位置均匀分配（angleStep 计算）
- [x] 3.18 实现模拟器启停控制（startSimulation / pauseSimulation / clearTrajectory）

---

## 四、数据接入引擎（16 项）

- [x] 4.1 定义 `ENGINE_CONFIG` 数据接入引擎常量（BUFFER_WINDOW_MS, MAX_SPEED_MPS, MIN_ALTITUDE, MAX_ALTITUDE, SUB_TRAJ_GAP_MS, SUB_TRAJ_GAP_M, DEDUP_DISTANCE_M, DEDUP_TIME_MS）
- [x] 4.2 实现 `validatePoint` 字段校验层：检查对象存在性
- [x] 4.3 实现 `validatePoint`：检查 robotId 字段及类型
- [x] 4.4 实现 `validatePoint`：检查 longitude/latitude/altitude 存在性及非 NaN
- [x] 4.5 实现 `validatePoint`：检查 timestamp 存在性及非 NaN
- [x] 4.6 实现 `validatePoint`：检查经纬度范围（-180~180, -90~90）
- [x] 4.7 实现 `validatePoint`：检查海拔范围（-500~10000m）
- [x] 4.8 实现 `validatePoint`：检查 missionId 匹配
- [x] 4.9 实现 `isFlightPoint` 飞点过滤：计算相邻点物理速度
- [x] 4.10 实现 `isFlightPoint`：速度阈值 50m/s 判定
- [x] 4.11 实现 `isDuplicate` 去重检测：1s 时间窗口判断
- [x] 4.12 实现 `isDuplicate`：5cm 空间距离判断
- [x] 4.13 实现 `shouldSplitSubTrajectory`：时间差 > 5s 切分
- [x] 4.14 实现 `shouldSplitSubTrajectory`：空间差 > 2m 且时间 > 1s 切分
- [x] 4.15 实现 `processIncomingPoint` 数据接入主入口（完整流水线）
- [x] 4.16 实现双时间轴处理逻辑（timestamp 排序，receiveTime 补传检测）

---

## 五、异常场景注入与处理（25 项）

- [x] 5.1 定义 `anomalyConfig` 异常注入配置响应式对象
- [x] 5.2 实现 UI 异常注入控制面板（el-switch 开关）
- [x] 5.3 **断电停机**：模拟机器人突然断电停止传输
- [x] 5.4 **断电停机**：断电期间保持当前高度不变
- [x] 5.5 **GPS重复**：断电期间添加微小位置噪声模拟重复信号
- [x] 5.6 **网络断连**：模拟随机断网（robot.offlineUntil 标记）
- [x] 5.7 **网络断连**：断网期间数据进入 `pendingRetransmission` 缓存队列
- [x] 5.8 **网络断连**：恢复后批量补传缓存数据（修改 receiveTime 为当前时间）
- [x] 5.9 **换设备续爬**：模拟在爬升 40% 高度后更换设备（A→B）
- [x] 5.10 **换设备续爬**：新设备自动注册到 deviceMap 并绑定 robotId
- [x] 5.11 **换设备续爬**：新设备自动附加随机校准偏移量
- [x] 5.12 **位置跳变**：恢复后首次位置随机偏移（模拟人工瞬移）
- [x] 5.13 **高斯噪声**：所有轨迹点附加 configurable 级别噪声
- [x] 5.14 **脱落坠落**（预留）：速度突增检测与标记
- [x] 5.15 **反向爬行**（预留）：运动方向突变检测
- [x] 5.16 **GPS遮挡**（预留）：信号质量骤降标记
- [x] 5.17 **多路径效应**（预留）：位置抖动增强
- [x] 5.18 **RTK切换**（预留）：精度突变标记
- [x] 5.19 **磁场干扰**（预留）：方向角异常标记
- [x] 5.20 **温度漂移**（预留）：缓慢偏移趋势
- [x] 5.21 **电量低**（预留）：battery 字段渐变模拟
- [x] 5.22 **时间戳异常**（预留）：timestamp 乱序/回退检测
- [x] 5.23 **字段损坏**（预留）：部分字段缺失/格式错误模拟
- [x] 5.24 **坐标格式错误**（预留）：经纬度格式异常模拟
- [x] 5.25 **云端突涌**（预留）：短时间内大量数据涌入模拟
- [x] 5.26 **重复 missionId**（预留）：missionId 冲突检测
- [x] 5.27 **飞点**（已实现）：见 4.9
- [x] 5.28 **风振**（预留）：高频位置振荡模拟
- [x] 5.29 **绕平台多圈**（预留）：平台区域轨迹加密模拟
- [x] 5.30 **卡滞抖动**（预留）：低幅度高频重复点模拟

---

## 六、设备校准与轨迹质量（10 项）

- [x] 6.1 实现 `calibrateDeviceByOverlap` 设备校准函数
- [x] 6.2 计算重叠段轨迹点平均圆心
- [x] 6.3 计算设备间平移向量（offsetX, offsetY, offsetZ）
- [x] 6.4 将校准参数写入 deviceMap
- [x] 6.5 实现 `computeTrajectoryQuality` 轨迹质量评分
- [x] 6.6 计算密度得分：有效点占总点比例
- [x] 6.7 计算连续性得分：基于子轨迹数量衰减
- [x] 6.8 计算信号得分：GPS 信号强度均值
- [x] 6.9 加权汇总：密度 40% + 连续性 40% + 信号 20%
- [x] 6.10 质量评分结果实时显示在机器人列表中

---

## 七、Three.js 场景与实时可视化（15 项）

- [x] 7.1 初始化 `THREE.Scene` 场景对象
- [x] 7.2 初始化 `THREE.PerspectiveCamera`（fov 75, near 0.1, far 5000）
- [x] 7.3 初始化 `THREE.WebGLRenderer`（antialias, preserveDrawingBuffer）
- [x] 7.4 集成 `OrbitControls`（enableDamping, dampingFactor 0.05）
- [x] 7.5 设置相机初始位置与目标点
- [x] 7.6 添加 `THREE.AmbientLight` 环境光
- [x] 7.7 添加 `THREE.DirectionalLight` 平行光
- [x] 7.8 添加 `THREE.GridHelper(200, 100)` 网格地面
- [x] 7.9 实现 `ensureTrajectoryMesh` 轨迹 Mesh 预分配
- [x] 7.10 预分配 `Float32Array`（10 万点 × 3 维）
- [x] 7.11 实现 `appendPointToTrajectory` 动态追加轨迹点
- [x] 7.12 实现轨迹 Mesh 自动扩容（容量翻倍）
- [x] 7.13 实现 `setDrawRange` 动态显示范围控制
- [x] 7.14 应用设备校准偏移到可视化轨迹
- [x] 7.15 实现 `clearTrajectoryMeshes` 轨迹清理

---

## 八、建模算法（18 项）

### 8.1 通用算法
- [x] 8.1.1 实现 `collectValidPoints` 收集所有有效轨迹点
- [x] 8.1.2 实现 `sliceLayers` 按高度分层切片（默认 0.5m/层）
- [x] 8.1.3 过滤每层少于 3 个点的无效层

### 8.2 塔/风机建模
- [x] 8.2.1 实现 `fitCircleRobust` RANSAC 圆拟合
- [x] 8.2.2 均值估计初始圆心（cx, cz）
- [x] 8.2.3 计算各点到圆心距离及均值半径
- [x] 8.2.4 计算半径标准差 stdR
- [x] 8.2.5 以 2σ 阈值剔除离群点
- [x] 8.2.6 用内点重新计算圆心和半径
- [x] 8.2.7 实现 `detectSegments` 段边界识别
- [x] 8.2.8 遍历各层半径，计算相邻层变化率
- [x] 8.2.9 变化率 > 0.5m 处判定为新段起点
- [x] 8.2.10 合并高度 < 1m 的短段
- [x] 8.2.11 实现 `buildTowerMesh` 多段圆柱拼接
- [x] 8.2.12 每段生成 `CylinderGeometry(topR, bottomR, height, 32, 1, true)`
- [x] 8.2.13 每段添加顶部圆圈线（64 点 Line）
- [x] 8.2.14 每段添加底部圆圈线（64 点 Line）
- [x] 8.2.15 设置半透明材质（opacity 0.3, DoubleSide）

### 8.3 立面建模
- [x] 8.3.1 实现 `buildFacadeModel` 立面建模入口
- [x] 8.3.2 计算所有点的 X/Y/Z 边界框
- [x] 8.3.3 生成 `BoxGeometry(width, height, depth)`
- [x] 8.3.4 添加 `EdgesGeometry` 绿色边框线
- [x] 8.3.5 定位到边界框中心

### 8.4 建模控制
- [x] 8.4.1 实现 `buildModel` 建模主入口，根据 modelType 分发
- [x] 8.4.2 计算数据完整度百分比
- [x] 8.4.3 生成 `completenessSegments` 20 段高度覆盖热力条
- [x] 8.4.4 建模完成后控制台打印序列化数据

---

## 九、历史模型与数据管理（12 项）

- [x] 9.1 实现 `queryParams` 查询参数响应式对象
- [x] 9.2 实现查询表单：模型名称输入框
- [x] 9.3 实现查询表单：模型类型下拉框（塔/风机/立面）
- [x] 9.4 实现查询表单：创建时间日期范围选择
- [x] 9.5 实现 `handleQuery` 查询触发
- [x] 9.6 实现 `resetQuery` 重置查询
- [x] 9.7 实现 `getModelList` Mock 数据加载
- [x] 9.8 实现 `el-table` 表格展示（模型名称、任务ID、模型类型、设备数、轨迹数、总高度、完整度、缺失段、创建时间）
- [x] 9.9 实现分页组件 pagination
- [x] 9.10 实现操作列：3D回显 `handleView3D`
- [x] 9.11 实现操作列：对比 `handleCompare` + 对比弹窗
- [x] 9.12 实现操作列：下载 `handleDownload`（JSON 导出）
- [x] 9.13 实现操作列：删除 `handleDelete`
- [x] 9.14 实现批量删除 `handleBatchDelete`

---

## 十、模型序列化、导出与全局优化（14 项）

- [x] 10.1 实现 `serializeCurrentModel` 模型序列化
- [x] 10.2 序列化字段：modelId, modelName, missionId, createTime
- [x] 10.3 序列化字段：modelType, towerProfile, totalHeight, dataCompleteness
- [x] 10.4 序列化 devices 列表（含校准参数）
- [x] 10.5 序列化 trajectories 列表（含子轨迹、质量评分）
- [x] 10.6 序列化降采样 GPS 点数组（每 5 个点保留 1 个）
- [x] 10.7 实现 `downloadJSON` JSON 文件下载（Blob + URL.createObjectURL）
- [x] 10.8 实现 `loadModelToScene` 3D 回显（重新追加轨迹点）
- [x] 10.9 实现 `toggleWireframe` 线框/实体模式切换
- [x] 10.10 实现 `centerModel` 居中视角自动计算
- [x] 10.11 实现 `screenshot` 截图保存为 PNG
- [x] 10.12 实现 `clearAllSceneObjects` 场景对象清理（dispose geometry/material）
- [x] 10.13 实现窗口 resize 自适应（handleResize）
- [x] 10.14 实现组件卸载时资源释放（cancelAnimationFrame, removeEventListener, renderer.dispose）

---

## 十一、模型类型扩展重构（16 项）

- [x] 11.1 将 `simParams.towerType` 拆分为 `modelType` + `towerProfile`
- [x] 11.2 定义 `modelType` 三种选项：tower / windTurbine / facade
- [x] 11.3 定义 `towerProfile` 五种选项：simple / tapered / platform / tilted / dumbbell
- [x] 11.4 修改模拟参数 UI：模型类型选择框
- [x] 11.5 修改模拟参数 UI：塔型轮廓条件显示（v-if="modelType === 'tower'"）
- [x] 11.6 修改查询表单 UI：模型类型查询条件
- [x] 11.7 修改表格列：塔类型 → 模型类型
- [x] 11.8 修改 `modelTypeOptions` 字典选项
- [x] 11.9 修改 `queryParams` 字段 towerType → modelType
- [x] 11.10 修改 `initMission` angleStep 逻辑：立面用米制，塔/风机用弧度制
- [x] 11.11 修改 `initMission` horizontalStep 逻辑：立面 0.3m，塔/风机 0.05rad
- [x] 11.12 重构 `getTowerRadiusAtHeight` → `getModelRadiusAtHeight`（判断 towerProfile）
- [x] 11.13 重构 `generateIdealPosition` 支持立面平面坐标
- [x] 11.14 重构 `simulationTick` 完成条件：立面按墙面宽度判断
- [x] 11.15 重构 `applyNoiseAndAnomalies` 断电处理统一调用 `generateIdealPosition`
- [x] 11.16 重构 `buildModel` 入口：facade 走立面建模，其他走塔筒建模
- [x] 11.17 全局搜索替换残留 `towerType` 引用
- [x] 11.18 全局搜索替换残留 `getTowerRadiusAtHeight` 引用

---

## 统计

| 模块 | 任务数 |
|------|--------|
| 一、基础框架搭建 | 14 |
| 二、数据协议与三层架构 | 12 |
| 三、前端模拟器与轨迹生成 | 18 |
| 四、数据接入引擎 | 16 |
| 五、异常场景注入与处理 | 30 |
| 六、设备校准与轨迹质量 | 10 |
| 七、Three.js 场景与实时可视化 | 15 |
| 八、建模算法 | 22 |
| 九、历史模型与数据管理 | 14 |
| 十、模型序列化、导出与全局优化 | 14 |
| 十一、模型类型扩展重构 | 18 |
| **合计** | **183** |
