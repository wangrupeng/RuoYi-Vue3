<template>
  <div class="app-container tower-model-builder">
    <!-- 上部：3D画布 + 控制面板 -->
    <el-row :gutter="20">
      <!-- 左侧：3D场景 -->
      <el-col :span="16">
        <el-card class="box-card">
          <template #header>
            <div class="card-header">
              <span>塔型三维重建</span>
              <div class="header-controls">
                <el-button-group>
                  <el-button size="small" @click="toggleWireframe">
                    {{ showWireframe ? '实体' : '线框' }}
                  </el-button>
                  <el-button size="small" @click="followRobot" :type="isFollowing ? 'primary' : ''">
                    跟随机器人
                  </el-button>
                  <el-button size="small" @click="centerModel">居中模型</el-button>
                  <el-button size="small" @click="screenshot">截图</el-button>
                </el-button-group>
              </div>
            </div>
          </template>
          <div ref="canvasContainer" class="canvas-container"></div>
        </el-card>
      </el-col>

      <!-- 右侧：控制面板 -->
      <el-col :span="8">
        <el-card class="box-card control-panel">
          <template #header>
            <div class="card-header">
              <span>控制面板</span>
            </div>
          </template>

          <!-- 任务状态 -->
          <el-divider content-position="left">任务状态</el-divider>
          <div class="status-bar">
            <el-tag type="info">任务ID: {{ currentMission?.missionId || '-' }}</el-tag>
            <el-tag :type="simRunning ? 'success' : 'info'">
              {{ simRunning ? '采集中' : '就绪' }}
            </el-tag>
          </div>

          <!-- 机器人状态 -->
          <el-divider content-position="left">机器人状态</el-divider>
          <div class="robot-list">
            <div v-for="robot in robotStatusList" :key="robot.robotId" class="robot-item">
              <div class="robot-header">
                <span class="robot-dot" :style="{ backgroundColor: robot.color }"></span>
                <span class="robot-name">{{ robot.robotId }}</span>
                <el-tag size="small" :type="getStatusType(robot.status)">
                  {{ robot.statusText }}
                </el-tag>
              </div>
              <div class="robot-info">
                <div>设备: {{ robot.deviceId }}</div>
                <div>高度: {{ robot.currentAlt?.toFixed(2) || 0 }}m</div>
                <div>点数: {{ robot.pointCount }}</div>
              </div>
            </div>
          </div>

          <!-- 模拟参数 -->
          <el-divider content-position="left">模拟参数</el-divider>
          <el-form :model="simParams" label-width="110px" size="small">
            <el-form-item label="模型类型">
              <el-select v-model="simParams.modelType" style="width: 100%">
                <el-option label="塔" value="tower" />
                <el-option label="风机" value="windTurbine" />
                <el-option label="立面" value="facade" />
              </el-select>
            </el-form-item>
            <el-form-item v-if="simParams.modelType === 'tower'" label="塔型轮廓">
              <el-select v-model="simParams.towerProfile" style="width: 100%">
                <el-option label="简单圆柱" value="simple" />
                <el-option label="变截面塔" value="tapered" />
                <el-option label="带平台塔" value="platform" />
                <el-option label="倾斜塔" value="tilted" />
                <el-option label="哑铃型" value="dumbbell" />
              </el-select>
            </el-form-item>
            <el-form-item label="塔高 (m)">
              <el-input-number v-model="simParams.height" :min="5" :max="200" :step="1" style="width: 100%" />
            </el-form-item>
            <el-form-item label="底径 (m)">
              <el-input-number v-model="simParams.bottomRadius" :min="1" :max="50" :step="0.1" :precision="2" style="width: 100%" />
            </el-form-item>
            <el-form-item label="顶径 (m)">
              <el-input-number v-model="simParams.topRadius" :min="1" :max="50" :step="0.1" :precision="2" style="width: 100%" />
            </el-form-item>
            <el-form-item label="机器人数">
              <el-input-number v-model="simParams.robotCount" :min="1" :max="4" :step="1" style="width: 100%" />
            </el-form-item>
            <el-form-item label="爬升速度">
              <el-slider v-model="simParams.speed" :min="1" :max="10" show-stops />
            </el-form-item>
          </el-form>

          <!-- 异常注入 -->
          <el-divider content-position="left">异常注入</el-divider>
          <el-form :model="anomalyConfig" label-width="110px" size="small">
            <el-form-item label="断电停机">
              <el-switch v-model="anomalyConfig.powerOff" />
            </el-form-item>
            <el-form-item label="GPS重复">
              <el-switch v-model="anomalyConfig.gpsRepeat" />
            </el-form-item>
            <el-form-item label="网络断连补传">
              <el-switch v-model="anomalyConfig.networkRetry" />
            </el-form-item>
            <el-form-item label="换设备续爬">
              <el-switch v-model="anomalyConfig.deviceSwitch" />
            </el-form-item>
            <el-form-item label="位置跳变">
              <el-switch v-model="anomalyConfig.positionJump" />
            </el-form-item>
          </el-form>

          <!-- 控制按钮 -->
          <el-divider content-position="left">操作</el-divider>
          <div class="action-buttons">
            <el-button type="primary" @click="startSimulation" :disabled="simRunning">开始采集</el-button>
            <el-button @click="pauseSimulation" :disabled="!simRunning">暂停</el-button>
            <el-button @click="clearTrajectory">清空轨迹</el-button>
            <el-button type="success" @click="buildModel" :disabled="!canBuildModel">重建模型</el-button>
          </div>

          <!-- 数据完整性看板 -->
          <el-divider content-position="left">数据完整性</el-divider>
          <div class="completeness-bar">
            <div class="completeness-track">
              <div
                v-for="(seg, idx) in completenessSegments"
                :key="idx"
                class="completeness-seg"
                :style="{ backgroundColor: seg.color, width: seg.percent + '%' }"
                :title="seg.title"
              ></div>
            </div>
            <div class="completeness-label">
              <span>数据完整度: {{ dataCompleteness }}%</span>
            </div>
          </div>
        </el-card>
      </el-col>
    </el-row>

    <!-- 下部：历史模型管理 -->
    <el-row :gutter="20" style="margin-top: 20px;">
      <el-col :span="24">
        <el-card class="box-card">
          <template #header>
            <div class="card-header">
              <span>历史模型管理</span>
              <div>
                <el-button type="primary" size="small" @click="handleImportModel">导入模型</el-button>
              </div>
            </div>
          </template>

          <!-- 查询表单 -->
          <el-form :model="queryParams" ref="queryRef" :inline="true" label-width="80px" size="small">
            <el-form-item label="模型名称" prop="modelName">
              <el-input v-model="queryParams.modelName" placeholder="请输入模型名称" clearable style="width: 200px" />
            </el-form-item>
            <el-form-item label="模型类型" prop="modelType">
              <el-select v-model="queryParams.modelType" placeholder="请选择" clearable style="width: 150px">
                <el-option label="塔" value="tower" />
                <el-option label="风机" value="windTurbine" />
                <el-option label="立面" value="facade" />
              </el-select>
            </el-form-item>
            <el-form-item label="创建时间">
              <el-date-picker
                v-model="queryParams.dateRange"
                value-format="YYYY-MM-DD"
                type="daterange"
                range-separator="-"
                start-placeholder="开始日期"
                end-placeholder="结束日期"
                style="width: 240px"
              />
            </el-form-item>
            <el-form-item>
              <el-button type="primary" icon="Search" @click="handleQuery">搜索</el-button>
              <el-button icon="Refresh" @click="resetQuery">重置</el-button>
            </el-form-item>
          </el-form>

          <!-- 操作按钮 -->
          <el-row :gutter="10" class="mb8">
            <el-col :span="1.5">
              <el-button type="danger" plain icon="Delete" :disabled="!selectedIds.length" @click="handleBatchDelete">删除</el-button>
            </el-col>
            <right-toolbar v-model:showSearch="showSearch" @queryTable="getModelList" :columns="columns" />
          </el-row>

          <!-- 数据表格 -->
          <el-table v-loading="loading" :data="modelList" @selection-change="handleSelectionChange">
            <el-table-column type="selection" width="50" align="center" />
            <el-table-column label="模型名称" align="center" prop="modelName" :show-overflow-tooltip="true" />
            <el-table-column label="任务ID" align="center" prop="missionId" />
            <el-table-column label="模型类型" align="center" prop="modelType">
              <template #default="scope">
                <dict-tag :options="modelTypeOptions" :value="scope.row.modelType" />
              </template>
            </el-table-column>
            <el-table-column label="设备数" align="center" prop="deviceCount" width="80" />
            <el-table-column label="轨迹数" align="center" prop="trajectoryCount" width="80" />
            <el-table-column label="总高度(m)" align="center" prop="totalHeight" width="100" />
            <el-table-column label="完整度" align="center" prop="dataCompleteness" width="100">
              <template #default="scope">
                <el-progress :percentage="scope.row.dataCompleteness" :color="progressColors" />
              </template>
            </el-table-column>
            <el-table-column label="缺失段" align="center" prop="missingSegmentCount" width="80" />
            <el-table-column label="创建时间" align="center" prop="createTime" width="160">
              <template #default="scope">
                <span>{{ parseTime(scope.row.createTime) }}</span>
              </template>
            </el-table-column>
            <el-table-column label="操作" align="center" width="220" class-name="small-padding fixed-width">
              <template #default="scope">
                <el-button link type="primary" icon="View" @click="handleView3D(scope.row)">3D回显</el-button>
                <el-button link type="primary" icon="CopyDocument" @click="handleCompare(scope.row)">对比</el-button>
                <el-button link type="primary" icon="Download" @click="handleDownload(scope.row)">下载</el-button>
                <el-button link type="danger" icon="Delete" @click="handleDelete(scope.row)">删除</el-button>
              </template>
            </el-table-column>
          </el-table>

          <!-- 分页 -->
          <pagination v-show="total > 0" :total="total" v-model:page="queryParams.pageNum" v-model:limit="queryParams.pageSize" @pagination="getModelList" />
        </el-card>
      </el-col>
    </el-row>

    <!-- 对比模型选择弹窗 -->
    <el-dialog title="选择对比模型" v-model="compareDialogVisible" width="500px" append-to-body>
      <el-form label-width="100px">
        <el-form-item label="基准模型">
          <el-input v-model="compareBaseModelName" disabled />
        </el-form-item>
        <el-form-item label="对比模型">
          <el-select v-model="compareTargetId" placeholder="请选择对比模型" style="width: 100%">
            <el-option
              v-for="item in modelList.filter(m => m.modelId !== compareBaseId)"
              :key="item.modelId"
              :label="item.modelName"
              :value="item.modelId"
            />
          </el-select>
        </el-form-item>
      </el-form>
      <template #footer>
        <div class="dialog-footer">
          <el-button type="primary" @click="confirmCompare">确 定</el-button>
          <el-button @click="compareDialogVisible = false">取 消</el-button>
        </div>
      </template>
    </el-dialog>
  </div>
</template>

<script setup name="ThreeModelBuilder">
import * as THREE from 'three'
import { OrbitControls } from 'three/examples/jsm/controls/OrbitControls.js'

const { proxy } = getCurrentInstance()

// ==================== Three.js 核心变量 ====================
const canvasContainer = ref(null)
let scene = null
let camera = null
let renderer = null
let controls = null
let animationId = null
let labelsGroup = null

// ==================== 任务与数据状态 ====================
const currentMission = ref(null)
const robotStatusList = ref([])
const simRunning = ref(false)
const isFollowing = ref(false)
const showWireframe = ref(false)
const canBuildModel = ref(false)
const dataCompleteness = ref(0)
const completenessSegments = ref([])

// ==================== 数据协议与轨迹缓存 ====================
const missionMap = ref(new Map()) // missionId -> Mission
const deviceMap = ref(new Map()) // deviceId -> Device
const trajectoryCache = ref(new Map()) // robotId -> { subTrajectories[], allPoints[], status, currentDeviceId }
const rawPointBuffer = ref([]) // 原始点接收缓冲区
const pendingRetransmission = ref(new Map()) // robotId -> [] 断网待补传缓存
const trajectoryMeshes = new Map() // robotId -> { line, geometry, positions, pointCount, color }
let pointSequence = 0
let simulationTimer = null
let missionStartTime = null

// 模拟器内部状态（非响应式，避免频繁触发）
const simulatorState = {
  robots: [], // { robotId, deviceId, startAngle, currentHeight, currentAngle, status, offlineUntil, powerOffUntil, switchedDevice }
  tickCount: 0,
  baseLng: 116.3974,
  baseLat: 39.9093,
  baseAlt: 0
}

// ==================== 模拟参数 ====================
const simParams = ref({
  modelType: 'tower',        // 三种模型：tower / windTurbine / facade
  towerProfile: 'simple',    // 仅当 modelType === 'tower' 时有效
  height: 50,
  bottomRadius: 10,
  topRadius: 8,
  robotCount: 2,
  speed: 3,
  noiseLevel: 0.1
})

// ==================== 异常注入配置 ====================
const anomalyConfig = ref({
  powerOff: false,
  gpsRepeat: false,
  networkRetry: false,
  deviceSwitch: false,
  positionJump: false
})

// ==================== 历史模型查询 ====================
const queryRef = ref(null)
const showSearch = ref(true)
const loading = ref(false)
const modelList = ref([])
const total = ref(0)
const selectedIds = ref([])
const queryParams = ref({
  pageNum: 1,
  pageSize: 10,
  modelName: '',
  modelType: '',
  dateRange: []
})
const columns = ref({
  modelName: { visible: true },
  missionId: { visible: true },
  modelType: { visible: true },
  deviceCount: { visible: true },
  trajectoryCount: { visible: true },
  totalHeight: { visible: true },
  dataCompleteness: { visible: true },
  missingSegmentCount: { visible: true },
  createTime: { visible: true }
})
const modelTypeOptions = ref([
  { label: '塔', value: 'tower' },
  { label: '风机', value: 'windTurbine' },
  { label: '立面', value: 'facade' }
])
const towerProfileOptions = ref([
  { label: '简单圆柱', value: 'simple' },
  { label: '变截面塔', value: 'tapered' },
  { label: '带平台塔', value: 'platform' },
  { label: '倾斜塔', value: 'tilted' },
  { label: '哑铃型', value: 'dumbbell' }
])
const progressColors = ref([
  { color: '#f56c6c', percentage: 50 },
  { color: '#e6a23c', percentage: 80 },
  { color: '#67c23a', percentage: 100 }
])

// ==================== 对比弹窗 ====================
const compareDialogVisible = ref(false)
const compareBaseId = ref('')
const compareBaseModelName = ref('')
const compareTargetId = ref('')

// ==================== Three.js 初始化 ====================
function initThreeJS() {
  scene = new THREE.Scene()
  scene.background = new THREE.Color(0xf5f5f5)

  const width = canvasContainer.value.clientWidth
  const height = canvasContainer.value.clientHeight
  camera = new THREE.PerspectiveCamera(75, width / height, 0.1, 5000)
  camera.position.set(30, 30, 30)
  camera.lookAt(0, 25, 0)

  renderer = new THREE.WebGLRenderer({ antialias: true, preserveDrawingBuffer: true })
  renderer.setSize(width, height)
  renderer.setPixelRatio(window.devicePixelRatio)
  canvasContainer.value.appendChild(renderer.domElement)

  controls = new OrbitControls(camera, renderer.domElement)
  controls.enableDamping = true
  controls.dampingFactor = 0.05
  controls.enableZoom = true
  controls.enablePan = true
  controls.maxDistance = 5000
  controls.minDistance = 1
  controls.target.set(0, 25, 0)

  const ambientLight = new THREE.AmbientLight(0xffffff, 0.6)
  scene.add(ambientLight)

  const directionalLight = new THREE.DirectionalLight(0xffffff, 0.8)
  directionalLight.position.set(50, 100, 50)
  scene.add(directionalLight)

  labelsGroup = new THREE.Group()
  scene.add(labelsGroup)

  const gridHelper = new THREE.GridHelper(200, 100, 0xcccccc, 0xe5e5e5)
  gridHelper.name = 'gridHelper'
  scene.add(gridHelper)

  window.addEventListener('resize', handleResize)
  animate()
}

// ==================== 动画循环 ====================
function animate() {
  animationId = requestAnimationFrame(() => {
    animate()
    if (isFollowing.value && simulatorState.robots.length > 0) {
      const robot = simulatorState.robots[0]
      const targetY = robot.currentHeight
      controls.target.lerp(new THREE.Vector3(0, targetY, 0), 0.05)
    }
    controls.update()
    renderer.render(scene, camera)
  })
}

// ==================== 窗口自适应 ====================
function handleResize() {
  if (!camera || !renderer) return
  const width = canvasContainer.value.clientWidth
  const height = canvasContainer.value.clientHeight
  camera.aspect = width / height
  camera.updateProjectionMatrix()
  renderer.setSize(width, height)
  renderer.setPixelRatio(window.devicePixelRatio)
}

// ==================== 视图控制 ====================
function toggleWireframe() {
  showWireframe.value = !showWireframe.value
  const tower = scene?.getObjectByName('towerModel')
  if (tower) {
    tower.traverse(child => {
      if (child.isMesh && child.material) {
        child.material.wireframe = showWireframe.value
        child.material.opacity = showWireframe.value ? 1 : 0.3
        child.material.color.setHex(showWireframe.value ? 0x46ff40 : 0x67c23a)
      }
      if (child.isLine || child.isLineSegments) {
        child.visible = !showWireframe.value
      }
    })
  }
}

function followRobot() {
  isFollowing.value = !isFollowing.value
}

function centerModel() {
  if (scene && controls && camera) {
    controls.target.set(0, simParams.value.height / 2, 0)
    const dist = Math.max(simParams.value.height, simParams.value.bottomRadius * 2) * 1.5
    const direction = new THREE.Vector3(1, 1, 1).normalize()
    camera.position.copy(direction.multiplyScalar(dist).add(controls.target))
    controls.update()
  }
}

function screenshot() {
  if (!renderer || !scene || !camera) return
  renderer.render(scene, camera)
  const dataURL = renderer.domElement.toDataURL('image/png')
  const link = document.createElement('a')
  link.download = 'tower-model.png'
  link.href = dataURL
  link.click()
  proxy.$modal.msgSuccess('截图保存成功')
}

// ==================== 模拟引擎核心 ====================

function initMission() {
  const missionId = 'MISSION-' + Date.now()
  missionStartTime = Date.now()
  pointSequence = 0

  const mission = {
    missionId,
    towerId: 'TOWER-' + Math.floor(Math.random() * 1000),
    towerBaseLocation: { lng: simulatorState.baseLng, lat: simulatorState.baseLat, alt: simulatorState.baseAlt },
    status: 'running',
    createTime: new Date().toISOString()
  }
  missionMap.value.set(missionId, mission)
  currentMission.value = mission

  // 初始化设备与机器人
  simulatorState.robots = []
  deviceMap.value.clear()
  trajectoryCache.value.clear()
  pendingRetransmission.value.clear()
  robotStatusList.value = []

  const colors = ['#ff6b6b', '#4ecdc4', '#45b7d1', '#96ceb4']
  const angleStep = simParams.value.modelType === 'facade'
    ? (simParams.value.bottomRadius * 2) / simParams.value.robotCount
    : (Math.PI * 2) / simParams.value.robotCount

  for (let i = 0; i < simParams.value.robotCount; i++) {
    const robotId = `ROBOT-${i + 1}`
    const deviceId = `DEVICE-${i + 1}-A`

    const device = {
      deviceId,
      robotId,
      deviceType: 'crawler',
      calibration: { offsetX: 0, offsetY: 0, offsetZ: 0 },
      bindTime: new Date().toISOString()
    }
    deviceMap.value.set(deviceId, device)

    simulatorState.robots.push({
      robotId,
      deviceId,
      startAngle: i * angleStep,
      currentHeight: 0,
      currentAngle: i * angleStep,
      status: 'running',
      offlineUntil: 0,
      powerOffUntil: 0,
      switchedDevice: false,
      repeatCount: 0,
      originalDeviceId: deviceId,
      scanDirection: 1,      // 1=向上，-1=向下
      horizontalStep: simParams.value.modelType === 'facade' ? 0.3 : 0.05   // 立面用米，塔/风机用弧度
    })

    trajectoryCache.value.set(robotId, {
      subTrajectories: [],
      allPoints: [],
      status: 'running',
      currentDeviceId: deviceId
    })

    robotStatusList.value.push({
      robotId,
      deviceId,
      color: colors[i % colors.length],
      status: 'online',
      statusText: '在线',
      currentAlt: 0,
      pointCount: 0
    })
  }

  simulatorState.tickCount = 0
}

function getModelRadiusAtHeight(height) {
  const h = simParams.value.height
  const br = simParams.value.bottomRadius
  const tr = simParams.value.topRadius
  const profile = simParams.value.towerProfile

  if (profile === 'simple') {
    return br
  }
  if (profile === 'tapered') {
    return br + (tr - br) * (height / h)
  }
  if (profile === 'platform') {
    const platformHeight = h * 0.6
    const platformWidth = 2.0
    if (height >= platformHeight - 1 && height <= platformHeight + 1) {
      return br + (tr - br) * (height / h) + platformWidth
    }
    return br + (tr - br) * (height / h)
  }
  if (profile === 'tilted') {
    return br + (tr - br) * (height / h)
  }
  if (profile === 'dumbbell') {
    // 哑铃型：中间细两头粗，分段线性
    const halfH = h / 2
    const waistR = Math.min(br, tr) * 0.5 // 腰部半径为较小端的50%
    if (height <= halfH) {
      return br + (waistR - br) * (height / halfH)
    }
    return waistR + (tr - waistR) * ((height - halfH) / halfH)
  }
  return br
}

function generateIdealPosition(robot) {
  const h = robot.currentHeight

  if (simParams.value.modelType === 'facade') {
    // 立面：平面墙面，z固定，x为水平位置，y为高度
    const elevationWidth = simParams.value.bottomRadius * 2
    const x = robot.currentAngle - elevationWidth / 2
    const z = 0
    const y = h
    return { x, y, z }
  }

  // 塔和风机：旋转体
  const radius = getModelRadiusAtHeight(h)
  const x = radius * Math.cos(robot.currentAngle)
  const z = radius * Math.sin(robot.currentAngle)
  const y = h
  return { x, y, z }
}

function localToGPS(x, y, z) {
  const latPerMeter = 1 / 111320
  const lngPerMeter = 1 / (111320 * Math.cos(simulatorState.baseLat * Math.PI / 180))
  return {
    longitude: simulatorState.baseLng + x * lngPerMeter,
    latitude: simulatorState.baseLat + z * latPerMeter,
    altitude: simulatorState.baseAlt + y
  }
}

function applyNoiseAndAnomalies(robot, ideal) {
  const now = Date.now()
  const cfg = anomalyConfig.value
  let px = ideal.x
  let py = ideal.y
  let pz = ideal.z
  let status = 'running'
  let signalQuality = 90 + Math.random() * 10
  let battery = Math.max(10, 100 - robot.currentHeight / simParams.value.height * 60)

  // 断电停机异常
  if (cfg.powerOff && Math.random() < 0.001 && robot.powerOffUntil < now) {
    robot.powerOffUntil = now + 5000 + Math.random() * 10000
  }

  if (robot.powerOffUntil > now) {
    status = 'idle'
    battery = 0
    // 保持当前高度不变
    py = robot.currentHeight
    const ideal = generateIdealPosition(robot)
    px = ideal.x
    pz = ideal.z

    // GPS重复：添加微小噪声
    if (cfg.gpsRepeat) {
      px += (Math.random() - 0.5) * 0.02
      pz += (Math.random() - 0.5) * 0.02
      signalQuality = 60 + Math.random() * 20
    }
  }

  // 恢复后位置跳变
  if (cfg.positionJump && robot.powerOffUntil > 0 && robot.powerOffUntil <= now && robot.repeatCount === 0) {
    px += (Math.random() - 0.5) * 0.8
    pz += (Math.random() - 0.5) * 0.8
    robot.repeatCount = 1
  }

  // 换设备异常
  if (cfg.deviceSwitch && !robot.switchedDevice && robot.currentHeight > simParams.value.height * 0.4) {
    const newDeviceId = robot.deviceId.replace(/-A$/, '-B')
    const oldDevice = deviceMap.value.get(robot.deviceId)
    if (oldDevice && !deviceMap.value.has(newDeviceId)) {
      deviceMap.value.set(newDeviceId, {
        deviceId: newDeviceId,
        robotId: robot.robotId,
        deviceType: 'crawler',
        calibration: { offsetX: 0.3 + (Math.random() - 0.5) * 0.2, offsetY: 0.1, offsetZ: -0.2 },
        bindTime: new Date().toISOString()
      })
      robot.deviceId = newDeviceId
      robot.switchedDevice = true

      const cache = trajectoryCache.value.get(robot.robotId)
      if (cache) cache.currentDeviceId = newDeviceId

      const robotStatus = robotStatusList.value.find(r => r.robotId === robot.robotId)
      if (robotStatus) robotStatus.deviceId = newDeviceId
    }
  }

  // 网络断连模拟
  if (cfg.networkRetry && Math.random() < 0.0008 && robot.offlineUntil < now) {
    robot.offlineUntil = now + 3000 + Math.random() * 7000
  }

  // 添加高斯噪声
  const noise = simParams.value.noiseLevel
  px += (Math.random() - 0.5) * noise
  py += (Math.random() - 0.5) * noise * 0.3
  pz += (Math.random() - 0.5) * noise

  return { x: px, y: py, z: pz, status, signalQuality, battery }
}

function createGPSPoint(robot, pos, status, signalQuality, battery) {
  const gps = localToGPS(pos.x, pos.y, pos.z)
  const now = Date.now()
  return {
    missionId: currentMission.value?.missionId,
    deviceId: robot.deviceId,
    robotId: robot.robotId,
    sequence: ++pointSequence,
    timestamp: missionStartTime + simulatorState.tickCount * 200,
    receiveTime: now,
    longitude: gps.longitude,
    latitude: gps.latitude,
    altitude: gps.altitude,
    status,
    signalQuality: Math.round(signalQuality),
    battery: Math.round(battery)
  }
}

function simulationTick() {
  if (!simRunning.value) return
  simulatorState.tickCount++
  // 垂直扫描模式：先垂直向上到顶，水平偏移，再垂直向下到底，水平偏移，反复环绕
  const vSpeed = 0.3 * simParams.value.speed // 垂直速度 m/tick

  simulatorState.robots.forEach(robot => {
    // 完成条件根据模型类型判断
    const modelType = simParams.value.modelType
    let isFinished = false
    if (modelType === 'tower' || modelType === 'windTurbine') {
      isFinished = Math.abs(robot.currentAngle - robot.startAngle) >= Math.PI * 2
    } else if (modelType === 'facade') {
      const elevationWidth = simParams.value.bottomRadius * 2
      isFinished = (robot.currentAngle - robot.startAngle) >= elevationWidth
    }
    if (isFinished) {
      if (robot.status !== 'finished') {
        robot.status = 'finished'
        const rs = robotStatusList.value.find(r => r.robotId === robot.robotId)
        if (rs) { rs.status = 'info'; rs.statusText = '已完成' }
      }
      return
    }

    // 垂直扫描：上下移动
    if (robot.status === 'running' && robot.powerOffUntil <= Date.now()) {
      robot.currentHeight += vSpeed * robot.scanDirection

      // 到达顶部，转向下并水平偏移
      if (robot.currentHeight >= simParams.value.height) {
        robot.currentHeight = simParams.value.height
        robot.scanDirection = -1
        robot.currentAngle += robot.horizontalStep
      }

      // 到达底部，转向上并水平偏移
      if (robot.currentHeight <= 0) {
        robot.currentHeight = 0
        robot.scanDirection = 1
        robot.currentAngle += robot.horizontalStep
      }

      robot.repeatCount = 0
    }

    const ideal = generateIdealPosition(robot)
    const anomalous = applyNoiseAndAnomalies(robot, ideal)

    const point = createGPSPoint(robot, anomalous, anomalous.status, anomalous.signalQuality, anomalous.battery)

    // 网络断连时进入补传缓存
    if (anomalyConfig.value.networkRetry && robot.offlineUntil > Date.now()) {
      const pending = pendingRetransmission.value.get(robot.robotId) || []
      pending.push(point)
      pendingRetransmission.value.set(robot.robotId, pending)

      const rs = robotStatusList.value.find(r => r.robotId === robot.robotId)
      if (rs) { rs.status = 'warning'; rs.statusText = '断网缓存中' }
    } else {
      // 如果有补传缓存，先发送缓存
      const pending = pendingRetransmission.value.get(robot.robotId)
      if (pending && pending.length > 0) {
        pending.forEach(p => {
          p.receiveTime = Date.now() // 补传的接收时间是现在
          processIncomingPoint(p)
        })
        pendingRetransmission.value.set(robot.robotId, [])
        proxy.$modal.msgSuccess(`${robot.robotId} 补传 ${pending.length} 个点`)
      }
      processIncomingPoint(point)

      const rs = robotStatusList.value.find(r => r.robotId === robot.robotId)
      if (rs && rs.status === 'warning') { rs.status = 'online'; rs.statusText = '在线' }
    }
  })

  // 检查是否全部完成
  const allFinished = simulatorState.robots.every(r => r.status === 'finished')
  if (allFinished && simRunning.value) {
    simRunning.value = false
    canBuildModel.value = true
    if (simulationTimer) {
      clearInterval(simulationTimer)
      simulationTimer = null
    }
    proxy.$modal.msgSuccess('所有机器人已完成爬升，可以重建模型')
  }

  updateRobotStatusFromCache()
}

// ==================== 数据接入引擎常量 ====================
const ENGINE_CONFIG = {
  BUFFER_WINDOW_MS: 2000,
  MAX_SPEED_MPS: 50,
  MIN_ALTITUDE: -500,
  MAX_ALTITUDE: 10000,
  SUB_TRAJ_GAP_MS: 5000,
  SUB_TRAJ_GAP_M: 2,
  DEDUP_DISTANCE_M: 0.05,
  DEDUP_TIME_MS: 1000
}

// ==================== 数据校验层 ====================
function validatePoint(point) {
  if (!point || typeof point !== 'object') return false
  if (!point.robotId || typeof point.robotId !== 'string') return false
  if (point.longitude == null || isNaN(point.longitude)) return false
  if (point.latitude == null || isNaN(point.latitude)) return false
  if (point.altitude == null || isNaN(point.altitude)) return false
  if (point.timestamp == null || isNaN(point.timestamp)) return false
  if (point.longitude < -180 || point.longitude > 180) return false
  if (point.latitude < -90 || point.latitude > 90) return false
  if (point.altitude < ENGINE_CONFIG.MIN_ALTITUDE || point.altitude > ENGINE_CONFIG.MAX_ALTITUDE) return false
  if (currentMission.value && point.missionId !== currentMission.value.missionId) return false
  return true
}

// ==================== 飞点过滤 ====================
function isFlightPoint(point, prevPoint) {
  if (!prevPoint) return false
  const dt = (point.timestamp - prevPoint.timestamp) / 1000
  if (dt <= 0) return false
  const dx = (point.longitude - prevPoint.longitude) * 111320 * Math.cos(point.latitude * Math.PI / 180)
  const dz = (point.latitude - prevPoint.latitude) * 111320
  const dy = point.altitude - prevPoint.altitude
  const dist = Math.sqrt(dx * dx + dy * dy + dz * dz)
  const speed = dist / dt
  return speed > ENGINE_CONFIG.MAX_SPEED_MPS
}

// ==================== 去重检测 ====================
function isDuplicate(point, prevPoint) {
  if (!prevPoint) return false
  const dt = Math.abs(point.timestamp - prevPoint.timestamp)
  if (dt > ENGINE_CONFIG.DEDUP_TIME_MS) return false
  const dx = (point.longitude - prevPoint.longitude) * 111320 * Math.cos(point.latitude * Math.PI / 180)
  const dz = (point.latitude - prevPoint.latitude) * 111320
  const dy = point.altitude - prevPoint.altitude
  const dist = Math.sqrt(dx * dx + dy * dy + dz * dz)
  return dist < ENGINE_CONFIG.DEDUP_DISTANCE_M
}

// ==================== 子轨迹切分检测 ====================
function shouldSplitSubTrajectory(prevPoint, point) {
  if (!prevPoint) return true
  const dt = point.timestamp - prevPoint.timestamp
  if (dt > ENGINE_CONFIG.SUB_TRAJ_GAP_MS) return true
  const dx = (point.longitude - prevPoint.longitude) * 111320 * Math.cos(point.latitude * Math.PI / 180)
  const dz = (point.latitude - prevPoint.latitude) * 111320
  const dy = point.altitude - prevPoint.altitude
  const dist = Math.sqrt(dx * dx + dy * dy + dz * dz)
  if (dist > ENGINE_CONFIG.SUB_TRAJ_GAP_M && dt > 1000) return true
  return false
}

// ==================== 数据接入主入口 ====================
function processIncomingPoint(point) {
  // 1. 数据校验层
  if (!validatePoint(point)) {
    console.warn('[DataEngine] 非法数据包丢弃:', point)
    return
  }

  // 2. 原始缓冲区
  rawPointBuffer.value.push(point)

  // 3. 获取缓存
  const cache = trajectoryCache.value.get(point.robotId)
  if (!cache) return

  const allPoints = cache.allPoints
  const lastPoint = allPoints.length > 0 ? allPoints[allPoints.length - 1] : null

  // 4. 飞点过滤
  if (isFlightPoint(point, lastPoint)) {
    console.warn(`[DataEngine] ${point.robotId} 飞点过滤: seq=${point.sequence}`)
    point._anomaly = 'flight'
    point._valid = false
    cache.allPoints.push(point)
    return
  }

  // 5. 去重检测
  if (isDuplicate(point, lastPoint)) {
    point._anomaly = 'duplicate'
    point._valid = false
    cache.allPoints.push(point)
    return
  }

  // 6. 子轨迹切分检测
  if (shouldSplitSubTrajectory(lastPoint, point)) {
    const subId = `sub-${cache.subTrajectories.length}`
    cache.subTrajectories.push({
      subId,
      startIndex: allPoints.length,
      endIndex: -1,
      startTime: point.timestamp,
      endTime: point.timestamp,
      deviceId: point.deviceId,
      pointCount: 0,
      status: point.status
    })
    console.log(`[DataEngine] ${point.robotId} 切分新子轨迹: ${subId}`)
  }

  // 更新当前子轨迹
  if (cache.subTrajectories.length > 0) {
    const currentSub = cache.subTrajectories[cache.subTrajectories.length - 1]
    currentSub.endIndex = allPoints.length
    currentSub.endTime = point.timestamp
    currentSub.pointCount++
    if (point.deviceId !== currentSub.deviceId) {
      currentSub.deviceId = point.deviceId
    }
  } else {
    cache.subTrajectories.push({
      subId: 'sub-0',
      startIndex: 0,
      endIndex: 0,
      startTime: point.timestamp,
      endTime: point.timestamp,
      deviceId: point.deviceId,
      pointCount: 1,
      status: point.status
    })
  }

  // 7. 存入主缓存
  point._valid = true
  cache.allPoints.push(point)

  // 8. 更新UI
  const rs = robotStatusList.value.find(r => r.robotId === point.robotId)
  if (rs) {
    rs.pointCount = cache.allPoints.length
    rs.currentAlt = point.altitude - simulatorState.baseAlt
  }

  // 9. 实时轨迹可视化
  if (point._valid) {
    appendPointToTrajectory(point.robotId, point)
  }
}

function updateRobotStatusFromCache() {
  // 由 simulationTick 调用，刷新UI状态
  // 目前数据已在 processIncomingPoint 中更新
}

// ==================== GPS 与局部坐标转换 ====================
function gpsToLocal(lng, lat, alt) {
  const latPerMeter = 1 / 111320
  const lngPerMeter = 1 / (111320 * Math.cos(simulatorState.baseLat * Math.PI / 180))
  return {
    x: (lng - simulatorState.baseLng) / lngPerMeter,
    y: alt - simulatorState.baseAlt,
    z: (lat - simulatorState.baseLat) / latPerMeter
  }
}

// ==================== 设备校准（Step4） ====================
function calibrateDeviceByOverlap(deviceId, referenceDeviceId) {
  const device = deviceMap.value.get(deviceId)
  const refDevice = deviceMap.value.get(referenceDeviceId)
  if (!device || !refDevice) return null

  const robotId = device.robotId
  const refRobotId = refDevice.robotId
  const cache = trajectoryCache.value.get(robotId)
  const refCache = trajectoryCache.value.get(refRobotId)
  if (!cache || !refCache) return null

  const myPoints = cache.allPoints.filter(p => p._valid)
  const refPoints = refCache.allPoints.filter(p => p._valid)
  if (myPoints.length < 5 || refPoints.length < 5) return null

  const myLocal = myPoints.map(p => gpsToLocal(p.longitude, p.latitude, p.altitude))
  const refLocal = refPoints.map(p => gpsToLocal(p.longitude, p.latitude, p.altitude))

  const myCenter = {
    x: myLocal.reduce((s, p) => s + p.x, 0) / myLocal.length,
    z: myLocal.reduce((s, p) => s + p.z, 0) / myLocal.length
  }
  const refCenter = {
    x: refLocal.reduce((s, p) => s + p.x, 0) / refLocal.length,
    z: refLocal.reduce((s, p) => s + p.z, 0) / refLocal.length
  }

  const offset = {
    offsetX: refCenter.x - myCenter.x,
    offsetY: 0,
    offsetZ: refCenter.z - myCenter.z
  }

  device.calibration = offset
  console.log(`[Calibration] ${deviceId} 校准完成: dx=${offset.offsetX.toFixed(3)}, dz=${offset.offsetZ.toFixed(3)}`)
  return offset
}

// ==================== 轨迹质量评分（Step4） ====================
function computeTrajectoryQuality(cache) {
  if (!cache || cache.allPoints.length < 2) {
    return { total: 0, density: 0, continuity: 0, signal: 0 }
  }

  const validPoints = cache.allPoints.filter(p => p._valid)
  const points = cache.allPoints
  const total = points.length

  const density = total > 0 ? Math.round((validPoints.length / total) * 100) : 0

  const subCount = cache.subTrajectories.length
  const continuity = subCount <= 1 ? 100 : Math.max(0, 100 - (subCount - 1) * 15)

  const avgSignal = points.reduce((s, p) => s + (p.signalQuality || 80), 0) / total
  const signal = Math.round(avgSignal)

  const overall = Math.round(density * 0.4 + continuity * 0.4 + signal * 0.2)

  return { total: overall, density, continuity, signal }
}

// ==================== Three.js 实时轨迹可视化（Step5） ====================
function ensureTrajectoryMesh(robotId, color) {
  if (trajectoryMeshes.has(robotId)) return trajectoryMeshes.get(robotId)

  const maxPoints = 20000
  const positions = new Float32Array(maxPoints * 3)
  const geometry = new THREE.BufferGeometry()
  geometry.setAttribute('position', new THREE.BufferAttribute(positions, 3))
  geometry.setDrawRange(0, 0)

  const material = new THREE.LineBasicMaterial({ color, linewidth: 2 })
  const line = new THREE.Line(geometry, material)
  line.frustumCulled = false
  scene.add(line)

  const mesh = { line, geometry, positions, maxPoints, pointCount: 0, color }
  trajectoryMeshes.set(robotId, mesh)
  return mesh
}

function appendPointToTrajectory(robotId, point) {
  if (!scene) return
  const rs = robotStatusList.value.find(r => r.robotId === robotId)
  const color = rs ? rs.color : '#46ff40'

  const mesh = ensureTrajectoryMesh(robotId, color)
  const local = gpsToLocal(point.longitude, point.latitude, point.altitude)

  // 应用设备校准偏移
  const device = deviceMap.value.get(point.deviceId)
  if (device && device.calibration) {
    local.x += device.calibration.offsetX || 0
    local.y += device.calibration.offsetY || 0
    local.z += device.calibration.offsetZ || 0
  }

  const idx = mesh.pointCount * 3
  if (idx + 3 > mesh.positions.length) {
    const newArr = new Float32Array(mesh.positions.length * 2)
    newArr.set(mesh.positions)
    mesh.positions = newArr
    mesh.geometry.setAttribute('position', new THREE.BufferAttribute(mesh.positions, 3))
  }

  mesh.positions[idx] = local.x
  mesh.positions[idx + 1] = local.y
  mesh.positions[idx + 2] = local.z
  mesh.pointCount++

  mesh.geometry.attributes.position.needsUpdate = true
  mesh.geometry.setDrawRange(0, mesh.pointCount)
}

function clearTrajectoryMeshes() {
  trajectoryMeshes.forEach(mesh => {
    if (mesh.line) {
      scene.remove(mesh.line)
      mesh.geometry.dispose()
      mesh.line.material.dispose()
    }
  })
  trajectoryMeshes.clear()
}

function clearAllSceneObjects() {
  clearTrajectoryMeshes()
  const oldTower = scene?.getObjectByName('towerModel')
  if (oldTower) {
    oldTower.traverse(child => {
      if (child.geometry) child.geometry.dispose()
      if (child.material) {
        if (Array.isArray(child.material)) {
          child.material.forEach(m => m.dispose())
        } else {
          child.material.dispose()
        }
      }
    })
    scene.remove(oldTower)
  }
}

// ==================== 模拟控制 ====================
function startSimulation() {
  if (simRunning.value) return

  // 如果没有初始化或已清空，重新初始化
  if (!currentMission.value || simulatorState.robots.length === 0) {
    initMission()
  }

  simRunning.value = true
  canBuildModel.value = false

  if (simulationTimer) {
    clearInterval(simulationTimer)
  }
  simulationTimer = setInterval(simulationTick, 200)

  proxy.$modal.msgSuccess('开始模拟采集')
}

function pauseSimulation() {
  simRunning.value = false
  if (simulationTimer) {
    clearInterval(simulationTimer)
    simulationTimer = null
  }
  proxy.$modal.msgSuccess('已暂停采集')
}

function clearTrajectory() {
  simRunning.value = false
  if (simulationTimer) {
    clearInterval(simulationTimer)
    simulationTimer = null
  }

  missionMap.value.clear()
  deviceMap.value.clear()
  trajectoryCache.value.clear()
  rawPointBuffer.value = []
  pendingRetransmission.value.clear()
  simulatorState.robots = []
  simulatorState.tickCount = 0
  currentMission.value = null
  robotStatusList.value = []
  canBuildModel.value = false
  dataCompleteness.value = 0
  completenessSegments.value = []

  clearAllSceneObjects()
  proxy.$modal.msgSuccess('已清空轨迹')
}

// ==================== 复杂塔型建模算法（Step6） ====================

function collectValidPoints() {
  const all = []
  trajectoryCache.value.forEach((cache, robotId) => {
    cache.allPoints.forEach(p => {
      if (p._valid) {
        const local = gpsToLocal(p.longitude, p.latitude, p.altitude)
        const device = deviceMap.value.get(p.deviceId)
        if (device && device.calibration) {
          local.x += device.calibration.offsetX || 0
          local.y += device.calibration.offsetY || 0
          local.z += device.calibration.offsetZ || 0
        }
        all.push({ ...local, robotId, timestamp: p.timestamp })
      }
    })
  })
  return all
}

function sliceLayers(points, thickness = 0.5) {
  if (points.length === 0) return []
  const minY = Math.min(...points.map(p => p.y))
  const maxY = Math.max(...points.map(p => p.y))
  const layers = []
  for (let y = minY; y <= maxY; y += thickness) {
    const layerPoints = points.filter(p => p.y >= y && p.y < y + thickness)
    if (layerPoints.length >= 3) {
      layers.push({ height: y + thickness / 2, points: layerPoints })
    }
  }
  return layers
}

function fitCircleRobust(points2D) {
  if (points2D.length < 3) return null
  let cx = points2D.reduce((s, p) => s + p.x, 0) / points2D.length
  let cz = points2D.reduce((s, p) => s + p.z, 0) / points2D.length
  let radii = points2D.map(p => Math.sqrt((p.x - cx) ** 2 + (p.z - cz) ** 2))
  let meanR = radii.reduce((s, r) => s + r, 0) / radii.length
  let stdR = Math.sqrt(radii.reduce((s, r) => s + (r - meanR) ** 2, 0) / radii.length)
  const inliers = points2D.filter((p, i) => Math.abs(radii[i] - meanR) < 2 * stdR)
  if (inliers.length < 3) return { cx, cz, radius: meanR, inlierCount: points2D.length }
  cx = inliers.reduce((s, p) => s + p.x, 0) / inliers.length
  cz = inliers.reduce((s, p) => s + p.z, 0) / inliers.length
  radii = inliers.map(p => Math.sqrt((p.x - cx) ** 2 + (p.z - cz) ** 2))
  meanR = radii.reduce((s, r) => s + r, 0) / radii.length
  return { cx, cz, radius: meanR, inlierCount: inliers.length }
}

function detectSegments(layers) {
  if (layers.length === 0) return []
  const segments = []
  let currentSeg = { startIdx: 0, endIdx: 0, startH: layers[0].height, endH: layers[0].height }
  for (let i = 1; i < layers.length; i++) {
    const prevR = layers[i - 1].circle?.radius || 0
    const currR = layers[i].circle?.radius || 0
    const dr = Math.abs(currR - prevR)
    if (dr > 0.5 || !layers[i].circle) {
      currentSeg.endIdx = i - 1
      currentSeg.endH = layers[i - 1].height
      segments.push(currentSeg)
      currentSeg = { startIdx: i, endIdx: i, startH: layers[i].height, endH: layers[i].height }
    }
  }
  currentSeg.endIdx = layers.length - 1
  currentSeg.endH = layers[layers.length - 1].height
  segments.push(currentSeg)
  const merged = []
  for (const seg of segments) {
    if (seg.endH - seg.startH < 1 && merged.length > 0) {
      merged[merged.length - 1].endIdx = seg.endIdx
      merged[merged.length - 1].endH = seg.endH
    } else {
      merged.push(seg)
    }
  }
  return merged
}

function buildTowerMesh(layers, segments) {
  if (!scene) return
  const oldTower = scene.getObjectByName('towerModel')
  if (oldTower) {
    oldTower.traverse(child => {
      if (child.geometry) child.geometry.dispose()
      if (child.material) child.material.dispose()
    })
    scene.remove(oldTower)
  }
  const towerGroup = new THREE.Group()
  towerGroup.name = 'towerModel'
  segments.forEach((seg, idx) => {
    const segLayers = layers.slice(seg.startIdx, seg.endIdx + 1).filter(l => l.circle)
    if (segLayers.length === 0) return
    const bottomR = segLayers[0].circle.radius
    const topR = segLayers[segLayers.length - 1].circle.radius
    const segHeight = seg.endH - seg.startH
    const geometry = new THREE.CylinderGeometry(topR, bottomR, segHeight, 32, 1, true)
    const material = new THREE.MeshBasicMaterial({
      color: showWireframe.value ? 0x46ff40 : 0x67c23a,
      wireframe: showWireframe.value,
      transparent: true,
      opacity: showWireframe.value ? 1 : 0.3,
      side: THREE.DoubleSide
    })
    const mesh = new THREE.Mesh(geometry, material)
    mesh.position.y = seg.startH + segHeight / 2
    towerGroup.add(mesh)
    // 顶部圆圈
    const topCircle = new THREE.Line(
      new THREE.BufferGeometry().setFromPoints(
        Array.from({ length: 65 }, (_, i) => {
          const angle = (i / 64) * Math.PI * 2
          return new THREE.Vector3(Math.cos(angle) * topR, seg.endH, Math.sin(angle) * topR)
        })
      ),
      new THREE.LineBasicMaterial({ color: 0x46ff40 })
    )
    towerGroup.add(topCircle)
    // 底部圆圈
    const botCircle = new THREE.Line(
      new THREE.BufferGeometry().setFromPoints(
        Array.from({ length: 65 }, (_, i) => {
          const angle = (i / 64) * Math.PI * 2
          return new THREE.Vector3(Math.cos(angle) * bottomR, seg.startH, Math.sin(angle) * bottomR)
        })
      ),
      new THREE.LineBasicMaterial({ color: 0x46ff40 })
    )
    towerGroup.add(botCircle)
  })
  scene.add(towerGroup)
}

function buildModel() {
  const allPoints = collectValidPoints()
  if (allPoints.length < 10) {
    proxy.$modal.msgWarning('有效轨迹点过少，无法建模')
    return
  }

  const modelType = simParams.value.modelType
  if (modelType === 'facade') {
    buildFacadeModel(allPoints)
  } else {
    buildTowerModel(allPoints)
  }

  // 序列化并打印到控制台
  const modelData = serializeCurrentModel()
  if (modelData) {
    console.log('[ModelExport] 模型序列化数据:', modelData)
  }
}

function buildTowerModel(allPoints) {
  const expectedPoints = simParams.value.height * 5 * simParams.value.robotCount
  dataCompleteness.value = Math.min(100, Math.round((allPoints.length / expectedPoints) * 100))
  const layers = sliceLayers(allPoints, 0.5)
  layers.forEach(layer => {
    const pts = layer.points.map(p => ({ x: p.x, z: p.z }))
    layer.circle = fitCircleRobust(pts)
  })
  const segments = detectSegments(layers)
  buildTowerMesh(layers, segments)
  completenessSegments.value = []
  const segCount = 20
  const hStep = simParams.value.height / segCount
  for (let i = 0; i < segCount; i++) {
    const hMin = i * hStep
    const hMax = (i + 1) * hStep
    const hasLayer = layers.some(l => l.height >= hMin && l.height < hMax && l.circle)
    completenessSegments.value.push({
      color: hasLayer ? '#67c23a' : '#f56c6c',
      percent: 100 / segCount,
      title: `高度段 ${hMin.toFixed(1)}~${hMax.toFixed(1)}m: ${hasLayer ? '有数据' : '缺失'}`
    })
  }
  proxy.$modal.msgSuccess(`塔模型重建完成，共${segments.length}段，数据完整度: ${dataCompleteness.value}%`)
}

function buildFacadeModel(allPoints) {
  const xs = allPoints.map(p => p.x)
  const ys = allPoints.map(p => p.y)
  const zs = allPoints.map(p => p.z)
  const minX = Math.min(...xs), maxX = Math.max(...xs)
  const minY = Math.min(...ys), maxY = Math.max(...ys)
  const minZ = Math.min(...zs), maxZ = Math.max(...zs)

  const width = Math.max(0.1, maxX - minX)
  const height = Math.max(0.1, maxY - minY)
  const depth = Math.max(0.3, maxZ - minZ)

  buildFacadeMesh(width, height, depth, (minX + maxX) / 2, (minY + maxY) / 2, (minZ + maxZ) / 2)

  dataCompleteness.value = Math.min(100, Math.round((allPoints.length / 500) * 100))
  completenessSegments.value = []
  const segCount = 20
  const hStep = height / segCount
  for (let i = 0; i < segCount; i++) {
    const hMin = minY + i * hStep
    const hMax = minY + (i + 1) * hStep
    const hasPoints = allPoints.some(p => p.y >= hMin && p.y < hMax)
    completenessSegments.value.push({
      color: hasPoints ? '#67c23a' : '#f56c6c',
      percent: 100 / segCount,
      title: `高度段 ${hMin.toFixed(1)}~${hMax.toFixed(1)}m: ${hasPoints ? '有数据' : '缺失'}`
    })
  }
  proxy.$modal.msgSuccess(`立面模型重建完成，数据完整度: ${dataCompleteness.value}%`)
}

function buildFacadeMesh(width, height, depth, cx, cy, cz) {
  if (!scene) return
  const oldModel = scene.getObjectByName('towerModel')
  if (oldModel) {
    oldModel.traverse(child => {
      if (child.geometry) child.geometry.dispose()
      if (child.material) child.material.dispose()
    })
    scene.remove(oldModel)
  }
  const group = new THREE.Group()
  group.name = 'towerModel'

  const geometry = new THREE.BoxGeometry(width, height, depth)
  const material = new THREE.MeshBasicMaterial({
    color: showWireframe.value ? 0x46ff40 : 0x67c23a,
    wireframe: showWireframe.value,
    transparent: true,
    opacity: showWireframe.value ? 1 : 0.3,
    side: THREE.DoubleSide
  })
  const mesh = new THREE.Mesh(geometry, material)
  mesh.position.set(cx, cy, cz)
  group.add(mesh)

  const edges = new THREE.EdgesGeometry(geometry)
  const line = new THREE.LineSegments(edges, new THREE.LineBasicMaterial({ color: 0x46ff40 }))
  line.position.set(cx, cy, cz)
  group.add(line)

  scene.add(group)
}

// ==================== 模型序列化与导出（Step9） ====================
function serializeCurrentModel() {
  if (!currentMission.value) return null
  const model = {
    modelId: 'MODEL-' + Date.now(),
    modelName: `${currentMission.value.towerId || 'TOWER'}-${new Date().toISOString().slice(0, 10).replace(/-/g, '')}`,
    missionId: currentMission.value.missionId,
    createTime: new Date().toISOString(),
    modelType: simParams.value.modelType,
    towerProfile: simParams.value.towerProfile,
    towerBase: currentMission.value.towerBaseLocation,
    totalHeight: simParams.value.height,
    dataCompleteness: dataCompleteness.value,
    segments: [],
    trajectories: [],
    devices: [],
    missingSegments: [],
    estimatedSegments: []
  }
  deviceMap.value.forEach((device, deviceId) => {
    model.devices.push({ deviceId, robotId: device.robotId, calibration: device.calibration })
  })
  trajectoryCache.value.forEach((cache, robotId) => {
    const quality = computeTrajectoryQuality(cache)
    model.trajectories.push({
      robotId,
      subTrajectoryCount: cache.subTrajectories.length,
      totalPoints: cache.allPoints.length,
      validPoints: cache.allPoints.filter(p => p._valid).length,
      quality,
      subTrajectories: cache.subTrajectories.map(sub => ({
        subId: sub.subId,
        deviceId: sub.deviceId,
        startTime: sub.startTime,
        endTime: sub.endTime,
        pointCount: sub.pointCount,
        status: sub.status
      })),
      points: cache.allPoints
        .filter(p => p._valid)
        .filter((_, i) => i % 5 === 0)
        .map(p => ({
          sequence: p.sequence,
          timestamp: p.timestamp,
          lng: p.longitude,
          lat: p.latitude,
          alt: p.altitude,
          deviceId: p.deviceId
        }))
    })
  })
  return model
}

function downloadJSON(data, filename) {
  const blob = new Blob([JSON.stringify(data, null, 2)], { type: 'application/json' })
  const url = URL.createObjectURL(blob)
  const a = document.createElement('a')
  a.href = url
  a.download = filename
  a.click()
  URL.revokeObjectURL(url)
}

function loadModelToScene(modelData) {
  if (!scene || !modelData) return
  clearAllSceneObjects()
  if (modelData.trajectories) {
    modelData.trajectories.forEach(traj => {
      if (traj.points) {
        traj.points.forEach(p => {
          appendPointToTrajectory(traj.robotId, {
            robotId: traj.robotId,
            deviceId: p.deviceId || traj.deviceId,
            longitude: p.lng,
            latitude: p.lat,
            altitude: p.alt,
            _valid: true
          })
        })
      }
    })
  }
  // 重建塔模型需要段参数，目前仅回显轨迹
  proxy.$modal.msgSuccess(`已加载模型: ${modelData.modelName}`)
}

// ==================== 历史模型查询 ====================
function getModelList() {
  loading.value = true
  // TODO: Step8 实现后端查询，目前用 Mock 数据
  setTimeout(() => {
    modelList.value = [
      {
        modelId: '1',
        modelName: '1号冷却塔-20260423',
        missionId: 'TOWER-001-20260423',
        modelType: 'tower',
        deviceCount: 2,
        trajectoryCount: 3,
        totalHeight: 80,
        dataCompleteness: 92,
        missingSegmentCount: 1,
        createTime: '2026-04-23 10:30:00'
      }
    ]
    total.value = 1
    loading.value = false
  }, 300)
}

function handleQuery() {
  queryParams.value.pageNum = 1
  getModelList()
}

function resetQuery() {
  proxy.resetForm('queryRef')
  queryParams.value.dateRange = []
  handleQuery()
}

function handleSelectionChange(selection) {
  selectedIds.value = selection.map(item => item.modelId)
}

function handleBatchDelete() {
  proxy.$modal.confirm('确认删除选中的模型吗？').then(() => {
    proxy.$modal.msgSuccess('删除成功')
    getModelList()
  })
}

function handleView3D(row) {
  if (row._raw) {
    loadModelToScene(row._raw)
  } else {
    proxy.$modal.msgWarning('该模型暂无3D数据，请先重建模型')
  }
}

function handleCompare(row) {
  compareBaseId.value = row.modelId
  compareBaseModelName.value = row.modelName
  compareTargetId.value = ''
  compareDialogVisible.value = true
}

function confirmCompare() {
  if (!compareTargetId.value) {
    proxy.$modal.msgError('请选择对比模型')
    return
  }
  compareDialogVisible.value = false
  proxy.$modal.msgSuccess('进入对比模式')
}

function handleDownload(row) {
  const modelData = row._raw || serializeCurrentModel()
  if (modelData) {
    downloadJSON(modelData, `${modelData.modelName || 'tower-model'}.json`)
    proxy.$modal.msgSuccess(`下载模型: ${row.modelName || modelData.modelName}`)
  }
}

function handleDelete(row) {
  proxy.$modal.confirm(`确认删除模型"${row.modelName}"吗？`).then(() => {
    proxy.$modal.msgSuccess('删除成功')
    getModelList()
  })
}

function handleImportModel() {
  // TODO: Step9 实现模型导入
  proxy.$modal.msgSuccess('导入功能待实现')
}

// ==================== 工具函数 ====================
function getStatusType(status) {
  const map = {
    online: 'success',
    offline: 'info',
    error: 'danger',
    charging: 'warning',
    idle: ''
  }
  return map[status] || ''
}

// ==================== 生命周期 ====================
onMounted(() => {
  nextTick(() => {
    initThreeJS()
    getModelList()
  })
})

onBeforeUnmount(() => {
  if (animationId) {
    cancelAnimationFrame(animationId)
  }
  window.removeEventListener('resize', handleResize)
  if (renderer) {
    renderer.dispose()
    canvasContainer.value?.removeChild(renderer.domElement)
  }
  if (controls) {
    controls.dispose()
  }
})
</script>

<style lang="scss" scoped>
.tower-model-builder {
  .canvas-container {
    width: 100%;
    height: 600px;
    position: relative;
    border: 1px solid #dcdfe6;
    border-radius: 4px;
    overflow: hidden;
  }

  .card-header {
    display: flex;
    justify-content: space-between;
    align-items: center;
    font-weight: bold;
    font-size: 16px;
  }

  .header-controls {
    display: flex;
    gap: 8px;
  }

  .control-panel {
    max-height: 600px;
    overflow-y: auto;
  }

  .status-bar {
    display: flex;
    gap: 8px;
    margin-bottom: 10px;
  }

  .robot-list {
    .robot-item {
      padding: 8px;
      margin-bottom: 8px;
      background: #f5f7fa;
      border-radius: 4px;

      .robot-header {
        display: flex;
        align-items: center;
        gap: 8px;
        margin-bottom: 4px;

        .robot-dot {
          width: 10px;
          height: 10px;
          border-radius: 50%;
        }

        .robot-name {
          font-weight: bold;
          flex: 1;
        }
      }

      .robot-info {
        font-size: 12px;
        color: #606266;
        padding-left: 18px;
        line-height: 1.6;
      }
    }
  }

  .action-buttons {
    display: flex;
    flex-wrap: wrap;
    gap: 8px;

    .el-button {
      flex: 1;
      min-width: 80px;
    }
  }

  .completeness-bar {
    .completeness-track {
      display: flex;
      height: 12px;
      border-radius: 6px;
      overflow: hidden;
      background: #e4e7ed;
      margin-bottom: 6px;
    }

    .completeness-seg {
      height: 100%;
      transition: width 0.3s;
    }

    .completeness-label {
      font-size: 12px;
      color: #606266;
      text-align: right;
    }
  }

  .mb8 {
    margin-bottom: 8px;
  }

  :deep(.el-form-item) {
    margin-bottom: 12px;
  }
}
</style>
