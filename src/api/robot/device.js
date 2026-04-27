import request from '@/utils/request'

// 查询机器人设备信息列表
export function listDevice(query) {
  return request({
    url: '/robot/device/list',
    method: 'get',
    params: query
  })
}

// 查询机器人设备信息详细
export function getDevice(id) {
  return request({
    url: '/robot/device/' + id,
    method: 'get'
  })
}

// 新增机器人设备信息
export function addDevice(data) {
  return request({
    url: '/robot/device',
    method: 'post',
    data: data
  })
}

// 修改机器人设备信息
export function updateDevice(data) {
  return request({
    url: '/robot/device',
    method: 'put',
    data: data
  })
}

// 删除机器人设备信息
export function delDevice(id) {
  return request({
    url: '/robot/device/' + id,
    method: 'delete'
  })
}
