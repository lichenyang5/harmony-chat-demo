import { hilog } from '@kit.PerformanceAnalysisKit'

// 业务域，团队内分段。0x0001 给 demo 整体用就行
const DOMAIN: number = 0x0001
const MAX_LEN: number = 600

export class LogUtil {
  /** 调试日志，release 包默认不输出 */
  static d(tag: string, msg: string): void {
    LogUtil.split(msg).forEach((s) => hilog.debug(DOMAIN, tag, '%{public}s', s))
  }

  /** 普通信息 */
  static i(tag: string, msg: string): void {
    LogUtil.split(msg).forEach((s) => hilog.info(DOMAIN, tag, '%{public}s', s))
  }

  /** 警告 */
  static w(tag: string, msg: string): void {
    LogUtil.split(msg).forEach((s) => hilog.warn(DOMAIN, tag, '%{public}s', s))
  }

  /** 错误 + 可选异常栈 */
  static e(tag: string, msg: string, err?: Error): void {
    const body = err ? `${msg} | ${err.message}\n${err.stack ?? ''}` : msg
    LogUtil.split(body).forEach((s) => hilog.error(DOMAIN, tag, '%{public}s', s))
  }

  /** 含用户隐私的日志：调用方传 format 用 %{private}s，release 自动脱敏 */
  static iPrivate(tag: string, format: string, sensitive: string): void {
    hilog.info(DOMAIN, tag, format, sensitive)
  }

  /** 长字符串切段，避免被 HiLog 系统上限截断 */
  private static split(s: string): string[] {
    if (s.length <= MAX_LEN) return [s]
    const arr: string[] = []
    for (let i = 0; i < s.length; i += MAX_LEN) {
      arr.push(s.slice(i, i + MAX_LEN))
    }
    return arr
  }
}