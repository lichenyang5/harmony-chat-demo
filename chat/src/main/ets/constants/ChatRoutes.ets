/**
 * chat HAR 内部页面路由常量
 *
 * HMRouter 装饰器要求 pageUrl 必须是同模块常量（编译期静态分析），
 * 所以 chat 模块定义自己的路由常量。
 *
 * 跨模块（entry）想跳转到这些页面，可以直接用字符串字面量，
 * 或者 import ChatRoutes 作为跨模块"公开 API"。
 */
export class ChatRoutes {
  static readonly PAGE_CHAT: string = 'pages/Chat'
  static readonly PAGE_CHAT_HISTORY: string = 'pages/ChatHistory'
}
