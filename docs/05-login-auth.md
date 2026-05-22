# 鸿蒙聊天 Demo 练习 05：新增登录功能，实现登录态保存与页面访问控制

## 一、本次分支

```bash
feature/login-auth
```

## 二、本次目标

本次在原有鸿蒙聊天 Demo 的基础上，新增一个基础登录功能。

前面 Demo 已经完成了：

1. 基础聊天页面。
2. 自动滚动到底部。
3. 打字机 / loading 效果。
4. 接入 Next.js 后端聊天接口。
5. 聊天历史本地缓存。

但是目前还有一个问题：

```txt
任何人进入 App 都可以直接进入聊天页，没有登录态判断。
```

真实项目中，聊天页面、用户信息、历史会话等功能通常都需要依赖用户身份。

所以本次新增登录功能，目标是跑通一条最小登录链路：

```txt
登录页输入账号密码
↓
请求 Next.js 后端 /api/login
↓
后端校验账号密码
↓
返回 token 和 userInfo
↓
鸿蒙端保存 token / userInfo 到 Preferences
↓
写入全局 AuthStore
↓
进入聊天页面
↓
聊天页读取登录态
↓
未登录时跳转登录页
↓
支持退出登录
```

本次不是为了做复杂的账号系统，而是先把登录页、登录接口、登录态缓存、全局状态、页面访问控制这一套流程跑通。

## 三、涉及文件

本次新增文件：

```txt
server/app/api/login/route.ts

entry/src/main/ets/models/AuthModel.ets
entry/src/main/ets/api/AuthApi.ets
entry/src/main/ets/utils/AuthStorage.ets
entry/src/main/ets/stores/AuthStore.ets
entry/src/main/ets/pages/Login.ets
```

本次修改文件：

```txt
entry/src/main/ets/constants/RouteConstants.ets
entry/src/main/ets/pages/Setting.ets
```

文档文件：

```txt
docs/05-login-auth.md
```

## 四、为什么要做登录功能

之前聊天 Demo 的页面访问流程是：

```txt
进入 App
↓
点击聊天页
↓
直接进入 Setting.ets
↓
发送消息
```

这个流程适合练习聊天页面，但不符合真实业务。

真实项目里，很多功能都需要先确认用户身份，比如：

```txt
聊天历史属于哪个用户
会话列表属于哪个用户
用户 token 是否有效
接口请求是否需要 Authorization
退出登录后是否还能访问页面
```

所以登录功能的价值不只是多一个页面，而是引入了几个真实项目里很常见的概念：

```txt
登录接口
token
用户信息
本地持久化
全局状态
页面权限控制
退出登录
```

这也能和公司项目里的架构思想对应起来：

```txt
View：Login.ets / Setting.ets
Api：AuthApi.ets
Storage：AuthStorage.ets
Store：AuthStore.ets
Backend：/api/login
```

## 五、本次整体链路

本次登录功能的完整链路是：

```txt
Login.ets
↓
AuthApi.ets
↓
Next.js /api/login
↓
返回 token / userInfo
↓
AuthStorage.ets 保存到 Preferences
↓
AuthStore.ets 保存运行时登录状态
↓
HMRouterMgr.replace 跳转 Setting
↓
Setting.ets 初始化时读取 AuthStorage
↓
有登录态，加载聊天历史
↓
无登录态，跳转 Login
```

可以理解为：

```txt
AuthApi 负责请求登录接口
AuthStorage 负责持久化登录信息
AuthStore 负责页面运行时状态
Setting 负责判断是否允许进入聊天页
Login 负责登录交互
```

## 六、新增后端登录接口

文件：

```txt
server/app/api/login/route.ts
```

完整代码：

```ts
import { NextResponse } from 'next/server'

type LoginRequestBody = {
  username?: string
  password?: string
}

export async function POST(request: Request) {
  try {
    const body = await request.json() as LoginRequestBody

    const username = String(body.username || '').trim()
    const password = String(body.password || '').trim()

    if (!username || !password) {
      return NextResponse.json(
        {
          code: 400,
          message: '账号和密码不能为空'
        },
        {
          status: 400
        }
      )
    }

    if (username !== 'admin' || password !== '123456') {
      return NextResponse.json(
        {
          code: 401,
          message: '账号或密码错误'
        },
        {
          status: 401
        }
      )
    }

    return NextResponse.json({
      code: 0,
      message: 'success',
      data: {
        token: `mock-token-${Date.now()}`,
        userInfo: {
          id: 1,
          username: 'admin',
          nickname: '鸿蒙练习用户',
          avatar: ''
        }
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

测试账号：

```txt
admin
```

测试密码：

```txt
123456
```

## 七、后端接口返回结构

登录成功返回：

```json
{
  "code": 0,
  "message": "success",
  "data": {
    "token": "mock-token-1779345862737",
    "userInfo": {
      "id": 1,
      "username": "admin",
      "nickname": "鸿蒙练习用户",
      "avatar": ""
    }
  }
}
```

登录失败返回：

```json
{
  "code": 401,
  "message": "账号或密码错误"
}
```

这里先使用 mock token：

```txt
mock-token-时间戳
```

原因是当前阶段重点不是安全认证，而是练习登录流程。

后续如果接数据库，可以把这部分改成：

```txt
查询 users 表
↓
校验密码
↓
生成 JWT
↓
返回真实 token
```

## 八、新增 AuthModel

文件：

```txt
entry/src/main/ets/models/AuthModel.ets
```

代码：

```ts
export interface LoginRequest {
  username: string
  password: string
}

export interface UserInfo {
  id: number
  username: string
  nickname: string
  avatar: string
}

export interface LoginResponseData {
  token: string
  userInfo: UserInfo
}

export interface LoginResponse {
  code: number
  message: string
  data: LoginResponseData
}
```

这个文件专门维护登录相关类型。

字段说明：

```txt
LoginRequest：登录请求参数
UserInfo：用户信息
LoginResponseData：登录成功返回的核心数据
LoginResponse：完整登录接口响应
```

这样写的好处是：

```txt
AuthApi 请求时有类型约束
AuthStorage 保存时有类型约束
AuthStore 使用用户信息时有类型提示
页面渲染 userInfo.nickname 时更安全
```

## 九、新增 AuthApi

文件：

```txt
entry/src/main/ets/api/AuthApi.ets
```

代码：

```ts
import { http } from '@kit.NetworkKit'
import { API_BASE_URL } from '../constants/ApiConstants'
import { LoginRequest, LoginResponse } from '../models/AuthModel'

interface RequestHeader {
  'Content-Type': string
}

export function login(params: LoginRequest): Promise<LoginResponse> {
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

    const requestUrl: string = `${API_BASE_URL}/api/login`

    console.info(`login api request url: ${requestUrl}`)
    console.info(`login api request body: ${JSON.stringify(params)}`)

    httpRequest.request(requestUrl, requestOptions, (err, data) => {
      httpRequest.destroy()

      if (err) {
        console.error(`login api request error: ${JSON.stringify(err)}`)
        reject(err)
        return
      }

      try {
        const rawResult: string = String(data.result)

        console.info(`login api response code: ${data.responseCode}`)
        console.info(`login api response result: ${rawResult}`)

        const result: LoginResponse = JSON.parse(rawResult) as LoginResponse
        resolve(result)
      } catch (parseError) {
        console.error(`login api parse error: ${JSON.stringify(parseError)}`)
        reject(parseError)
      }
    })
  })
}
```

## 十、AuthApi 的作用

`AuthApi.ets` 的作用是把登录请求封装起来。

页面不需要直接写：

```txt
http.createHttp
requestOptions
Content-Type
JSON.stringify
JSON.parse
destroy
```

页面只需要调用：

```ts
const res = await login(requestParams)
```

这样页面就不会关心底层 HTTP 细节。

这和之前的 `ChatApi.ets` 思路一致：

```txt
ChatApi 负责聊天接口
AuthApi 负责登录接口
```

后续可以继续升级成通用 Request 工具：

```txt
Request.post('/api/login', params)
Request.post('/api/chat', params)
```

这就是下一节可以做的“请求封装升级”。

## 十一、新增 AuthStorage

文件：

```txt
entry/src/main/ets/utils/AuthStorage.ets
```

代码：

```ts
import { preferences } from '@kit.ArkData'
import { common } from '@kit.AbilityKit'
import { UserInfo } from '../models/AuthModel'

interface AuthCacheData {
  token: string
  userInfo: UserInfo
}

export class AuthStorage {
  private static readonly STORE_NAME: string = 'auth_storage'
  private static readonly AUTH_CACHE_KEY: string = 'auth_cache'

  static async saveAuthCache(
    context: common.UIAbilityContext,
    token: string,
    userInfo: UserInfo
  ): Promise<void> {
    const pref = await preferences.getPreferences(context, AuthStorage.STORE_NAME)

    const cacheData: AuthCacheData = {
      token,
      userInfo
    }

    await pref.put(AuthStorage.AUTH_CACHE_KEY, JSON.stringify(cacheData))
    await pref.flush()
  }

  static async getAuthCache(context: common.UIAbilityContext): Promise<AuthCacheData | null> {
    const pref = await preferences.getPreferences(context, AuthStorage.STORE_NAME)
    const cacheValue = await pref.get(AuthStorage.AUTH_CACHE_KEY, '')

    if (typeof cacheValue !== 'string' || cacheValue.length === 0) {
      return null
    }

    try {
      const cacheData = JSON.parse(cacheValue) as AuthCacheData

      if (!cacheData.token || !cacheData.userInfo) {
        return null
      }

      return cacheData
    } catch (error) {
      console.error(`parse auth cache error: ${JSON.stringify(error)}`)
      return null
    }
  }

  static async clearAuthCache(context: common.UIAbilityContext): Promise<void> {
    const pref = await preferences.getPreferences(context, AuthStorage.STORE_NAME)
    await pref.delete(AuthStorage.AUTH_CACHE_KEY)
    await pref.flush()
  }
}
```

## 十二、AuthStorage 的职责

`AuthStorage` 只负责登录缓存。

它主要提供三个方法：

```txt
saveAuthCache：保存 token 和 userInfo
getAuthCache：读取 token 和 userInfo
clearAuthCache：清空登录缓存
```

页面不需要关心：

```txt
Preferences 文件名是什么
缓存 key 是什么
数据怎么 stringify
数据怎么 parse
异常时怎么处理
```

这和上一节的 `ChatStorage` 是同一种思路：

```txt
ChatStorage：负责聊天缓存
AuthStorage：负责登录缓存
```

这样代码职责更清晰。

## 十三、为什么要保存 token 和 userInfo

登录成功后需要保存两个东西：

```txt
token
userInfo
```

`token` 的作用：

```txt
表示当前用户已经登录
后续请求接口时可以放到 Authorization Header
后续做登录拦截时可以判断是否存在 token
```

`userInfo` 的作用：

```txt
页面展示当前用户名
后续可以展示头像、昵称、个人中心
后续会话列表可以按用户区分
```

所以本地缓存结构设计成：

```ts
interface AuthCacheData {
  token: string
  userInfo: UserInfo
}
```

## 十四、新增 AuthStore

文件：

```txt
entry/src/main/ets/stores/AuthStore.ets
```

代码：

```ts
import { UserInfo } from '../models/AuthModel'

@ObservedV2
export class AuthStore {
  @Trace token: string = ''
  @Trace userInfo: UserInfo | null = null

  get isLogin(): boolean {
    return this.token.length > 0 && this.userInfo !== null
  }

  setAuth(token: string, userInfo: UserInfo): void {
    this.token = token
    this.userInfo = userInfo
  }

  clearAuth(): void {
    this.token = ''
    this.userInfo = null
  }
}

export const globalAuthStore: AuthStore = new AuthStore()
```

## 十五、AuthStore 的作用

`AuthStorage` 和 `AuthStore` 不是一回事。

它们的区别是：

```txt
AuthStorage：负责本地持久化，应用重启后还在
AuthStore：负责运行时状态，页面刷新更方便
```

可以这样理解：

```txt
Preferences 是硬盘
Store 是内存
```

登录成功时，两边都要更新：

```txt
AuthStorage 保存到本地
AuthStore 更新当前运行时状态
```

退出登录时，两边也都要清空：

```txt
AuthStorage 删除本地缓存
AuthStore 清空当前状态
```

## 十六、修改 RouteConstants

文件：

```txt
entry/src/main/ets/constants/RouteConstants.ets
```

新增登录页面路由：

```ts
static readonly LOGIN: string = 'pages/Login'
```

示例：

```ts
export class RouteConstants {
  static readonly MAIN_NAVIGATION_ID: string = 'MainNavigation'

  static readonly LOGIN: string = 'pages/Login'

  static readonly TAB_HOME: string = 'pages/TabHome'
  static readonly HOME: string = 'pages/Home'
  static readonly SETTING: string = 'pages/Setting'
  static readonly PRODUCT_DETAIL: string = 'pages/ProductDetail'
}
```

只有把登录页注册到路由常量里，后面才能通过：

```ts
HMRouterMgr.replace({
  pageUrl: RouteConstants.LOGIN
})
```

跳转到登录页面。

## 十七、新增 Login 页面

文件：

```txt
entry/src/main/ets/pages/Login.ets
```

完整代码：

```ts
import { HMRouter, HMRouterMgr } from '@hadss/hmrouter'
import { common } from '@kit.AbilityKit'

import { login } from '../api/AuthApi'
import { LoginRequest } from '../models/AuthModel'
import { RouteConstants } from '../constants/RouteConstants'
import { AuthStorage } from '../utils/AuthStorage'
import { globalAuthStore } from '../stores/AuthStore'

@HMRouter({ pageUrl: RouteConstants.LOGIN })
@ComponentV2
export struct Login {
  @Local username: string = 'admin'
  @Local password: string = '123456'
  @Local isLoading: boolean = false
  @Local errorMessage: string = ''

  async handleLogin(): Promise<void> {
    const username = this.username.trim()
    const password = this.password.trim()

    if (!username || !password) {
      this.errorMessage = '请输入账号和密码'
      return
    }

    if (this.isLoading) {
      return
    }

    this.isLoading = true
    this.errorMessage = ''

    try {
      const requestParams: LoginRequest = {
        username: username,
        password: password
      }

      const res = await login(requestParams)

      if (res.code !== 0) {
        this.errorMessage = res.message || '登录失败'
        return
      }

      const context = getContext(this) as common.UIAbilityContext

      await AuthStorage.saveAuthCache(
        context,
        res.data.token,
        res.data.userInfo
      )

      globalAuthStore.setAuth(res.data.token, res.data.userInfo)

      HMRouterMgr.replace({
        pageUrl: RouteConstants.SETTING
      })
    } catch (error) {
      console.error(`login error: ${JSON.stringify(error)}`)
      this.errorMessage = '登录请求失败，请检查后端服务是否启动'
    } finally {
      this.isLoading = false
    }
  }

  build() {
    Column() {
      Text('登录')
        .fontSize(30)
        .fontWeight(FontWeight.Bold)
        .fontColor('#222222')
        .margin({ bottom: 8 })

      Text('鸿蒙聊天 Demo')
        .fontSize(16)
        .fontColor('#666666')
        .margin({ bottom: 36 })

      Column() {
        TextInput({
          placeholder: '请输入账号',
          text: this.username
        })
          .height(46)
          .width('100%')
          .backgroundColor('#F5F6F7')
          .borderRadius(10)
          .padding({ left: 12, right: 12 })
          .enabled(!this.isLoading)
          .onChange((value: string) => {
            this.username = value
          })

        TextInput({
          placeholder: '请输入密码',
          text: this.password
        })
          .height(46)
          .width('100%')
          .type(InputType.Password)
          .backgroundColor('#F5F6F7')
          .borderRadius(10)
          .padding({ left: 12, right: 12 })
          .margin({ top: 14 })
          .enabled(!this.isLoading)
          .onChange((value: string) => {
            this.password = value
          })

        if (this.errorMessage.length > 0) {
          Text(this.errorMessage)
            .fontSize(14)
            .fontColor('#E5484D')
            .width('100%')
            .margin({ top: 12 })
        }

        Button(this.isLoading ? '登录中' : '登录')
          .width('100%')
          .height(46)
          .margin({ top: 24 })
          .enabled(!this.isLoading)
          .onClick(() => {
            this.handleLogin()
          })

        Text('测试账号：admin / 123456')
          .fontSize(13)
          .fontColor('#999999')
          .margin({ top: 16 })
      }
      .width('100%')
      .padding(20)
      .backgroundColor(Color.White)
      .borderRadius(16)
    }
    .width('100%')
    .height('100%')
    .padding({ left: 24, right: 24 })
    .backgroundColor('#F5F6F7')
    .justifyContent(FlexAlign.Center)
  }
}
```

## 十八、Login 页面的核心流程

登录页的核心逻辑在 `handleLogin` 方法中。

流程是：

```txt
读取 username / password
↓
trim 去掉前后空格
↓
判断是否为空
↓
设置 isLoading = true
↓
组装 LoginRequest
↓
调用 login 接口
↓
判断 res.code
↓
保存 token / userInfo 到 AuthStorage
↓
写入 globalAuthStore
↓
跳转聊天页面
↓
finally 中关闭 loading
```

核心代码：

```ts
const requestParams: LoginRequest = {
  username: username,
  password: password
}

const res = await login(requestParams)
```

这里没有直接写匿名对象到函数里，而是先定义 `LoginRequest` 类型变量。

原因是 ArkTS 对对象字面量比较严格，明确类型可以减少报错。

## 十九、修改 Setting 页面

文件：

```txt
entry/src/main/ets/pages/Setting.ets
```

本次 `Setting.ets` 主要新增了三件事：

```txt
进入页面时初始化登录态
未登录跳转 Login
支持退出登录
```

新增引用：

```ts
import { HMRouter, HMRouterMgr } from '@hadss/hmrouter'
import { common } from '@kit.AbilityKit'

import { AuthStorage } from '../utils/AuthStorage'
import { globalAuthStore } from '../stores/AuthStore'
```

如果原来已经有：

```ts
import { HMRouter } from '@hadss/hmrouter'
```

就改成：

```ts
import { HMRouter, HMRouterMgr } from '@hadss/hmrouter'
```

## 二十、Setting 页面初始化登录态

原来 `aboutToAppear` 可能是：

```ts
aboutToAppear(): void {
  globalTabState.setCurrentTab(RouteConstants.SETTING)

  this.getUIContext().setKeyboardAvoidMode(KeyboardAvoidMode.RESIZE)

  this.loadChatCache()
}
```

现在改成：

```ts
aboutToAppear(): void {
  globalTabState.setCurrentTab(RouteConstants.SETTING)

  this.getUIContext().setKeyboardAvoidMode(KeyboardAvoidMode.RESIZE)

  this.initAuth()
}
```

新增方法：

```ts
async initAuth(): Promise<void> {
  const context = getContext(this) as common.UIAbilityContext
  const authCache = await AuthStorage.getAuthCache(context)

  if (!authCache) {
    globalAuthStore.clearAuth()

    HMRouterMgr.replace({
      pageUrl: RouteConstants.LOGIN
    })

    return
  }

  globalAuthStore.setAuth(authCache.token, authCache.userInfo)
  this.isAuthReady = true

  await this.loadChatCache()
}
```

这里的顺序很重要：

```txt
先判断登录态
↓
登录成功后
↓
再读取聊天历史
```

不要一进页面就先加载聊天历史。

否则用户没登录时，聊天页可能先短暂显示内容，再跳转登录页。

## 二十一、为什么加 isAuthReady

在 `Setting.ets` 里新增了：

```ts
@Local isAuthReady: boolean = false
```

它的作用是标记：

```txt
登录态是否已经初始化完成
```

输入框和发送按钮可以依赖它：

```ts
.enabled(!this.isSending && this.isAuthReady)
```

这样可以避免：

```txt
登录态还没读取完
用户已经开始输入或点击发送
```

这属于一个小的状态保护。

## 二十二、Setting 页面退出登录

新增方法：

```ts
async logout(): Promise<void> {
  const context = getContext(this) as common.UIAbilityContext

  await AuthStorage.clearAuthCache(context)
  globalAuthStore.clearAuth()

  HMRouterMgr.replace({
    pageUrl: RouteConstants.LOGIN
  })
}
```

退出登录时做了三件事：

```txt
清空本地登录缓存
清空全局登录状态
跳转到 Login 页面
```

目前没有清空聊天历史。

也就是说：

```txt
退出登录只代表账号退出
聊天缓存还在
```

如果希望退出时也清空聊天记录，可以加：

```ts
await ChatStorage.clearChatCache(context)
```

并且同时：

```ts
this.chatList = []
this.conversationId = 0
```

## 二十三、Header 显示当前用户

Header 中新增了当前用户展示：

```ts
if (globalAuthStore.userInfo !== null) {
  Text(`当前用户：${globalAuthStore.userInfo.nickname}`)
    .fontSize(12)
    .fontColor('#999999')
    .margin({ top: 2 })
} else {
  Text('未登录')
    .fontSize(12)
    .fontColor('#999999')
    .margin({ top: 2 })
}
```

这样登录成功后，聊天页面可以展示：

```txt
当前用户：鸿蒙练习用户
```

右侧按钮保留：

```txt
清空
退出
```

其中：

```txt
清空：清空聊天记录
退出：退出登录
```

## 二十四、本次功能和上一节本地缓存的关系

上一节做的是：

```txt
ChatStorage
```

负责保存：

```txt
conversationId
chatList
```

这一节做的是：

```txt
AuthStorage
```

负责保存：

```txt
token
userInfo
```

两者结构很像：

```txt
ChatStorage：聊天业务缓存
AuthStorage：登录业务缓存
```

它们的共同点是：

```txt
都用 Preferences
都需要 JSON.stringify
都需要 JSON.parse
都需要 flush
都需要异常兜底
都从页面逻辑中抽离出来
```

这说明本地存储可以形成统一写法，后续做主题、设置、用户偏好时也可以照这个模式。

## 二十五、本次功能和公司项目架构的对应关系

公司项目里有类似的分层：

```txt
AgentChatComp
↓
ChatViewModel
↓
ChatController
↓
CozeProvider
↓
HttpClient
```

这次 Demo 登录功能里也有类似思路：

```txt
Login.ets / Setting.ets
↓
AuthStore
↓
AuthApi
↓
Next.js /api/login
↓
AuthStorage
```

虽然 Demo 比公司项目简单很多，但核心思想是一样的：

```txt
页面不要直接处理所有事情
接口请求要封装
状态要统一管理
本地缓存要单独封装
业务逻辑要分层
```

这个功能正好能帮助理解真实项目里的工程化设计。

## 二十六、测试步骤

### 1. 启动后端

```bash
cd server
npm run dev
```

如果第一次运行：

```bash
cd server
npm install
npm run dev
```

### 2. 测试登录接口

PowerShell 测试：

```powershell
Invoke-RestMethod `
  -Uri "http://localhost:3000/api/login" `
  -Method POST `
  -ContentType "application/json" `
  -Body '{"username":"admin","password":"123456"}'
```

局域网测试：

```powershell
Invoke-RestMethod `
  -Uri "http://192.168.20.8:3000/api/login" `
  -Method POST `
  -ContentType "application/json" `
  -Body '{"username":"admin","password":"123456"}'
```

注意：这里的 IP 要换成自己电脑当前局域网 IP。

### 3. 启动鸿蒙应用

用 DevEco Studio 运行到真机或模拟器。

### 4. 测试未登录跳转

操作：

```txt
清空应用数据
打开 App
进入聊天页
```

预期：

```txt
自动跳转 Login 页面
```

### 5. 测试账号密码为空

不输入账号或密码，点击登录。

预期：

```txt
提示：请输入账号和密码
```

### 6. 测试账号密码错误

输入：

```txt
admin
111111
```

预期：

```txt
提示：账号或密码错误
```

### 7. 测试登录成功

输入：

```txt
admin
123456
```

预期：

```txt
登录成功
跳转聊天页
Header 显示当前用户：鸿蒙练习用户
```

### 8. 测试登录态持久化

操作：

```txt
关闭 App
重新打开 App
进入聊天页
```

预期：

```txt
不需要重新登录
直接进入聊天页
```

因为 token 和 userInfo 已经保存到了 `AuthStorage`。

### 9. 测试退出登录

点击 Header 右侧：

```txt
退出
```

预期：

```txt
清空登录缓存
跳转 Login 页面
再次进入聊天页仍然要求登录
```

## 二十七、可能遇到的问题

### 1. Cannot find module '../utils/AuthStorage'

原因：

```txt
AuthStorage.ets 没有创建
utils 路径写错
导出类名写错
```

确认文件位置：

```txt
entry/src/main/ets/utils/AuthStorage.ets
```

确认导出：

```ts
export class AuthStorage {}
```

### 2. Cannot find module '../stores/AuthStore'

原因：

```txt
AuthStore.ets 没有创建
stores 路径写错
globalAuthStore 没有导出
```

确认导出：

```ts
export const globalAuthStore: AuthStore = new AuthStore()
```

### 3. RouteConstants.LOGIN 报错

原因：

```txt
RouteConstants.ets 里没有新增 LOGIN
```

添加：

```ts
static readonly LOGIN: string = 'pages/Login'
```

### 4. 登录页跳不过去

可能原因：

```txt
Login.ets 没有加 @HMRouter
pageUrl 和 RouteConstants.LOGIN 不一致
HMRouterMgr.replace 当前版本不支持
```

确认：

```ts
@HMRouter({ pageUrl: RouteConstants.LOGIN })
```

如果 `replace` 报错，可以先改成：

```ts
HMRouterMgr.push({
  pageUrl: RouteConstants.LOGIN
})
```

### 5. 登录请求失败

可能原因：

```txt
Next.js 后端没启动
API_BASE_URL 写错
真机不能访问 localhost
手机和电脑不在同一局域网
Windows 防火墙拦截
```

真机调试时不能写：

```txt
http://localhost:3000
```

应该写：

```txt
http://电脑局域网IP:3000
```

### 6. 退出登录后重新进入还显示已登录

可能原因：

```txt
只清空了 AuthStore，没有清空 AuthStorage
clearAuthCache 后没有 flush
```

确认退出登录中有：

```ts
await AuthStorage.clearAuthCache(context)
globalAuthStore.clearAuth()
```

确认 `AuthStorage.clearAuthCache` 里有：

```ts
await pref.delete(AuthStorage.AUTH_CACHE_KEY)
await pref.flush()
```

## 二十八、ArkTS 类型注意点

这次依然要注意 ArkTS 的对象字面量类型问题。

不推荐直接写：

```ts
const res = await login({
  username,
  password
})
```

更推荐：

```ts
const requestParams: LoginRequest = {
  username: username,
  password: password
}

const res = await login(requestParams)
```

这样写类型更明确，也更符合 ArkTS 的严格要求。

## 二十九、本次知识点总结

本次练习涉及以下知识点：

1. 新增 Next.js 登录接口。
2. 使用 POST `/api/login` 完成账号密码校验。
3. 鸿蒙侧封装 `AuthApi.ets` 请求登录接口。
4. 使用 `LoginRequest`、`LoginResponse` 统一接口类型。
5. 使用 `Preferences` 保存 token 和 userInfo。
6. 使用 `AuthStorage` 封装登录缓存。
7. 使用 `AuthStore` 管理运行时登录状态。
8. 使用 `@ObservedV2` 和 `@Trace` 创建全局响应式状态。
9. 使用 `HMRouterMgr.replace` 实现登录成功后跳转。
10. 在聊天页 `aboutToAppear` 中初始化登录态。
11. 未登录时跳转 Login 页面。
12. 登录后再加载聊天历史缓存。
13. Header 展示当前用户昵称。
14. 退出登录时清空缓存和全局状态。
15. 区分本地持久化状态和运行时状态。
16. 理解 token、userInfo、登录态的基本关系。
17. 为后续接口 Authorization 和路由拦截器打基础。

## 三十、面试表达

这个功能可以这样说：

> 我在鸿蒙聊天 Demo 中新增了一个基础登录功能。后端使用 Next.js 新增了 `POST /api/login` 接口，先用 mock 账号 `admin / 123456` 完成登录校验，登录成功后返回 token 和 userInfo。鸿蒙侧新增了 `AuthApi.ets` 封装登录请求，新增 `AuthStorage.ets` 使用 Preferences 保存 token 和用户信息，新增 `AuthStore.ets` 管理运行时登录状态。登录页提交账号密码后，会调用登录接口，成功后保存登录态并跳转聊天页。聊天页在 `aboutToAppear` 中先读取本地登录缓存，如果没有 token 就跳转 Login 页面，如果有 token 才继续加载聊天历史缓存。同时 Header 中展示当前用户昵称，并支持退出登录。这个功能让我练习了登录接口、token 本地保存、全局状态管理、页面访问控制和退出登录流程，也为后续做路由拦截器、Authorization 请求头和数据库用户表打下基础。

## 三十一、本次提交命令

```bash
git add server/app/api/login/route.ts

git add entry/src/main/ets/models/AuthModel.ets
git add entry/src/main/ets/api/AuthApi.ets
git add entry/src/main/ets/utils/AuthStorage.ets
git add entry/src/main/ets/stores/AuthStore.ets
git add entry/src/main/ets/pages/Login.ets

git add entry/src/main/ets/constants/RouteConstants.ets
git add entry/src/main/ets/pages/Setting.ets

git add docs/05-login-auth.md

git commit -m "feat: add login auth flow"
git push origin feature/login-auth
```

如果合并到 main：

```bash
git checkout main
git pull
git merge feature/login-auth
git push
```

删除本地分支：

```bash
git branch -d feature/login-auth
```

删除远程分支：

```bash
git push origin --delete feature/login-auth
```

## 三十二、本次练习总结

这一节的重点不是做复杂的用户系统，而是把登录的最小闭环跑通：

```txt
登录页面
↓
登录接口
↓
保存 token
↓
保存用户信息
↓
全局登录状态
↓
聊天页登录态判断
↓
退出登录
```

通过这次练习，我理解了几个关键点：

1. 登录功能不只是一个页面，还包括接口、缓存、状态和路由控制。
2. token 适合保存到本地缓存中，用于表示用户登录态。
3. userInfo 可以用于页面展示和后续用户相关业务。
4. `AuthStorage` 负责持久化，`AuthStore` 负责运行时状态。
5. 页面进入时应该先判断登录态，再加载业务数据。
6. 退出登录时要同时清空本地缓存和全局状态。
7. 登录功能可以继续扩展成路由拦截器，而不是每个页面都手动判断。
8. 后续接数据库时，可以把 mock 登录接口替换成真实 users 表查询。
9. 后续请求封装升级后，可以统一给接口加 Authorization Header。
10. 这个功能让 Demo 更接近真实业务项目。

目前 Demo 已经具备：

```txt
基础聊天
后端接口请求
聊天历史本地缓存
登录页
登录态保存
退出登录
```

后续可以继续扩展：

```txt
请求封装升级
登录路由拦截器
Authorization 请求头
用户表和数据库登录
会话列表
多用户聊天历史
```

这样整个鸿蒙聊天 Demo 会越来越接近公司项目中的真实工程结构。
