// 模块根目录由 hvigor 生成的构建信息（此 hvigor 版本不支持 'BuildProfile' 裸模块名导入，用相对路径）
import BuildProfile from '../../../../BuildProfile'

/** 记录条数上限，超过后丢弃最旧的 */
const MAX_RECORDS: number = 50

/** 单段文本存储上限（字符数），超出截断，防止超大响应拖垮调试面板渲染 */
const MAX_BODY_LEN: number = 51200

/**
 * SSE 单帧记录
 *
 * 一帧创建后不再修改，所以是普通 class，不需要响应式。
 */
export class NetFrame {
  /** 帧序号，从 1 开始 */
  seq: number = 0
  /** 距请求开始的毫秒偏移 */
  offsetMs: number = 0
  /** chunk / done / raw（raw = JSON 解析失败的原始帧） */
  type: string = ''
  /** data: 后面的原始 JSON 文本 */
  data: string = ''
}

/**
 * 一次网络请求的完整记录
 *
 * 会随请求进行不断更新的字段加 @Trace，
 * 面板打开时能实时看到流式帧一条条进来。
 */
@ObservedV2
export class NetRecord {
  id: number = 0
  /** GET / POST / SSE */
  method: string = ''
  url: string = ''
  startTime: number = 0
  /** 请求体（原始 JSON 字符串） */
  requestBody: string = ''
  /** pending / streaming / done / error */
  @Trace status: string = 'pending'
  @Trace httpCode: number = 0
  @Trace durationMs: number = 0
  /** 普通请求的响应体 */
  @Trace responseBody: string = ''
  /** SSE 帧列表（按到达顺序） */
  @Trace frames: NetFrame[] = []
  /** chunk 拼接出的完整回复文本 */
  @Trace fullText: string = ''
  /** done 帧附带的卡片 JSON（已格式化） */
  @Trace cardJson: string = ''
  @Trace errorMsg: string = ''
}

/**
 * 应用内网络调试监视器（类似浏览器 DevTools 的 Network 面板）
 *
 * 数据流：
 * - HttpUtil / SseHttpUtil 在请求关键节点上报到这里；
 * - NetMonitorOverlay 读取 records 渲染悬浮球 + 面板。
 *
 * release 包 enabled = false：
 * begin() 返回的记录不进 records 列表（孤儿记录，随请求结束被 GC），
 * 调用方不用判空，也几乎没有额外开销。
 */
@ObservedV2
export class NetMonitorState {
  /** 采集开关：跟随构建模式，debug 包默认开 */
  @Trace enabled: boolean = BuildProfile.DEBUG
  /** 调试面板是否展开 */
  @Trace panelVisible: boolean = false
  /** 请求记录，最新的在最前 */
  @Trace records: NetRecord[] = []
  private idSeq: number = 0

  /** 新请求开始 */
  begin(method: string, url: string, requestBody: string): NetRecord {
    const rec = new NetRecord()
    rec.id = ++this.idSeq
    rec.method = method
    rec.url = url
    rec.startTime = Date.now()
    rec.requestBody = NetMonitorState.clip(requestBody)
    if (this.enabled) {
      this.records.unshift(rec)
      if (this.records.length > MAX_RECORDS) {
        this.records.splice(MAX_RECORDS, this.records.length - MAX_RECORDS)
      }
    }
    return rec
  }

  /** 普通请求成功返回 */
  finish(rec: NetRecord, httpCode: number, responseBody: string): void {
    rec.httpCode = httpCode
    rec.responseBody = NetMonitorState.clip(responseBody)
    rec.durationMs = Date.now() - rec.startTime
    rec.status = 'done'
  }

  /** 请求失败（建连失败 / 解析失败 / 流中断） */
  fail(rec: NetRecord, msg: string): void {
    rec.errorMsg = NetMonitorState.clip(msg)
    rec.durationMs = Date.now() - rec.startTime
    rec.status = 'error'
  }

  /** SSE 拿到 HTTP 响应码，进入接收态 */
  onSseStatus(rec: NetRecord, httpCode: number): void {
    rec.httpCode = httpCode
    if (rec.status === 'pending') {
      rec.status = 'streaming'
    }
  }

  /** 记录一帧 SSE 数据 */
  addFrame(rec: NetRecord, type: string, data: string): void {
    const f = new NetFrame()
    f.seq = rec.frames.length + 1
    f.offsetMs = Date.now() - rec.startTime
    f.type = type
    f.data = NetMonitorState.clip(data)
    rec.frames.push(f)
    // 兜底：首帧可能先于 requestInStream 的 then(code) 到达
    if (rec.status === 'pending') {
      rec.status = 'streaming'
    }
  }

  /** 追加流式文本（chunk 拼接） */
  appendText(rec: NetRecord, chunk: string): void {
    if (rec.fullText.length < MAX_BODY_LEN) {
      rec.fullText += chunk
    }
  }

  /** 记录 done 帧附带的卡片 JSON */
  setCard(rec: NetRecord, cardJson: string): void {
    rec.cardJson = NetMonitorState.clip(cardJson)
  }

  /** done 帧里带了业务错误（不改写已收到的内容，只标红状态） */
  noteError(rec: NetRecord, msg: string): void {
    rec.errorMsg = NetMonitorState.clip(msg)
    rec.status = 'error'
  }

  /** SSE 流结束（dataEnd） */
  endStream(rec: NetRecord): void {
    rec.durationMs = Date.now() - rec.startTime
    if (rec.status !== 'error') {
      rec.status = 'done'
    }
  }

  /** 清空所有记录 */
  clear(): void {
    this.records.splice(0, this.records.length)
  }

  /** 超长内容截断 */
  private static clip(s: string): string {
    if (s.length <= MAX_BODY_LEN) {
      return s
    }
    return s.substring(0, MAX_BODY_LEN) + '\n...[已截断，原始长度 ' + s.length.toString() + ' 字符]'
  }
}

let monitorInstance: NetMonitorState | null = null

/**
 * 全局单例
 * common 在整个 App 里是单实例 HAR，entry / chat 模块拿到的都是同一个对象。
 */
export function getNetMonitor(): NetMonitorState {
  if (monitorInstance === null) {
    monitorInstance = new NetMonitorState()
  }
  return monitorInstance
}
