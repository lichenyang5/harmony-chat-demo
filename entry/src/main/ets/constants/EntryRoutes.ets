/**
 * Entry 模块内部页面路由常量
 *
 * 为什么不放到 common HAR？
 * HMRouter 的 @HMRouter / @HMInterceptor 装饰器是编译期静态分析，
 * 它只能解析**同模块**内的常量；跨 HAR 引用的常量它解析不到，会报
 * "Unknown variable" 错误。所以路由常量必须定义在所属模块内。
 *
 * 跨模块跳转（比如 entry 里 push 到 chat HAR 的页面）也是同样规则：
 * push 调用是运行时代码，可以 import 任意模块的常量，但目标 HAR 自己
 * 的装饰器也必须用它自己模块的常量。
 */
export class EntryRoutes {
  static readonly PAGE_HOME: string = 'pages/Home'
  static readonly PAGE_LOGIN: string = 'pages/Login'
  static readonly PAGE_CHAT: string = 'pages/Chat'
  static readonly PAGE_CHAT_HISTORY: string = 'pages/ChatHistory'
  static readonly PAGE_PRODUCT_DETAIL: string = 'pages/ProductDetail'
  static readonly DIALOG_LOGIN_PROMPT: string = 'dialogs/LoginPrompt'
}
