// entry/src/main/ets/mock/ChatMockApi.ets

import { ChatMessage } from '../models/ChatModel'

const mockHistoryList: ChatMessage[] = [
  {
    id: 1,
    role: 'user',
    content: '历史问题 1：HMRouter 是什么？',
    createTime: Date.now() - 100000
  },
  {
    id: 2,
    role: 'assistant',
    content: 'HMRouter 是鸿蒙开发中常用的路由库，可以用来管理页面跳转、参数传递和页面注册。',
    createTime: Date.now() - 99000
  },
  {
    id: 3,
    role: 'user',
    content: '历史问题 2：push 和 replace 有什么区别？',
    createTime: Date.now() - 98000
  },
  {
    id: 4,
    role: 'assistant',
    content: 'push 会把新页面压入页面栈，replace 会替换当前页面，所以返回行为不同。',
    createTime: Date.now() - 97000
  },
  {
    id: 5,
    role: 'user',
    content: '历史问题 3：@Local 是干什么的？',
    createTime: Date.now() - 96000
  },
  {
    id: 6,
    role: 'assistant',
    content: '@Local 是组件内部状态，状态变化后会驱动当前组件重新渲染。',
    createTime: Date.now() - 95000
  },
  {
    id: 7,
    role: 'user',
    content: '历史问题 4：ForEach 怎么用？',
    createTime: Date.now() - 94000
  },
  {
    id: 8,
    role: 'assistant',
    content: 'ForEach 通常用于列表渲染，需要传入数据源、渲染函数和唯一 key。',
    createTime: Date.now() - 93000
  },
  {
    id: 9,
    role: 'user',
    content: '历史问题 5：组件生命周期有哪些？',
    createTime: Date.now() - 92000
  },
  {
    id: 10,
    role: 'assistant',
    content: '常用生命周期有 aboutToAppear 和 aboutToDisappear，分别对应组件出现前和销毁前。',
    createTime: Date.now() - 91000
  },
  {
    id: 11,
    role: 'user',
    content: '历史问题 6：如何模拟接口请求？',
    createTime: Date.now() - 90000
  },
  {
    id: 12,
    role: 'assistant',
    content: '可以用 Promise 配合 setTimeout 模拟请求延迟，返回 mock 假数据。',
    createTime: Date.now() - 89000
  },
  {
    id: 13,
    role: 'user',
    content: '历史问题 7：聊天列表怎么做？',
    createTime: Date.now() - 88000
  },
  {
    id: 14,
    role: 'assistant',
    content: '聊天列表可以用 List + ForEach 渲染，通过 role 区分用户消息和 AI 消息。',
    createTime: Date.now() - 87000
  },
  {
    id: 15,
    role: 'user',
    content: '历史问题 8：输入框怎么绑定状态？',
    createTime: Date.now() - 86000
  },
  {
    id: 16,
    role: 'assistant',
    content: '可以用 TextInput 的 text 属性展示值，用 onChange 监听输入并更新 @Local 状态。',
    createTime: Date.now() - 85000
  },
  {
    id: 17,
    role: 'user',
    content: '历史问题 9：如何做打字机效果？',
    createTime: Date.now() - 84000
  },
  {
    id: 18,
    role: 'assistant',
    content: '打字机效果本质是定时器逐字追加内容，每次追加后更新状态触发 UI 刷新。',
    createTime: Date.now() - 83000
  },
  {
    id: 19,
    role: 'user',
    content: '历史问题 10：如何加载更多历史？',
    createTime: Date.now() - 82000
  },
  {
    id: 20,
    role: 'assistant',
    content: '可以监听列表到达顶部事件，然后请求更早的数据，再拼接到当前列表前面。',
    createTime: Date.now() - 81000
  }
]

export class ChatMockApi {
  /**
   * 模拟分页获取历史消息
   * offset：已经加载过多少条
   * limit：本次加载多少条
   *
   * 例如：
   * offset = 0, limit = 10，获取最近 10 条
   * offset = 10, limit = 5，获取更早的 5 条
   */
  static getHistoryList(offset: number, limit: number): Promise<ChatMessage[]> {
    return new Promise((resolve) => {
      setTimeout(() => {
        const total: number = mockHistoryList.length
        const end: number = total - offset
        const start: number = Math.max(0, end - limit)

        if (end <= 0) {
          resolve([])
          return
        }

        resolve(mockHistoryList.slice(start, end))
      }, 500)
    })
  }

  /**
   * 模拟发送消息给 AI
   */
  static sendMessage(content: string): Promise<ChatMessage> {
    console.info('mock 接口收到用户问题：' + content)

    return new Promise((resolve) => {
      setTimeout(() => {
        resolve({
          id: new Date().getTime(),
          role: 'assistant',
          content: '你好，我是 AI 的 mock 固定回复。我已经收到你的问题了，这里正在模拟接口返回和打字机输出效果。',
          createTime: new Date().getTime()
        })
      }, 500)
    })
  }
}