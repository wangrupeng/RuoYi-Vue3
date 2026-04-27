<template>
  <div class="app-container elevation-model" :class="{ 'dark-theme': isDarkTheme }">
    <!-- 3D画布 -->
    <canvas ref="canvasContainer" class="canvas-container"></canvas>

    <!-- 顶部中央坐标系位置 -->
    <div class="float-panel panel-top">
      <el-form :model="paramsForm" label-width="70px" size="small" class="coord-form">
        <el-form-item label="中心经度">
          <el-input-number v-model="paramsForm.longitude" :precision="6" :step="0.0001" @change="updateModel" />
        </el-form-item>
        <el-form-item label="中心纬度">
          <el-input-number v-model="paramsForm.latitude" :precision="6" :step="0.0001" @change="updateModel" />
        </el-form-item>
        <el-form-item label="中心海拔">
          <el-input-number v-model="paramsForm.altitude" @change="updateModel" />
        </el-form-item>
      </el-form>
    </div>

    <!-- 左上角颜色面板 -->
    <div class="float-panel panel-tl">
      <el-form :model="paramsForm" label-width="70px" size="small">
        <el-form-item label="模型颜色">
          <el-color-picker v-model="paramsForm.color" @change="updateModel" />
        </el-form-item>
        <el-form-item label="E-W颜色">
          <el-color-picker v-model="paramsForm.xColor" @change="updateModel" />
        </el-form-item>
        <el-form-item label="U-D颜色">
          <el-color-picker v-model="paramsForm.yColor" @change="updateModel" />
        </el-form-item>
        <el-form-item label="S-N颜色">
          <el-color-picker v-model="paramsForm.zColor" @change="updateModel" />
        </el-form-item>
      </el-form>
    </div>

    <!-- 右上角模型参数面板 -->
    <div class="float-panel panel-tr">
      <div class="panel-section">
        <el-form :model="paramsForm" label-width="80px" size="small">
          <el-form-item label="上边 (m)">
            <el-input-number v-model="paramsForm.topLength" :min="0.1" :max="500" :step="0.01" :precision="2" @change="updateModel" />
          </el-form-item>
          <el-form-item label="下边 (m)">
            <el-input-number v-model="paramsForm.bottomLength" :min="0.1" :max="500" :step="0.01" :precision="2" @change="updateModel" />
          </el-form-item>
          <el-form-item label="高度 (m)">
            <el-input-number v-model="paramsForm.height" :min="0.1" :max="500" :step="0.01" :precision="2" @change="updateModel" />
          </el-form-item>
          <el-form-item label="素线数量">
            <el-input-number v-model="paramsForm.meridianCount" :min="4" :max="25" :step="1" :disabled="paramsForm.showSolid" @change="updateModel" />
          </el-form-item>
          <el-form-item label="线框/实体">
            <el-switch v-model="paramsForm.showSolid" active-text="实体" inactive-text="线框" @change="handleShowSolidChange" />
          </el-form-item>
          <el-form-item label="透明度">
            <el-input-number v-model="paramsForm.opacity" :min="0" :max="1" :step="0.01" :precision="2" :disabled="!paramsForm.showSolid" />
          </el-form-item>
        </el-form>
      </div>
    </div>

    <!-- 右下角按钮 -->
    <div class="float-panel panel-br">
      <div class="btn-group">
        <el-link type="primary" icon="Refresh" @click="resetParams">重置参数</el-link>
        <el-link type="success" icon="Aim" @click="centerModel">居中模型</el-link>
        <el-link type="info" icon="Camera" @click="screenshot">截图保存</el-link>
      </div>
    </div>

    <!-- 左下角坐标轴说明 + 操作指南 -->
    <div class="float-panel panel-bl">
      <div class="axis-legend">
        <div class="legend-item"><span class="color-line" :style="{background: paramsForm.xColor}"></span>E-W (东西向)</div>
        <div class="legend-item"><span class="color-line" :style="{background: paramsForm.yColor}"></span>U-D (上下向)</div>
        <div class="legend-item"><span class="color-line" :style="{background: paramsForm.zColor}"></span>S-N (南北向)</div>
      </div>
      <el-divider class="dark-divider" />
      <div class="guide-list">
        <div class="guide-item"><span class="guide-key">左键拖拽</span>旋转视角</div>
        <div class="guide-item"><span class="guide-key">右键拖拽</span>平移视角</div>
        <div class="guide-item"><span class="guide-key">滚轮</span>缩放</div>
      </div>
    </div>
  </div>
</template>

<script setup>
import * as THREE from 'three'
import { OrbitControls } from 'three/examples/jsm/controls/OrbitControls.js'
import { useDark } from '@vueuse/core'

const { proxy } = getCurrentInstance()

const canvasContainer = ref(null)
let scene = null
let camera = null
let renderer = null
let controls = null
let elevationMesh = null
let labelsGroup = null
let lineMesh = null
let animationId = null

const isDarkTheme = useDark()

watch(isDarkTheme, (val) => {
  if (scene) {
    scene.background = new THREE.Color(val ? 0x1a1a2e : 0xf5f5f5)
  }
})

const paramsForm = ref({
  topLength: 10,
  bottomLength: 10,
  height: 5,
  color: '#46ff40',
  meridianCount: 8,
  xColor: '#ff0000',
  yColor: '#00ff00',
  zColor: '#0000ff',
  latitude: 0,
  longitude: 0,
  altitude: 0,
  showSolid: false,
  opacity: 0
})

function initThreeJS() {
  // 防止重复初始化
  if (scene) return
  // 确保容器有尺寸
  const width = canvasContainer.value.clientWidth
  const height = canvasContainer.value.clientHeight
  if (width === 0 || height === 0) {
    setTimeout(initThreeJS, 100)
    return
  }

  // 创建场景
  scene = new THREE.Scene()
  scene.background = new THREE.Color(isDarkTheme.value ? 0x1a1a2e : 0xf5f5f5)

  // 创建相机
  camera = new THREE.PerspectiveCamera(75, width / height, 0.1, 1000)
  camera.position.set(12, 8, 12)
  camera.lookAt(0, paramsForm.value.altitude + paramsForm.value.height / 2, 0)

  // 创建渲染器（直接绑定到 Vue 管理的 canvas 元素）
  renderer = new THREE.WebGLRenderer({ canvas: canvasContainer.value, antialias: true })
  renderer.setSize(width, height)
  renderer.setPixelRatio(window.devicePixelRatio)
  renderer.shadowMap.enabled = true
  renderer.shadowMap.type = THREE.PCFSoftShadowMap

  // 添加轨道控制器
  controls = new OrbitControls(camera, renderer.domElement)
  controls.enableDamping = true
  controls.dampingFactor = 0.05
  controls.enableZoom = true
  controls.enablePan = true

  // 添加光源
  const ambientLight = new THREE.AmbientLight(0xffffff, 0.6)
  scene.add(ambientLight)

  const directionalLight = new THREE.DirectionalLight(0xffffff, 0.8)
  directionalLight.position.set(10, 10, 10)
  directionalLight.castShadow = true
  directionalLight.shadow.mapSize.width = 2048
  directionalLight.shadow.mapSize.height = 2048
  scene.add(directionalLight)

  // 创建标签组
  labelsGroup = new THREE.Group()
  scene.add(labelsGroup)

  // 更新模型（创建立面并生成坐标系）
  updateModel()

  // 监听窗口大小变化
  window.addEventListener('resize', handleResize)

  // 开始渲染循环
  animate()
}

function createElevation() {
  // 移除旧模型
  if (elevationMesh) {
    scene.remove(elevationMesh)
    elevationMesh.geometry.dispose()
    elevationMesh.material.dispose()
  }
  if (lineMesh) {
    scene.remove(lineMesh)
    lineMesh.geometry.dispose()
    lineMesh.material.dispose()
  }
  const oldBorder = scene.getObjectByName('borderLines')
  if (oldBorder) {
    oldBorder.geometry.dispose()
    oldBorder.material.dispose()
    scene.remove(oldBorder)
  }

  // 创建梯形立面几何体
  const bottomLength = paramsForm.value.bottomLength
  const topLength = paramsForm.value.topLength
  const height = paramsForm.value.height
  const altitude = paramsForm.value.altitude
  const shape = new THREE.Shape()
  shape.moveTo(-bottomLength / 2, 0)
  shape.lineTo(-topLength / 2, height)
  shape.lineTo(topLength / 2, height)
  shape.lineTo(bottomLength / 2, 0)
  shape.lineTo(-bottomLength / 2, 0)

  const extrudeSettings = {
    depth: 0,
    bevelEnabled: false
  }
  const geometry = new THREE.ExtrudeGeometry(shape, extrudeSettings)

  // 创建材质（使用 MeshStandardMaterial 支持光照，产生实体明暗效果）
  const material = new THREE.MeshLambertMaterial({
    color: new THREE.Color(paramsForm.value.color),
    transparent: paramsForm.value.opacity < 1,
    opacity: paramsForm.value.opacity,
    side: THREE.DoubleSide
  })

  // 创建网格
  elevationMesh = new THREE.Mesh(geometry, material)
  elevationMesh.castShadow = true
  elevationMesh.receiveShadow = true
  elevationMesh.position.y = altitude
  elevationMesh.visible = paramsForm.value.showSolid
  scene.add(elevationMesh)

  // 创建垂直线（与高度线平行，均匀分布在立面上）
  createVerticalLines()

  // 绘制立面边框线（4条边）
  createBorderLines()
}

// 创建8条垂直线（与高度线平行，均匀分布在立面上）
function createVerticalLines() {
  // 移除旧线
  if (lineMesh) {
    scene.remove(lineMesh)
    lineMesh.geometry.dispose()
    lineMesh.material.dispose()
  }
  
  const altitude = paramsForm.value.altitude || 0
  const height = paramsForm.value.height
  const topLength = paramsForm.value.topLength
  const bottomLength = paramsForm.value.bottomLength
  
  // 创建垂直线的点
  const points = []
  const meridianCount = paramsForm.value.meridianCount || 8
  
  // 在立面上均匀分布素线（包括左右边界）
  for (let i = 0; i < meridianCount; i++) {
    const t = i / (meridianCount - 1) // 0, 1/(n-1), ..., 1
    
    // 在底部边上插值（从bottomLeft到bottomRight）
    const bottomX = -bottomLength / 2 + bottomLength * t
    // 在顶部边上插值（从topLeft到topRight）
    const topX = -topLength / 2 + topLength * t
    
    // 每条垂直线从底部到顶部
    points.push(new THREE.Vector3(bottomX, altitude, 0))
    points.push(new THREE.Vector3(topX, altitude + height, 0))
  }
  
  const geometry = new THREE.BufferGeometry().setFromPoints(points)
  const material = new THREE.LineBasicMaterial({ 
    color: new THREE.Color('#46ff40'),
    depthTest: false,
    transparent: true,
    opacity: 0.8
  })
  
  lineMesh = new THREE.LineSegments(geometry, material)
  lineMesh.renderOrder = 100
  lineMesh.visible = !paramsForm.value.showSolid
  scene.add(lineMesh)
}

// 绘制立面边框线（4条边）
function createBorderLines() {
  // 移除旧边框
  const oldBorder = scene.getObjectByName('borderLines')
  if (oldBorder) {
    oldBorder.geometry.dispose()
    oldBorder.material.dispose()
    scene.remove(oldBorder)
  }
  
  const altitude = paramsForm.value.altitude || 0
  const height = paramsForm.value.height
  const topLength = paramsForm.value.topLength
  const bottomLength = paramsForm.value.bottomLength
  
  // 梯形四个角
  const bottomLeft = { x: -bottomLength / 2, y: altitude }
  const bottomRight = { x: bottomLength / 2, y: altitude }
  const topLeft = { x: -topLength / 2, y: altitude + height }
  const topRight = { x: topLength / 2, y: altitude + height }
  
  // 4条边：底边、顶边、左边、右边
  const points = [
    // 底边
    new THREE.Vector3(bottomLeft.x, bottomLeft.y, 0),
    new THREE.Vector3(bottomRight.x, bottomRight.y, 0),
    // 顶边
    new THREE.Vector3(topLeft.x, topLeft.y, 0),
    new THREE.Vector3(topRight.x, topRight.y, 0),
    // 左边
    new THREE.Vector3(bottomLeft.x, bottomLeft.y, 0),
    new THREE.Vector3(topLeft.x, topLeft.y, 0),
    // 右边
    new THREE.Vector3(bottomRight.x, bottomRight.y, 0),
    new THREE.Vector3(topRight.x, topRight.y, 0)
  ]
  
  const geometry = new THREE.BufferGeometry().setFromPoints(points)
  const material = new THREE.LineBasicMaterial({ 
    color: new THREE.Color('#46ff40'),
    depthTest: false,
    transparent: true,
    opacity: 0.8
  })
  
  const borderLines = new THREE.LineSegments(geometry, material)
  borderLines.name = 'borderLines'
  borderLines.renderOrder = 100
  borderLines.visible = !paramsForm.value.showSolid
  scene.add(borderLines)
}

// 创建坐标系标签和刻度，包括X轴、Z轴和网格
function createLabelsAndScales() {
  // 清除旧标签
  if (labelsGroup) {
    while(labelsGroup.children.length > 0) {
      const child = labelsGroup.children[0]
      if (child.isMesh || child.isLine || child.isSprite) {
        if (child.geometry) child.geometry.dispose()
        if (child.material) {
          if (Array.isArray(child.material)) {
            child.material.forEach(m => m.dispose())
          } else {
            child.material.dispose()
          }
        }
      }
      labelsGroup.remove(child)
    }
  }

  const altitude = paramsForm.value.altitude || 0
  const maxRadius = Math.max(paramsForm.value.topLength, paramsForm.value.bottomLength) / 2;
  const modelRefSize = Math.max(paramsForm.value.height, maxRadius * 2)

  // 动态确定刻度步长：根据最大半径动态调整
  let scaleSteps = 1
  if (maxRadius <= 0.5) {
    scaleSteps = 0.05
  } else if (maxRadius <= 1) {
    scaleSteps = 0.1
  } else if (maxRadius <= 5) {
    scaleSteps = 0.5
  } else if (maxRadius <= 20) {
    scaleSteps = 1
  } else if (maxRadius <= 100) {
    scaleSteps = 5
  } else {
    scaleSteps = 10
  }
  // 使用原始scaleSteps作为刻度间隔，不进行向上取整
  const tickStep = scaleSteps;

  // 更新网格位置和大小
  if (scene) {
    const oldGrid = scene.getObjectByName('gridHelper')
    if (oldGrid) {
      oldGrid.geometry.dispose()
      oldGrid.material.dispose()
      scene.remove(oldGrid)
    }
      // 网格大小基于模型最大半径的两倍，确保网格范围匹配模型实际尺寸
    const gridHelper = new THREE.GridHelper(maxRadius * 2, maxRadius * 2, 0xcccccc, 0xe5e5e5)
    gridHelper.name = 'gridHelper'
    gridHelper.position.y = altitude
    scene.add(gridHelper)
  }

  // 坐标轴配置 - 使用配置的颜色
  const xAxisColor = new THREE.Color(paramsForm.value.xColor)
  const zAxisColor = new THREE.Color(paramsForm.value.zColor)

  // 1. 绘制 X 轴 (E-W) - 一整条线
  const xLineGeometry = new THREE.BufferGeometry().setFromPoints([
    new THREE.Vector3(-maxRadius, altitude, 0),
    new THREE.Vector3(maxRadius, altitude, 0)
  ])
  const xLineMaterial = new THREE.LineBasicMaterial({ color: xAxisColor, depthTest: false })
  const xLine = new THREE.Line(xLineGeometry, xLineMaterial)
  xLine.renderOrder = 100
  labelsGroup.add(xLine)

  // 2. 绘制 Z 轴 (N-S) - 一整条线
  const zLineGeometry = new THREE.BufferGeometry().setFromPoints([
    new THREE.Vector3(0, altitude, -maxRadius),
    new THREE.Vector3(0, altitude, maxRadius)
  ])
  const zLineMaterial = new THREE.LineBasicMaterial({ color: zAxisColor, depthTest: false })
  const zLine = new THREE.Line(zLineGeometry, zLineMaterial)
  zLine.renderOrder = 100
  labelsGroup.add(zLine)

  // 添加刻度和尺寸标签
  const axes = [
    { dx: 1, dz: 0, label: 'E', color: xAxisColor },
    { dx: -1, dz: 0, label: 'W', color: xAxisColor },
    { dx: 0, dz: 1, label: 'S', color: zAxisColor },
    { dx: 0, dz: -1, label: 'N', color: zAxisColor }
  ]

  axes.forEach(axis => {
    // 轴末端方位和尺寸标签 (去掉 m，精确到两位小数)
    const endCanvas = document.createElement('canvas')
    const endContext = endCanvas.getContext('2d')
    endCanvas.width = 512
    endCanvas.height = 256
    // 使用对应轴的颜色
    const axisColor = axis.dx !== 0 ? paramsForm.value.xColor : paramsForm.value.zColor
    endContext.fillStyle = axisColor
    endContext.font = 'bold 72px Arial' // 进一步减小字体到18px
    endContext.textAlign = 'center'
    endContext.fillText(axis.label, 256, 100)
    endContext.font = '64px Arial' // 进一步减小尺寸字体到16px
    endContext.fillText(`${maxRadius.toFixed(2)}`, 256, 200)

    const endTexture = new THREE.CanvasTexture(endCanvas)
    const endSpriteMaterial = new THREE.SpriteMaterial({ map: endTexture, depthTest: false, transparent: true })
    const endSprite = new THREE.Sprite(endSpriteMaterial)
    endSprite.position.set(axis.dx * (maxRadius + 0.15), altitude + 0.1, axis.dz * (maxRadius + 0.15))
    // 根据模型尺寸调整精灵大小，保持与模型的比例关系
    const scaleValue = Math.max(0.3, modelRefSize * 0.08)
    endSprite.scale.set(scaleValue, scaleValue * 0.5, 1)
    endSprite.renderOrder = 100
    labelsGroup.add(endSprite)

    // 每个刻度步长一个刻度线和数字 (去掉 m)
    // 从0开始生成刻度，包括原点
    for (let i = 0; i <= maxRadius; i += tickStep) {
      const value = i;
      const x = axis.dx * i
      const z = axis.dz * i

      // 刻度线 - 垂直于网格平面（沿Y轴向下延伸）
      let tickStart, tickEnd
      // 刻度线从坐标轴向下（Y轴负方向）延伸，垂直于XZ网格平面
      tickStart = new THREE.Vector3(x, altitude, z)
      tickEnd = new THREE.Vector3(x, altitude - 0.2, z)
      const tickLine = new THREE.Line(
        new THREE.BufferGeometry().setFromPoints([tickStart, tickEnd]),
        new THREE.LineBasicMaterial({ color: axis.color, depthTest: false })
      )
      tickLine.renderOrder = 100
      labelsGroup.add(tickLine)

      // 数字标签 (去掉 m) - 使用对应轴的颜色
      const canvas = document.createElement('canvas')
      const context = canvas.getContext('2d')
      canvas.width = 512
      canvas.height = 256
      context.fillStyle = axis.dx !== 0 ? paramsForm.value.xColor : paramsForm.value.zColor
      context.font = '128px Arial'
      context.textAlign = 'center'
      context.textBaseline = 'middle'
      context.fillText(`${i}`, 256, 128)

      const texture = new THREE.CanvasTexture(canvas)
      const spriteMaterial = new THREE.SpriteMaterial({ map: texture, depthTest: false, transparent: true })
      const sprite = new THREE.Sprite(spriteMaterial)
      // 数字位于刻度线末端（Y轴下方）
      sprite.position.set(x, altitude - 0.3, z)
      // 根据模型尺寸调整精灵大小，保持与模型的比例关系
      const scaleValue = Math.max(0.3, modelRefSize * 0.08)
      sprite.scale.set(scaleValue * 0.6, scaleValue * 0.3, 1)
      labelsGroup.add(sprite)
    }
  })
}

// 创建高度标尺，包括刻度线和数字标签
function createHeightIndicator() {
  const height = paramsForm.value.height
  const altitude = paramsForm.value.altitude || 0
  const modelRefSize = Math.max(height, Math.max(paramsForm.value.topLength, paramsForm.value.bottomLength) / 2)

  // 垂直线移至中心位置 (0, 0) - 使用配置的Y柱颜色
  const offset = 0
  const points = [
    new THREE.Vector3(offset, altitude, 0),
    new THREE.Vector3(offset, altitude + height, 0)
  ]
  const geometry = new THREE.BufferGeometry().setFromPoints(points)
  const material = new THREE.LineBasicMaterial({ color: new THREE.Color(paramsForm.value.yColor), depthTest: false })
  const line = new THREE.Line(geometry, material)
  line.renderOrder = 100
  labelsGroup.add(line)

  // 根据高度范围确定刻度步长
  let step = 1
  if (height <= 0.5) {
    step = 0.05
  } else if (height <= 1) {
    step = 0.1
  } else if (height <= 5) {
    step = 0.5
  } else if (height <= 20) {
    step = 1
  } else if (height <= 100) {
    step = 5
  } else {
    step = 10
  }

  // 计算刻度数
  const tickCount = Math.floor(height / step)

  // 绘制高度刻度
  for (let i = 0; i <= tickCount; i++) {
    const y = i * step
    // 刻度线
    const tickPoints = [
      new THREE.Vector3(offset - 0.2, altitude + y, 0),
      new THREE.Vector3(offset + 0.2, altitude + y, 0)
    ]
    const tickGeometry = new THREE.BufferGeometry().setFromPoints(tickPoints)
    const tickLine = new THREE.Line(tickGeometry, material)
    tickLine.renderOrder = 100
    labelsGroup.add(tickLine)

    // 刻度数字 - 使用Y柱颜色
    const canvas = document.createElement('canvas')
    const context = canvas.getContext('2d')
    canvas.width = 512
    canvas.height = 256
    context.fillStyle = paramsForm.value.yColor
    context.font = '128px Arial'
    context.textAlign = 'center'
    context.textBaseline = 'middle'
    // 根据步长决定显示精度
    const labelText = step < 1 ? y.toFixed(1) : `${Math.round(y)}`
    context.fillText(labelText, 256, 128)

    const texture = new THREE.CanvasTexture(canvas)
    const spriteMaterial = new THREE.SpriteMaterial({ map: texture, depthTest: false, transparent: true })
    const sprite = new THREE.Sprite(spriteMaterial)
    sprite.position.set(offset + 0.05, altitude + y, 0.02)
    // 根据模型尺寸调整精灵大小，保持与模型的比例关系
    const scaleValue = Math.max(0.3, modelRefSize * 0.08)
    sprite.scale.set(scaleValue * 0.6, scaleValue * 0.3, 1)
    labelsGroup.add(sprite)
  }

  // 如果高度不是刻度的整数倍，在顶部添加一个额外刻度
  const lastTick = tickCount * step
  if (height - lastTick > 0.01) {
    // 顶部刻度线
    const tickPoints = [
      new THREE.Vector3(offset - 0.2, altitude + height, 0),
      new THREE.Vector3(offset + 0.2, altitude + height, 0)
    ]
    const tickGeometry = new THREE.BufferGeometry().setFromPoints(tickPoints)
    const tickLine = new THREE.Line(tickGeometry, material)
    tickLine.renderOrder = 100
    labelsGroup.add(tickLine)

    // 顶部刻度数字 - 使用Y柱颜色
    const canvas = document.createElement('canvas')
    const context = canvas.getContext('2d')
    canvas.width = 512
    canvas.height = 256
    context.fillStyle = paramsForm.value.yColor
    context.font = '128px Arial'
    context.textAlign = 'center'
    context.textBaseline = 'middle'
    context.fillText(height.toFixed(2), 256, 128)

    const texture = new THREE.CanvasTexture(canvas)
    const spriteMaterial = new THREE.SpriteMaterial({ map: texture, depthTest: false, transparent: true })
    const sprite = new THREE.Sprite(spriteMaterial)
    sprite.position.set(offset + 0.1, altitude + height, 0.05)
    // 根据模型尺寸调整精灵大小，保持与模型的比例关系
    const scaleValue = Math.max(0.3, modelRefSize * 0.08)
    sprite.scale.set(scaleValue * 0.6, scaleValue * 0.3, 1)
    labelsGroup.add(sprite)
  }

  // U 标签（高度线上端）- 使用Y柱颜色
  const uCanvas = document.createElement('canvas')
  const uContext = uCanvas.getContext('2d')
  uCanvas.width = 512
  uCanvas.height = 256
  uContext.fillStyle = paramsForm.value.yColor
  uContext.font = 'bold 72px Arial'
  uContext.textAlign = 'center'
  uContext.fillText('U', 256, 100)
  uContext.font = '64px Arial'
  uContext.fillText(height.toFixed(2), 256, 200)

  const uTexture = new THREE.CanvasTexture(uCanvas)
  const uSpriteMaterial = new THREE.SpriteMaterial({ map: uTexture, depthTest: false, transparent: true })
  const uSprite = new THREE.Sprite(uSpriteMaterial)
  uSprite.position.set(offset, altitude + height + 0.15, 0.05)
  const uScaleValue = Math.max(0.3, modelRefSize * 0.08)
  uSprite.scale.set(uScaleValue, uScaleValue * 0.5, 1)
  uSprite.renderOrder = 100
  labelsGroup.add(uSprite)

  // D 标签（高度线下端）- 使用Y柱颜色
  const dCanvas = document.createElement('canvas')
  const dContext = dCanvas.getContext('2d')
  dCanvas.width = 512
  dCanvas.height = 256
  dContext.fillStyle = paramsForm.value.yColor
  dContext.font = 'bold 72px Arial'
  dContext.textAlign = 'center'
  dContext.fillText('D', 256, 100)
  dContext.font = '64px Arial'
  dContext.fillText('0.00', 256, 200)

  const dTexture = new THREE.CanvasTexture(dCanvas)
  const dSpriteMaterial = new THREE.SpriteMaterial({ map: dTexture, depthTest: false, transparent: true })
  const dSprite = new THREE.Sprite(dSpriteMaterial)
  dSprite.position.set(offset, altitude - 0.15, 0.05)
  const dScaleValue = Math.max(0.3, modelRefSize * 0.08)
  dSprite.scale.set(dScaleValue, dScaleValue * 0.5, 1)
  dSprite.renderOrder = 100
  labelsGroup.add(dSprite)
}

function updateMaterialOpacity() {
  if (elevationMesh && elevationMesh.material) {
    const opacity = paramsForm.value.opacity
    elevationMesh.material.opacity = opacity
    elevationMesh.material.transparent = opacity < 1
    elevationMesh.material.needsUpdate = true
  }
}

function handleShowSolidChange(val) {
  if (!val) {
    paramsForm.value.opacity = 0
  } else {
    paramsForm.value.opacity = 0.3
  }
  updateModel()
}

function updateModel() {
  if (scene) {
    createElevation()

    // 清除所有标签
    if (labelsGroup) {
      while(labelsGroup.children.length > 0) {
        const child = labelsGroup.children[0];
        if (child.isMesh || child.isLine || child.isSprite) {
          if (child.geometry) child.geometry.dispose();
          if (child.material) {
            if (Array.isArray(child.material)) {
              child.material.forEach(m => m.dispose());
            } else {
              child.material.dispose();
            }
          }
        }
        labelsGroup.remove(child);
      }
    }

    // 重新创建标签（在相机调整后创建，确保正确缩放）
    createLabelsAndScales();
    createHeightIndicator();

  }
}



function resetParams() {
  paramsForm.value = {
    topLength: 10,
    bottomLength: 10,
    height: 5,
    color: '#46ff40',
    meridianCount: 8,
    xColor: '#ff0000',
    yColor: '#00ff00',
    zColor: '#0000ff',
    latitude: 0,
    longitude: 0,
    altitude: 0,
    showSolid: false,
    opacity: 0
  }
  updateModel()
}

// 将模型居中显示，调整相机位置和目标到模型中心
function centerModel() {
  if (scene && controls && camera) {
    const height = paramsForm.value.height;
    const altitude = paramsForm.value.altitude || 0;
    const maxRadius = Math.max(paramsForm.value.topLength, paramsForm.value.bottomLength) / 2;
    const centerHeight = altitude + height / 2;
    
    // 设置相机目标为中心
    controls.target.set(0, centerHeight, 0);
    
    // 计算合适的相机距离
    const minDesiredDist = Math.max(height, maxRadius * 2) * 1.5;
    
    // 调整相机位置
    const direction = new THREE.Vector3(1, 1, 1).normalize();
    camera.position.copy(direction.multiplyScalar(minDesiredDist).add(controls.target));
    
    controls.update();
  }
}

function screenshot() {
  renderer.render(scene, camera)
  const dataURL = renderer.domElement.toDataURL('image/png')
  const link = document.createElement('a')
  link.download = 'elevation-model.png'
  link.href = dataURL
  link.click()
  proxy.$modal.msgSuccess('截图保存成功')
}

function handleResize() {
  if (!camera || !renderer) return
  const width = canvasContainer.value.clientWidth
  const height = canvasContainer.value.clientHeight
  camera.aspect = width / height
  camera.updateProjectionMatrix()
  renderer.setSize(width, height)
  // 确保渲染器像素比正确
  renderer.setPixelRatio(window.devicePixelRatio)
  // 延迟更新标签，避免频繁调用
  setTimeout(() => {
    if (scene) {
      updateModel()
    }
  }, 100)
}

function animate() {
  animationId = requestAnimationFrame(() => {
    animate()
    controls.update()
    renderer.render(scene, camera)
  })
}

watch(() => paramsForm.value.opacity, () => {
  if (scene) {
    updateMaterialOpacity()
  }
})

onMounted(() => {
  nextTick(() => {
    initThreeJS()
  })
})

onActivated(() => {
  if (scene && !animationId) {
    animate()
  }
})

onDeactivated(() => {
  if (animationId) {
    cancelAnimationFrame(animationId)
    animationId = null
  }
})

onBeforeUnmount(() => {
  if (animationId) {
    cancelAnimationFrame(animationId)
    animationId = null
  }
  window.removeEventListener('resize', handleResize)
  if (renderer) {
    renderer.dispose()
    renderer = null
  }
  if (controls) {
    controls.dispose()
    controls = null
  }
  scene = null
  camera = null
})
</script>

<style lang="scss" scoped>
.elevation-model {
  position: relative;
  width: 100%;
  height: calc(100vh - 84px);
  overflow: hidden;

  .canvas-container {
    position: absolute;
    top: 0;
    left: 0;
    width: 100%;
    height: 100%;
  }

  /* 浮动面板通用样式 */
  .float-panel {
    position: absolute;
    background: rgba(255, 255, 255, 0.92);
    border: 1px solid #dcdfe6;
    border-radius: 8px;
    padding: 12px 16px;
    color: #333;
    font-size: 13px;
    backdrop-filter: blur(4px);
    min-width: 220px;
    max-width: 300px;

    :deep(.el-form-item) {
      margin-bottom: 12px;
    }

    :deep(.el-form-item__label) {
      color: #606266;
    }
  }

  .panel-tl {
    top: 16px;
    left: 16px;
    min-width: auto;
    max-width: 135px;
  }

  .panel-tr {
    top: 16px;
    right: 16px;
    max-height: 75vh;
    overflow-y: auto;
  }

  .panel-bl {
    bottom: 16px;
    left: 16px;
    min-width: 160px;

    :deep(.el-divider) {
      margin: 6px 0;
    }
  }

  .panel-br {
    bottom: 16px;
    right: 16px;
    width: auto;
    min-width: auto;
  }

  .panel-top {
    top: 16px;
    left: 50%;
    transform: translateX(-50%);
    min-width: auto;
    max-width: none;

    .coord-form {
      display: flex;
      gap: 16px;
      align-items: center;

      :deep(.el-form-item) {
        margin-bottom: 0;
      }
    }
  }

  /* 坐标轴图例 */
  .axis-legend {
    .legend-item {
      display: flex;
      align-items: center;
      gap: 8px;
      margin-bottom: 6px;
      font-size: 12px;

      .color-line {
        display: inline-block;
        width: 24px;
        height: 3px;
        border-radius: 2px;
      }
    }
  }

  /* 操作指南 */
  .guide-list {
    .guide-item {
      display: flex;
      align-items: center;
      gap: 8px;
      margin-bottom: 6px;
      font-size: 12px;

      .guide-key {
        display: inline-block;
        background: #f0f2f5;
        border: 1px solid #dcdfe6;
        border-radius: 4px;
        padding: 2px 8px;
        color: #606266;
        font-size: 11px;
        white-space: nowrap;
      }
    }
  }

  .btn-group {
    display: flex;
    flex-direction: column;
    gap: 8px;
  }

  /* 深色主题 */
  &.dark-theme {
    background: #0d1117;

    .float-panel {
      background: rgba(22, 27, 34, 0.92);
      border-color: #30363d;
      color: #c9d1d9;

      .panel-title {
        color: #58a6ff;
        border-bottom-color: #30363d;
      }

      .section-title {
        color: #c9d1d9;
      }

      :deep(.el-form-item__label) {
        color: #c9d1d9;
      }

      :deep(.el-divider__text) {
        background: rgba(22, 27, 34, 0.92);
        color: #8b949e;
      }

      :deep(.el-input__wrapper) {
        background: #0d1117;
        box-shadow: 0 0 0 1px #30363d inset;
      }

      :deep(.el-input__inner) {
        color: #c9d1d9;
      }
    }

    .guide-key {
      background: rgba(48, 54, 61, 0.6);
      border-color: rgba(88, 166, 255, 0.3);
    }
  }
}
</style>