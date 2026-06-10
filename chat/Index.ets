// === Chat HAR 对外公开 API ===

// 唯一对外暴露的 UI 组件：让 entry 的 HomePage 嵌入 Chat Tab
export { ChatTabComp } from './src/main/ets/components/ChatTabComp'

// 路由常量：跨模块跳转时可以 import
export { ChatRoutes } from './src/main/ets/constants/ChatRoutes'

// 跨页面通信：让 entry 监听"待加载会话"信号以触发 Tab 切换
export { ChatLoadState, getChatLoadState } from './src/main/ets/viewmodel/ChatLoadState'

// 关系型数据库，聊天记录存入数据库中，调用这个方法
export { ChatRdb } from './src/main/ets/utils/ChatRdb'