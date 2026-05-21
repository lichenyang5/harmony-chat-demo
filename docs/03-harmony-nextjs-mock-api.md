# 鸿蒙聊天 Demo 练习 03：接入 Next.js 后端接口，实现真机前后端联调

## 一、本次分支

```bash
feat/server-init
```

## 二、本次目标

本次在原有聊天 Demo 的基础上，把前端写死的模拟回复，改造成调用自己写的 Next.js 后端接口。

本次完成的核心流程：

1. 在鸿蒙项目中新增 `server` 后端目录。
2. 使用 Next.js 初始化后端项目。
3. 新增 `GET /api/ping` 测试接口。
4. 新增 `POST /api/chat` 模拟聊天接口。
5. 鸿蒙前端封装 HTTP 请求。
6. 聊天页面调用后端接口。
7. 真机通过局域网 IP 请求电脑上的后端服务。
8. 页面展示后端返回的 assistant 回复。

最终效果：

```txt
用户输入消息
↓
鸿蒙前端先展示用户消息
↓
调用 Next.js 后端 POST /api/chat
↓
后端返回模拟 assistant 回复
↓
鸿蒙页面展示后端返回内容
```

本次还没有接入 MySQL，也没有接入真实 AI，只是先跑通最重要的前后端通信链路。

## 三、涉及文件

```txt
server/app/api/ping/route.ts
server/app/api/chat/route.ts
entry/src/main/ets/constants/ApiConstants.ets
entry/src/main/ets/api/ChatApi.ets
entry/src/main/ets/pages/Setting.ets
entry/src/main/module.json5
```

## 四、为什么要加后端

之前聊天 Demo 的回复都是前端自己模拟的：

```txt
用户输入
↓
前端创建用户消息
↓
前端创建 AI 假回复
↓
更新 chatList
```

这种方式适合练习页面布局、状态更新、列表渲染和滚动到底部，但它不是真实业务。

真实业务中，前端通常只负责输入和展示，消息要发送给后端，由后端处理后再返回结果。

所以本次把聊天流程改造成：

```txt
鸿蒙前端
↓
HTTP 请求
↓
Next.js 后端
↓
JSON 响应
↓
鸿蒙页面更新
```

这样后续才能继续扩展 MySQL、历史消息、会话列表和真实 AI 接口。

## 五、项目结构变化

本次新增了一个 `server` 目录，专门放 Next.js 后端代码。

```txt
MyApplication
├── entry
│   └── src/main/ets
│       ├── api
│       │   └── ChatApi.ets
│       ├── constants
│       │   └── ApiConstants.ets
│       └── pages
│           └── Setting.ets
│
├── server
│   └── app
│       └── api
│           ├── ping
│           │   └── route.ts
│           └── chat
│               └── route.ts
│
└── docs
```

现在这个项目变成了：

```txt
entry：鸿蒙前端
server：Next.js 后端
docs：复盘文档
```

这种结构适合练习全栈 Demo，因为前后端代码都在一个仓库里，提交记录也比较完整。

## 六、初始化 Next.js 后端

在项目根目录执行：

```bash
npx create-next-app@latest server
```

初始化时选择：

```txt
TypeScript: Yes
ESLint: Yes
Tailwind CSS: No
src directory: No
App Router: Yes
Turbopack: Yes 或 No 都可以
Import alias: No
```

进入后端目录启动：

```bash
cd server
npm run dev
```

启动成功后，终端会显示类似：

```txt
Local:   http://localhost:3000
Network: http://192.168.20.8:3000
```

其中：

```txt
localhost:3000
```

是电脑自己访问。

```txt
192.168.20.8:3000
```

是局域网内其他设备访问，比如鸿蒙真机。

## 七、Node 版本问题

初始化 Next.js 时遇到过 Node 版本问题：

```txt
You are using Node.js 18.20.1.
For Next.js, Node.js version ">=20.9.0" is required.
```

解决方式是用 nvm 安装 Node 20：

```bash
nvm install 20.18.1
nvm use 20.18.1
node -v
```

正常结果：

```txt
v20.18.1
```

后来发现 DevEco Studio 终端里还是 Node 18，因为 DevEco Studio 自带了 Node，并且路径排在前面。

检查命令：

```powershell
where.exe node
```

看到：

```txt
C:\Program Files\Huawei\DevEco Studio\tools\node\node.exe
C:\Program Files\nodejs\node.exe
```

说明 DevEco 自带 Node 抢了优先级。

本次最终采用的方式是：

```txt
DevEco Studio 写鸿蒙代码
外部 PowerShell 跑 Next.js 后端
```

这样最稳定，不影响后续开发。

## 八、新增 ping 测试接口

为了先确认后端能不能正常访问，新增了一个最小测试接口。

文件：

```txt
server/app/api/ping/route.ts
```

代码：

```ts
import { NextResponse } from 'next/server'

export async function GET() {
  return NextResponse.json({
    message: 'pong',
    service: 'harmony-chat-demo-server'
  })
}
```

浏览器访问：

```txt
http://localhost:3000/api/ping
```

或者局域网访问：

```txt
http://192.168.20.8:3000/api/ping
```

正常返回：

```json
{
  "message": "pong",
  "service": "harmony-chat-demo-server"
}
```

这个接口主要用于验证：

1. Next.js 服务是否启动成功。
2. `app/api` 路由是否正常。
3. 后端是否可以返回 JSON。
4. 真机是否能访问电脑后端。

## 九、新增聊天接口

本次新增的聊天接口是：

```txt
POST /api/chat
```

文件：

```txt
server/app/api/chat/route.ts
```

完整代码：

```ts
import { NextResponse } from 'next/server'

type ChatRequestBody = {
  conversationId?: number
  content?: string
}

export async function POST(request: Request) {
  try {
    const body = await request.json() as ChatRequestBody

    const content = String(body.content || '').trim()
    const conversationId = body.conversationId || Date.now()

    if (!content) {
      return NextResponse.json(
        {
          code: 400,
          message: '消息内容不能为空'
        },
        {
          status: 400
        }
      )
    }

    const now = Date.now()

    return NextResponse.json({
      code: 0,
      message: 'success',
      data: {
        conversationId,
        messages: [
          {
            id: now,
            role: 'user',
            content,
            createTime: now
          },
          {
            id: now + 1,
            role: 'assistant',
            content: `这是 Next.js 后端返回的模拟回复：${content}`,
            createTime: now + 1
          }
        ]
      }
    })
  } catch {
    return NextResponse.json(
      {
        code: 500,
        message: '服务端解析请求失败'
      },
      {
        status: 500
      }
    )
  }
}
```

## 十、聊天接口数据结构

请求体：

```json
{
  "content": "你好"
}
```

响应体：

```json
{
  "code": 0,
  "message": "success",
  "data": {
    "conversationId": 1779345862737,
    "messages": [
      {
        "id": 1779345862737,
        "role": "user",
        "content": "你好",
        "createTime": 1779345862737
      },
      {
        "id": 1779345862738,
        "role": "assistant",
        "content": "这是 Next.js 后端返回的模拟回复：你好",
        "createTime": 1779345862738
      }
    ]
  }
}
```

这里统一使用：

```ts
role: 'user' | 'assistant'
```

而不是之前的：

```ts
type: 'user' | 'ai'
```

原因是 `role` 更接近真实聊天接口设计，后续接入真实 AI 接口时也更容易对齐。

## 十一、测试聊天接口

PowerShell 测试：

```powershell
Invoke-RestMethod `
  -Uri "http://localhost:3000/api/chat" `
  -Method POST `
  -ContentType "application/json" `
  -Body '{"content":"你好，后端"}'
```

如果要看完整 JSON：

```powershell
$response = Invoke-RestMethod `
  -Uri "http://localhost:3000/api/chat" `
  -Method POST `
  -ContentType "application/json" `
  -Body '{"content":"你好，后端"}'

$response | ConvertTo-Json -Depth 10
```

局域网地址也要测试：

```powershell
$response = Invoke-RestMethod `
  -Uri "http://192.168.20.8:3000/api/chat" `
  -Method POST `
  -ContentType "application/json" `
  -Body '{"content":"你好，局域网后端"}'

$response | ConvertTo-Json -Depth 10
```

如果这个也能成功，说明后端接口和局域网访问都没问题。

## 十二、鸿蒙前端接口地址

新增文件：

```txt
entry/src/main/ets/constants/ApiConstants.ets
```

代码：

```ts
export const API_BASE_URL: string = 'http://192.168.20.8:3000'
```

这里不能写：

```ts
export const API_BASE_URL: string = 'http://localhost:3000'
```

因为真机里的 `localhost` 指的是手机自己，不是电脑。

所以真机访问电脑上的后端服务时，要写电脑的局域网 IP。

## 十三、鸿蒙 HTTP 请求封装

新增文件：

```txt
entry/src/main/ets/api/ChatApi.ets
```

代码：

```ts
import { http } from '@kit.NetworkKit'
import { API_BASE_URL } from '../constants/ApiConstants'

export interface ChatRequest {
  conversationId?: number
  content: string
}

export interface ChatMessageDTO {
  id: number
  role: 'user' | 'assistant'
  content: string
  createTime: number
}

export interface ChatResponseData {
  conversationId: number
  messages: ChatMessageDTO[]
}

export interface ChatResponse {
  code: number
  message: string
  data: ChatResponseData
}

interface RequestHeader {
  'Content-Type': string
}

export function sendChatMessage(params: ChatRequest): Promise<ChatResponse> {
  return new Promise((resolve, reject) => {
    const httpRequest = http.createHttp()

    const requestHeader: RequestHeader = {
      'Content-Type': 'application/json'
    }

    const requestOptions: http.HttpRequestOptions = {
      method: http.RequestMethod.POST,
      header: requestHeader,
      extraData: JSON.stringify(params),
      connectTimeout: 10000,
      readTimeout: 10000
    }

    const requestUrl: string = `${API_BASE_URL}/api/chat`

    console.info(`chat api request url: ${requestUrl}`)
    console.info(`chat api request body: ${JSON.stringify(params)}`)

    httpRequest.request(requestUrl, requestOptions, (err, data) => {
      httpRequest.destroy()

      if (err) {
        console.error(`chat api request error: ${JSON.stringify(err)}`)
        reject(err)
        return
      }

      try {
        const rawResult: string = String(data.result)

        console.info(`chat api response code: ${data.responseCode}`)
        console.info(`chat api response result: ${rawResult}`)

        const result: ChatResponse = JSON.parse(rawResult) as ChatResponse
        resolve(result)
      } catch (parseError) {
        console.error(`chat api parse error: ${JSON.stringify(parseError)}`)
        reject(parseError)
      }
    })
  })
}
```

这个文件的作用是把请求细节封装起来，页面里不用直接写 `http.createHttp()`。

主要流程：

```txt
创建 httpRequest
↓
配置 POST 请求
↓
发送 JSON 数据
↓
解析后端返回结果
↓
销毁 httpRequest
```

## 十四、配置网络权限

鸿蒙 App 访问网络，需要在：

```txt
entry/src/main/module.json5
```

中添加网络权限：

```json5
"requestPermissions": [
  {
    "name": "ohos.permission.INTERNET"
  }
]
```

没有这个权限，App 可能无法正常发起 HTTP 请求。

## 十五、修改聊天页面

`Setting.ets` 的发送逻辑从“前端生成假回复”改成了“调用后端接口”。

核心流程：

```txt
读取输入内容
↓
先展示用户消息
↓
调用 sendChatMessage
↓
取出后端返回的 assistant 消息
↓
追加到 chatList
↓
滚动到底部
```

消息结构改为：

```ts
interface ChatItem {
  id: number
  role: 'user' | 'assistant'
  content: string
  createTime: number
}
```

核心发送方法：

```ts
async sendMessage(): Promise<void> {
  const content: string = this.inputValue.trim()

  if (!content || this.isSending) {
    return
  }

  this.isSending = true
  this.inputValue = ''

  const now: number = Date.now()

  const tempUserMessage: ChatItem = {
    id: now,
    role: 'user',
    content: content,
    createTime: now
  }

  this.chatList = this.chatList.concat([tempUserMessage])
  this.scrollToBottom()

  try {
    const requestParams: ChatRequest = {
      content: content
    }

    if (this.conversationId > 0) {
      requestParams.conversationId = this.conversationId
    }

    const res = await sendChatMessage(requestParams)

    this.conversationId = res.data.conversationId

    const assistantMessages: ChatItem[] = res.data.messages
      .filter((item: ChatMessageDTO) => item.role === 'assistant')
      .map((item: ChatMessageDTO): ChatItem => {
        const message: ChatItem = {
          id: item.id,
          role: item.role,
          content: item.content,
          createTime: item.createTime
        }

        return message
      })

    this.chatList = this.chatList.concat(assistantMessages)
    this.scrollToBottom()
  } catch (error) {
    const errorNow: number = Date.now()

    const errorMessage: ChatItem = {
      id: errorNow,
      role: 'assistant',
      content: '请求后端失败，请检查 Next.js 服务是否启动，以及接口地址是否正确。',
      createTime: errorNow
    }

    this.chatList = this.chatList.concat([errorMessage])
    this.scrollToBottom()
  } finally {
    this.isSending = false
  }
}
```

这里前端只取后端返回的 `assistant` 消息，是因为用户消息已经提前展示了，如果再展示后端返回的 `user` 消息，就会重复。

## 十六、ArkTS 对象字面量报错

开发时遇到过这个报错：

```txt
Object literal must correspond to some explicitly declared class or interface
```

原因是 ArkTS 对对象字面量比较严格，不能随便传匿名对象。

不推荐：

```ts
const res = await sendChatMessage({
  conversationId: this.conversationId || undefined,
  content
})
```

推荐：

```ts
const requestParams: ChatRequest = {
  content: content
}

if (this.conversationId > 0) {
  requestParams.conversationId = this.conversationId
}

const res = await sendChatMessage(requestParams)
```

这次学到的是：ArkTS 比普通 TypeScript 更严格，写对象时最好先定义 interface，再用明确类型的变量接住。

## 十七、真机请求超时问题

真机调试时遇到过请求失败，日志是：

```txt
chat api request error: {"code":2300028,"message":"Operation timeout"}
```

这说明请求发出去了，但是连接目标地址超时。

一开始电脑浏览器访问：

```txt
http://localhost:3000/api/ping
```

是正常的，但这只能证明电脑自己能访问后端。

真机要单独测试：

```txt
http://192.168.20.8:3000/api/ping
```

而且要用手机浏览器测试这个地址。

如果手机浏览器打不开，就说明不是鸿蒙代码问题，而是网络问题。

可能原因：

1. 手机和电脑不在同一个 WiFi。
2. Windows 防火墙拦截了 Node.js。
3. 路由器开启了设备隔离。
4. 后端没有正常启动。
5. 前端接口地址写错了。

最终真机可以访问 `ping` 接口后，App 请求 `/api/chat` 也成功了。

## 十八、localhost 和局域网 IP 的区别

这次最大的坑是 `localhost`。

```txt
电脑里的 localhost = 电脑自己
手机里的 localhost = 手机自己
```

所以真机里不能写：

```txt
http://localhost:3000
```

要写：

```txt
http://电脑局域网IP:3000
```

本次是：

```txt
http://192.168.20.8:3000
```

这是移动端真机联调很常见的问题。

## 十九、本次知识点总结

本次练习涉及以下知识点：

1. 在鸿蒙项目中新增 Next.js 后端目录。
2. 使用 Next.js App Router 编写接口。
3. `GET /api/ping` 测试接口。
4. `POST /api/chat` 聊天接口。
5. PowerShell 测试 POST 请求。
6. 鸿蒙 `http.createHttp()` 请求封装。
7. `module.json5` 配置网络权限。
8. 真机访问电脑后端不能使用 `localhost`。
9. 使用局域网 IP 进行前后端联调。
10. ArkTS 对对象字面量类型要求更严格。
11. 使用 `role: user | assistant` 统一前后端消息结构。
12. 使用日志定位请求失败原因。
13. `Operation timeout` 的排查思路。

## 二十、面试表达

这个功能可以这样说：

> 我在鸿蒙聊天 Demo 中把原本前端写死的模拟回复，改造成了调用自己写的 Next.js 后端接口。后端使用 Next.js App Router 提供 `POST /api/chat` 接口，接收用户输入的 `content`，并返回一条模拟的 `assistant` 消息。鸿蒙侧单独封装了 `ChatApi.ets`，使用 `@kit.NetworkKit` 的 `http.createHttp()` 发起 POST 请求，并把响应解析成统一的消息结构。真机调试时，我还处理了 `localhost` 无法访问电脑后端的问题，改用电脑局域网 IP，并通过手机浏览器访问 `ping` 接口排查网络连通性。这个功能让我完整练习了鸿蒙前端到 Next.js 后端的请求链路、接口封装、类型定义和真机网络调试。

## 二十一、本次提交命令

```bash
git add server/app/api/ping/route.ts
git add server/app/api/chat/route.ts
git add entry/src/main/ets/constants/ApiConstants.ets
git add entry/src/main/ets/api/ChatApi.ets
git add entry/src/main/ets/pages/Setting.ets
git add entry/src/main/module.json5
git add docs/03-harmony-nextjs-mock-api.md

git commit -m "feat: connect harmony chat page to mock api"
git push origin feat/server-init
```

如果合并到 main：

```bash
git checkout main
git pull
git merge feat/server-init
git push
```

删除分支：

```bash
git branch -d feat/server-init
git push origin --delete feat/server-init
```

## 二十二、本次练习总结

这一节的重点不是做一个复杂聊天系统，而是跑通一个最小真实链路：

```txt
鸿蒙输入
↓
HTTP 请求
↓
Next.js 接口
↓
JSON 返回
↓
鸿蒙渲染
```

通过这次练习，我理解了前后端联调时几个关键点：

1. 前端假数据只是练页面，真实项目一定要接接口。
2. Next.js 可以很方便地作为轻量后端。
3. 鸿蒙网络请求需要单独封装。
4. 真机调试不能使用 `localhost`。
5. 请求失败时要看真实错误日志。
6. ArkTS 的类型规则比普通 TypeScript 更严格。
7. 前后端字段统一非常重要。

目前 Demo 已经完成了阶段性目标，后续如果继续扩展，可以接入 MySQL、Prisma、会话列表、历史消息和真实 AI 接口。

不过当前阶段可以先暂停 Demo，回到公司业务项目，重点分析真实项目的目录结构、架构设计、路由体系、接口封装和常用 ArkTS 语法。