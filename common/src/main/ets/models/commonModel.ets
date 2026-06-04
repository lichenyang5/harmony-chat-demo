/**
 * 通用 API 响应包装
 * 从 chatModel 提取出来，所有模块（chat / auth / 后续业务）共用
 */
export class ApiResponse<T> {
  code: number = 0
  message: string = ''
  data: T | null = null
}
