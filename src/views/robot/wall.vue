<template>
  <div class="app-container wall-model">
    <el-row :gutter="20">
      <el-col :span="16">
        <el-card class="box-card">
          <template #header>
            <div class="card-header">
              <span>墙面模型</span>
            </div>
          </template>
          <div ref="canvasContainer" class="canvas-container"></div>
        </el-card>
      </el-col>
      <el-col :span="8">
        <el-card class="box-card">
          <template #header>
            <div class="card-header">
              <span>参数设置</span>
            </div>
          </template>
          <el-form :model="paramsForm" label-width="100px">
            <el-divider content-position="left">模型参数</el-divider>
            <el-form-item label="上边长度">
              <el-input-number
                v-model="paramsForm.topLength"
                :min="0.1"
                :max="500"
                :step="0.01"
                :precision="2"
                @change="updateModel"
              />
            </el-form-item>
            <el-form-item label="下边长度">
              <el-input-number
                v-model="paramsForm.bottomLength"
                :min="0.1"
                :max="500"
                :step="0.01"
                :precision="2"
                @change="updateModel"
              />
            </el-form-item>
            <el-form-item label="高度">
              <el-input-number
                v-model="paramsForm.height"
                :min="0.1"
                :max="500"
                :step="0.01"
                :precision="2"
                @change="updateModel"
              />
            </el-form-item>
            
            <el-form-item label="颜色">
              <el-color-picker
                v-model="paramsForm.color"
                @change="updateModel"
              />
            </el-form-item>

            <el-divider content-position="left">坐标系颜色</el-divider>
            <el-form-item label="X柱颜色">
              <el-color-picker
                v-model="paramsForm.xColor"
                @change="updateModel"
              />
            </el-form-item>
            <el-form-item label="Y柱颜色">
              <el-color-picker
                v-model="paramsForm.yColor"
                @change="updateModel"
              />
            </el-form-item>
            <el-form-item label="Z柱颜色">
              <el-color-picker
                v-model="paramsForm.zColor"
                @change="updateModel"
              />
            </el-form-item>

            <el-divider content-position="left">坐标系位置</el-divider>
            <el-form-item label="中心经度">
              <el-input-number v-model="paramsForm.longitude" :precision="6" :step="0.0001" @change="updateModel" />
            </el-form-item>
            <el-form-item label="中心纬度">
              <el-input-number v-model="paramsForm.latitude" :precision="6" :step="0.0001" @change="updateModel" />
            </el-form-item>
            <el-form-item label="中心海拔 (m)">
              <el-input-number v-model="paramsForm.altitude" @change="updateModel" />
            </el-form-item>
            <el-form-item>
              <el-button type="primary" @click="resetParams">重置参数</el-button>
              <el-button type="success" @click="centerModel">居中模型</el-button>
              <el-button type="info" @click="screenshot">截图保存</el-button>
            </el-form-item>
          </el-form>
        </el-card>
      </el-col>
    </el-row>
  </div>
</template>

<script setup>
import * as THREE from 'three'
import { OrbitControls } from 'three/examples/jsm/controls/OrbitControls.js'

const { proxy } = getCurrentInstance()

const canvasContainer = ref(null)
let scene = null
let camera = null
let renderer = null
let controls = null
let wallMesh = null
let labelsGroup = null
let lineMesh = null
let animationId = null

const paramsForm = ref({
  topLength: 10,
  bottomLength: 10,
  height: 5,
  color: '#46ff40',
  xColor: '#ff0000',
  yColor: '#00ff00',
  zColor: '#0000ff',
  latitude: 0,
  longitude: 0,
  altitude: 0,
  wireframe: false
})

function initThreeJS() {
  // 创建场景
  scene = new THREE.Scene()
  scene.background = new THREE.Color(0xf5f5f5)

  // 创建相机
  const width = canvasContainer.value.clientWidth
  const height = canvasContainer.value.clientHeight
  camera = new THREE.PerspectiveCamera(75, width / height, 0.1, 1000)
  camera.position.set(12, 8, 12)
  camera.lookAt(0, paramsForm.value.altitude + paramsForm.value.height / 2, 0)

  // 创建渲染器
  renderer = new THREE.WebGLRenderer({ antialias: true })
  renderer.setSize(width, height)
  renderer.setPixelRatio(window.devicePixelRatio)
  renderer.shadowMap.enabled = true
  renderer.shadowMap.type = THREE.PCFSoftShadowMap
  canvasContainer.value.appendChild(renderer.domElement)

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

  // 更新模型（创建墙面并生成坐标系）
  updateModel()

  // 监听窗口大小变化
  window.addEventListener('resize', handleResize)

  // 开始渲染循环
  animate()
}

function createWall() {
  // 移除旧模型
  if (wallMesh) {
    scene.remove(wallMesh)
    wallMesh.geometry.dispose()
    wallMesh.material.dispose()
  }
  


  // 创建梯形墙面几何体
  const bottomLength = paramsForm.value.bottomLength;
  const topLength = paramsForm.value.topLength;
  const height = paramsForm.value.height;
  const shape = new THREE.Shape();
  shape.moveTo(-bottomLength / 2, 0);
  shape.lineTo(-topLength / 2, height);
  shape.lineTo(topLength / 2, height);
  shape.lineTo(bottomLength / 2, 0);
  shape.lineTo(-bottomLength / 2, 0);
  
  const extrudeSettings = {
    depth: 0,
    bevelEnabled: false
  };
  const geometry = new THREE.ExtrudeGeometry(shape, extrudeSettings);

  // 创建材质 - 不显示填充，只保留边框线和垂直线
  const material = new THREE.MeshBasicMaterial({
    color: new THREE.Color('#46ff40'),
    wireframe: false,
    transparent: true,
    opacity: 0
  })

  // 创建网格
  wallMesh = new THREE.Mesh(geometry, material)
  wallMesh.castShadow = true
  wallMesh.receiveShadow = true
  wallMesh.position.y = paramsForm.value.altitude
  scene.add(wallMesh)
  
  // 创建8条垂直线（与高度线平行，均匀分布在墙面上）
  createVerticalLines()
  
  // 绘制墙面边框线（4条边）
  createBorderLines()
}

// 创建8条垂直线（与高度线平行，均匀分布在墙面上）
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
  
  // 创建8条垂直线的点
  const points = []
  
  // 在墙面上均匀分布8条线（包括左右边界）
  for (let i = 0; i < 8; i++) {
    const t = i / 7 // 0, 1/7, 2/7, ..., 1
    
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
  scene.add(lineMesh)
}

// 绘制墙面边框线（4条边）
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
    endCanvas.width = 128
    endCanvas.height = 64
    // 使用对应轴的颜色
    const axisColor = axis.dx !== 0 ? paramsForm.value.xColor : paramsForm.value.zColor
    endContext.fillStyle = axisColor
    endContext.font = 'bold 18px Arial' // 进一步减小字体到18px
    endContext.textAlign = 'center'
    endContext.fillText(axis.label, 64, 25)
    endContext.font = '16px Arial' // 进一步减小尺寸字体到16px
    endContext.fillText(`${maxRadius.toFixed(2)}`, 64, 50)

    const endTexture = new THREE.CanvasTexture(endCanvas)
    const endSpriteMaterial = new THREE.SpriteMaterial({ map: endTexture, depthTest: false, transparent: true })
    const endSprite = new THREE.Sprite(endSpriteMaterial)
    endSprite.position.set(axis.dx * (maxRadius + 0.15), altitude + 0.1, axis.dz * (maxRadius + 0.15))
    // 根据相机距离调整精灵大小，确保在各种缩放级别都可见
    const distance = camera ? camera.position.distanceTo(endSprite.position) : 10
    const scaleValue = Math.max(0.3, distance * 0.03)  // 进一步减小缩放比例，最小为0.3
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
      canvas.width = 64
      canvas.height = 32
      context.fillStyle = axis.dx !== 0 ? paramsForm.value.xColor : paramsForm.value.zColor
      context.font = '16px Arial'
      context.textAlign = 'center'
      context.textBaseline = 'middle'
      context.fillText(`${i}`, 32, 16)

      const texture = new THREE.CanvasTexture(canvas)
      const spriteMaterial = new THREE.SpriteMaterial({ map: texture, depthTest: false, transparent: true })
      const sprite = new THREE.Sprite(spriteMaterial)
      // 数字位于刻度线末端（Y轴下方）
      sprite.position.set(x, altitude - 0.3, z)
      // 根据相机距离调整精灵大小，确保在各种缩放级别都可见
      const distance = camera ? camera.position.distanceTo(sprite.position) : 10
      const scaleValue = Math.max(0.2, distance * 0.03)  // 进一步减小缩放比例，最小为0.2
      sprite.scale.set(scaleValue * 0.6, scaleValue * 0.3, 1)
      labelsGroup.add(sprite)
    }
  })
}

// 创建高度标尺，包括刻度线和数字标签
function createHeightIndicator() {
  const height = paramsForm.value.height
  const altitude = paramsForm.value.altitude || 0

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
    canvas.width = 128
    canvas.height = 32
    context.fillStyle = paramsForm.value.yColor
    context.font = '16px Arial'
    context.textAlign = 'left'
    context.textBaseline = 'middle'
    // 根据步长决定显示精度
    const labelText = step < 1 ? y.toFixed(1) : `${Math.round(y)}`
    context.fillText(labelText, 10, 16)

    const texture = new THREE.CanvasTexture(canvas)
    const spriteMaterial = new THREE.SpriteMaterial({ map: texture, depthTest: false, transparent: true })
    const sprite = new THREE.Sprite(spriteMaterial)
    sprite.position.set(offset + 0.05, altitude + y, 0.02)
    // 根据相机距离调整精灵大小，确保在各种缩放级别都可见
    const distance = camera ? camera.position.distanceTo(sprite.position) : 10
    const scaleValue = Math.max(0.5, distance * 0.05)  // 随距离缩放，但最小为0.5
    sprite.scale.set(scaleValue, scaleValue * 0.4, 1)
    sprite.renderOrder = 100
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
    canvas.width = 128
    canvas.height = 32
    context.fillStyle = paramsForm.value.yColor
    context.font = 'bold 16px Arial'
    context.textAlign = 'left'
    context.textBaseline = 'middle'
    context.fillText(height.toFixed(2), 10, 16)

    const texture = new THREE.CanvasTexture(canvas)
    const spriteMaterial = new THREE.SpriteMaterial({ map: texture, depthTest: false, transparent: true })
    const sprite = new THREE.Sprite(spriteMaterial)
    sprite.position.set(offset + 0.1, altitude + height, 0.05)
    // 根据相机距离调整精灵大小，确保在各种缩放级别都可见
    const distance = camera ? camera.position.distanceTo(sprite.position) : 10
    const scaleValue = Math.max(0.5, distance * 0.05)  // 随距离缩放，但最小为0.5
    sprite.scale.set(scaleValue * 1.2, scaleValue * 0.4, 1)
    sprite.renderOrder = 100
    labelsGroup.add(sprite)
  }

  // 总高度标签 - 使用Y柱颜色
  const canvas = document.createElement('canvas')
  const context = canvas.getContext('2d')
  canvas.width = 128
  canvas.height = 32
  context.fillStyle = paramsForm.value.yColor
  context.font = 'bold 16px Arial'
  context.textAlign = 'center'
  context.textBaseline = 'middle'
  context.fillText(`H: ${height.toFixed(2)}`, 64, 16)

  const texture = new THREE.CanvasTexture(canvas)
  const spriteMaterial = new THREE.SpriteMaterial({ map: texture, depthTest: false, transparent: true })
  const sprite = new THREE.Sprite(spriteMaterial)
  sprite.position.set(offset, altitude + height + 0.2, 0)
  // 根据相机距离调整精灵大小，确保在各种缩放级别都可见
  const distance = camera ? camera.position.distanceTo(sprite.position) : 10
  const scaleValue = Math.max(0.5, distance * 0.05)  // 随距离缩放，但最小为0.5
  sprite.scale.set(scaleValue * 1.2, scaleValue * 0.3, 1)
  sprite.renderOrder = 100
  labelsGroup.add(sprite)
}

function updateModel() {
  if (scene) {
    createWall()

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
    xColor: '#ff0000',
    yColor: '#00ff00',
    zColor: '#0000ff',
    latitude: 0,
    longitude: 0,
    altitude: 0,
    wireframe: true
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
  link.download = 'wall-model.png'
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

onMounted(() => {
  nextTick(() => {
    initThreeJS()
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
.wall-model {
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

  .el-form {
    padding: 10px;
  }

  .el-form-item {
    margin-bottom: 22px;
  }
}
</style>