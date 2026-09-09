// === Chat HAR 对外公开 API ===

// 唯一对外暴露的 UI 组件：让 entry 的 HomePage 嵌入 Chat Tab
export { ChatTabComp } from './src/main/ets/components/ChatTabComp'

// 关系型数据库，聊天记录存入数据库中，调用这个方法
export { ChatRdb } from './src/main/ets/utils/ChatRdb'
