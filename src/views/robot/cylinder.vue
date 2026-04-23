---------------- <template>
  <div class="app-container cylinder-model">
    <el-row :gutter="20">
      <el-col :span="16">
        <el-card class="box-card">
          <template #header>
            <div class="card-header">
              <span>柱体模型</span>
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
            <el-form-item label="高度 (m)">
              <el-input-number v-model="paramsForm.height" :min="0.1" :max="500" :step="0.01" :precision="2" @change="updateModel" />
            </el-form-item>
            <el-form-item label="上直径 (m)">
              <el-input-number v-model="paramsForm.topDiameter" :min="0.1" :max="500" :step="0.01" :precision="2" @change="updateModel" />
            </el-form-item>
            <el-form-item label="下直径 (m)">
              <el-input-number v-model="paramsForm.bottomDiameter" :min="0.1" :max="500" :step="0.01" :precision="2" @change="updateModel" />
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
let cylinderMesh = null
let lineMesh = null
let labelsGroup = null
let animationId = null

const paramsForm = ref({
  height: 5,
  topDiameter: 4,
  bottomDiameter: 4,
  color: '#46ff40',
  xColor: '#ff0000',
  yColor: '#00ff00',
  zColor: '#0000ff',
  latitude: 0,
  longitude: 0,
  altitude: 0
})

function initThreeJS() {
  // 创建场景
  scene = new THREE.Scene()
  scene.background = new THREE.Color(0xf5f5f5)

  // 创建相机
  const width = canvasContainer.value.clientWidth
  const height = canvasContainer.value.clientHeight
  camera = new THREE.PerspectiveCamera(75, width / height, 0.1, 5000) // 增加远裁剪面以适应 500m 级模型
  camera.position.set(10, 8, 10)
  camera.lookAt(0, paramsForm.value.altitude + paramsForm.value.height / 2, 0)

  // 创建渲染器
  renderer = new THREE.WebGLRenderer({ antialias: true, preserveDrawingBuffer: true })
  renderer.setSize(width, height)
  renderer.setPixelRatio(window.devicePixelRatio)
  canvasContainer.value.appendChild(renderer.domElement)

  // 添加轨道控制器
  controls = new OrbitControls(camera, renderer.domElement)
  controls.enableDamping = true
  controls.dampingFactor = 0.05
  controls.enableZoom = true
  controls.enablePan = true
  controls.maxDistance = 5000 // 增加最大缩放距离以适应大场景
  controls.minDistance = 1
  controls.target.set(0, paramsForm.value.altitude + paramsForm.value.height / 2, 0)

  // 添加光源
  const ambientLight = new THREE.AmbientLight(0xffffff, 0.6)
  scene.add(ambientLight)

  const directionalLight = new THREE.DirectionalLight(0xffffff, 0.8)
  directionalLight.position.set(10, 10, 10)
  scene.add(directionalLight)

  // 创建标签组
  labelsGroup = new THREE.Group()
  scene.add(labelsGroup)

  // 创建柱体 (createCylinder 会处理 gridHelper)
  createCylinder()

  // 监听窗口大小变化
  window.addEventListener('resize', handleResize)

  // 开始渲染循环
  animate()
}

function createCylinder() {
  // 移除旧模型
  if (cylinderMesh) {
    scene.remove(cylinderMesh.topCircle)
    cylinderMesh.topCircle.geometry.dispose()
    cylinderMesh.topCircle.material.dispose()
    scene.remove(cylinderMesh.bottomCircle)
    cylinderMesh.bottomCircle.geometry.dispose()
    cylinderMesh.bottomCircle.material.dispose()
  }
  if (lineMesh) {
    scene.remove(lineMesh)
    lineMesh.geometry.dispose()
    lineMesh.material.dispose()
  }

  const topRadius = paramsForm.value.topDiameter / 2
  const bottomRadius = paramsForm.value.bottomDiameter / 2
  const height = paramsForm.value.height
  const altitude = paramsForm.value.altitude

  // 创建上面的圆圈
  const topCircleGeometry = new THREE.BufferGeometry()
  const topPoints = []
  const segments = 64
  for (let i = 0; i <= segments; i++) {
    const angle = (i / segments) * Math.PI * 2
    const x = Math.cos(angle) * topRadius
    const z = Math.sin(angle) * topRadius
    topPoints.push(new THREE.Vector3(x, altitude + height, z))
  }
  topCircleGeometry.setFromPoints(topPoints)
  const topCircleMaterial = new THREE.LineBasicMaterial({ 
    color: new THREE.Color(paramsForm.value.color),
    linewidth: 2
  })
  const topCircle = new THREE.Line(topCircleGeometry, topCircleMaterial)
  scene.add(topCircle)

  // 创建下面的圆圈
  const bottomCircleGeometry = new THREE.BufferGeometry()
  const bottomPoints = []
  for (let i = 0; i <= segments; i++) {
    const angle = (i / segments) * Math.PI * 2
    const x = Math.cos(angle) * bottomRadius
    const z = Math.sin(angle) * bottomRadius
    bottomPoints.push(new THREE.Vector3(x, altitude, z))
  }
  bottomCircleGeometry.setFromPoints(bottomPoints)
  const bottomCircleMaterial = new THREE.LineBasicMaterial({ 
    color: new THREE.Color(paramsForm.value.color),
    linewidth: 2
  })
  const bottomCircle = new THREE.Line(bottomCircleGeometry, bottomCircleMaterial)
  scene.add(bottomCircle)

  // 保存引用以便更新时移除
  cylinderMesh = { topCircle, bottomCircle }

  // 创建方位标识和刻度
  createLabelsAndScales()
  
  // 创建竖线
  createVerticalLines()
  
  // 创建高度标线
  createHeightIndicator(height)

  // 更新相机焦点，使其始终看向圆柱体中心
  if (controls) {
    controls.target.set(0, altitude + height / 2, 0)
  }
}

// 创建圆柱体侧面的垂直线条
function createVerticalLines() {
  const topRadius = paramsForm.value.topDiameter / 2
  const bottomRadius = paramsForm.value.bottomDiameter / 2
  const height = paramsForm.value.height
  const altitude = paramsForm.value.altitude

  // 8条线的起点和终点
  const angles = [0, Math.PI / 4, Math.PI / 2, Math.PI * 3 / 4, Math.PI, Math.PI * 5 / 4, Math.PI * 3 / 2, Math.PI * 7 / 4]
  const points = []

  angles.forEach(angle => {
    const xTop = Math.cos(angle) * topRadius
    const zTop = Math.sin(angle) * topRadius
    const xBottom = Math.cos(angle) * bottomRadius
    const zBottom = Math.sin(angle) * bottomRadius
    // 每条线从底部到顶部
    points.push(
      new THREE.Vector3(xBottom, altitude, zBottom),
      new THREE.Vector3(xTop, altitude + height, zTop)
    )
  })

  // 创建线段几何体
  const lineGeometry = new THREE.BufferGeometry().setFromPoints(points)
  const lineMaterial = new THREE.LineBasicMaterial({ 
    color: new THREE.Color(paramsForm.value.color),
    linewidth: 2
  })

  lineMesh = new THREE.LineSegments(lineGeometry, lineMaterial)
  scene.add(lineMesh)
}

// 创建高度标尺，包括刻度线和数字标签
function createHeightIndicator() {
  const height = paramsForm.value.height
  const altitude = paramsForm.value.altitude

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

  const altitude = paramsForm.value.altitude
  const maxRadius = Math.max(paramsForm.value.topDiameter, paramsForm.value.bottomDiameter) / 2
  
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

// 重置模型参数到默认值
function resetParams() {
  paramsForm.value = {
    height: 5,
    topDiameter: 4,
    bottomDiameter: 4,
    color: '#46ff40',
    xColor: '#ff0000',
    yColor: '#00ff00',
    zColor: '#0000ff',
    latitude: 0,
    longitude: 0,
    altitude: 0
  }
  updateModel()
}

// 将模型居中显示，调整相机位置和目标到模型中心
function centerModel() {
  if (scene && controls && camera) {
    const height = paramsForm.value.height;
    const altitude = paramsForm.value.altitude;
    const maxRadius = Math.max(paramsForm.value.topDiameter, paramsForm.value.bottomDiameter) / 2;
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

// 更新模型显示，包括创建圆柱体、调整相机和更新标签
function updateModel() {
  if (scene) {
    createCylinder()

    // 动态调整相机观察点和距离
    const height = paramsForm.value.height;
    const altitude = paramsForm.value.altitude;
    const maxRadius = Math.max(paramsForm.value.topDiameter, paramsForm.value.bottomDiameter) / 2;
    const centerHeight = altitude + height / 2;

    if (controls) {
      controls.target.set(0, centerHeight, 0);

      // 如果模型很大，且相机离得太近，自动推开相机
      const dist = camera.position.distanceTo(new THREE.Vector3(0, centerHeight, 0));
      const minDesiredDist = Math.max(height, maxRadius * 2) * 1.5;

      if (dist < minDesiredDist * 0.5) {
        // 计算方向并推开
        const direction = new THREE.Vector3().subVectors(camera.position, controls.target).normalize();
        if (direction.length() === 0) direction.set(1, 1, 1).normalize();
        camera.position.copy(direction.multiplyScalar(minDesiredDist).add(controls.target));
      }

      controls.update();
    }

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

// 截取当前视图并保存为PNG图片
function screenshot() {
  renderer.render(scene, camera)
  const dataURL = renderer.domElement.toDataURL('image/png')
  const link = document.createElement('a')
  link.download = 'cylinder-model.png'
  link.href = dataURL
  link.click()
  proxy.$modal.msgSuccess('截图保存成功')
}

// 处理窗口大小变化，调整渲染器尺寸
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

// 动画循环，持续更新渲染
function animate() {
  animationId = requestAnimationFrame(() => {
    animate()
    controls.update()
    renderer.render(scene, camera)
  })
}

// 组件挂载时初始化Three.js场景
onMounted(() => {
  nextTick(() => {
    initThreeJS()
  })
})

// 组件卸载前清理Three.js资源
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
.cylinder-model {
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
