# HarmonyOS 工程签名本地化与 API 环境化：告别证书泄露和反复修改 IP

在多人协作或公开示例项目中，`build-profile.json5` 经常同时承担两类职责：

1. 描述模块、Product、SDK 版本等公共构建结构；
2. 保存开发者个人的证书路径、密钥库和签名密码。

第二类数据显然不应该进入 Git，但 DevEco Studio 的自动签名又会把它们写回工程级 `build-profile.json5`。同一个文件还很适合承载不同开发环境的 API 地址，于是很容易出现两个问题：换一台电脑无法构建，以及每次换网络都要修改 ArkTS 业务代码。

本文以 `harmony-chat-demo` 的实际改造为案例，讲清楚如何把个人签名配置留在本机，通过 `BuildProfile` 向 ArkTS 注入服务端地址，并用契约测试防止敏感配置再次进入仓库。

## 一、改造前的问题

原工程直接跟踪根目录 `build-profile.json5`。DevEco Studio 自动签名后，这个文件会包含：

- `.cer` 调试证书的绝对路径；
- `.p7b` Profile 的绝对路径；
- `.p12` 密钥库的绝对路径；
- `keyPassword` 和 `storePassword`；
- Product 对具体签名方案的引用。

这些值与某一台开发电脑绑定。其他人拉取项目后，即使证书没有过期，也无法访问原开发者的磁盘路径。

客户端地址也直接写在 `ApiConstants.ets`：

```ts
static readonly BASE_URL: string = 'http://192.168.x.x:3000'
```

电脑切换 Wi-Fi、局域网地址变化或改用本机预览时，都需要改动受 Git 跟踪的业务源码。这种修改很容易被误提交，也会让不同开发者不断覆盖彼此的地址。

项目根目录还存在一个没有对应 `package.json` 的空 `package-lock.json`，而真正的 Node.js 工程位于 `server`。Next.js 因此检测到两个锁文件，把错误的目录推断为 workspace root，并持续输出警告。

## 二、目标结构

改造后的相关结构如下：

```text
harmony-chat-demo/
├─ .gitignore
├─ build-profile.example.json5   # 可提交：公共结构和安全默认值
├─ build-profile.json5           # 不提交：本机 API 地址与自动签名材料
├─ common/
│  ├─ BuildProfile.ets           # 不提交：Hvigor 生成的本机构建字段
│  └─ src/main/ets/constants/
│     └─ ApiConstants.ets         # 只消费 BuildProfile，不保存环境地址
└─ server/
   ├─ package.json
   ├─ package-lock.json           # 唯一的 npm 锁文件
   └─ tests/
      └─ project-config.contract.test.mjs
```

数据流变成：

```text
本机 build-profile.json5
        │
        │ buildProfileFields.API_BASE_URL
        ▼
Hvigor 生成 BuildProfile
        │
        ▼
ApiConstants.BASE_URL
        │
        ├─ HttpUtil
        └─ SseHttpUtil
```

业务层只知道“当前构建环境的基础地址”，并不关心地址来自真机、模拟环境还是某位开发者的电脑。

## 三、为什么采用“模板 + 本机文件”

`.gitignore` 增加：

```gitignore
/build-profile.json5
**/BuildProfile.ets
```

仓库保存 `build-profile.example.json5`，首次拉取后复制为本机文件：

```powershell
Copy-Item .\build-profile.example.json5 .\build-profile.json5
```

采用这个方案有三个原因：

1. DevEco Studio 自动签名会直接修改工程级 `build-profile.json5`；
2. HarmonyOS 的 `signingConfigs` 同时包含路径和密码，难以只靠几行忽略规则隔离；
3. API 地址同样属于开发者本机环境，和签名配置放在同一个本机文件中，首次配置最简单。

模板仍然保留模块列表、Product、SDK 和严格模式配置，因此新开发者不会从空文件开始配置。它只移除了 `signingConfigs` 和 `signingConfig` 引用，并提供安全的回环地址作为默认值。

需要注意：工程公共构建结构发生变化时，应同时更新模板。代码评审时应把 `build-profile.example.json5` 当作公共配置的事实来源。

## 四、使用 buildProfileFields 注入 API 地址

模板的 Product 中加入：

```json5
"buildOption": {
  "strictMode": {
    "caseSensitiveCheck": true,
    "useNormalizedOHMUrl": true
  },
  "arkOptions": {
    "buildProfileFields": {
      "API_BASE_URL": "http://127.0.0.1:3000"
    }
  }
}
```

HarmonyOS 构建系统会把 `buildProfileFields` 转换为 ArkTS 可读取的构建字段。由于当前工程的 Hvigor 版本不支持在 HAR 中使用裸模块名导入，`common` 模块沿用相对路径读取模块根目录生成的 `BuildProfile.ets`：

```ts
import BuildProfile from '../../../../BuildProfile'

export class ApiConstants {
  static readonly BASE_URL: string = BuildProfile.API_BASE_URL
  static readonly LOGIN: string = '/api/login'
  static readonly CHAT: string = '/api/chat'
  static readonly PRODUCTS: string = '/api/products'
}
```

这样 `HttpUtil`、`SseHttpUtil` 和各业务模块无需修改调用方式。环境变化只影响构建配置，不会扩散到网络层和页面层。

### 真机应该填写什么地址

HarmonyOS 真机中的 `127.0.0.1` 指向手机本身，不是开发电脑。运行本地 Mock Server 时，应把本机 `build-profile.json5` 改为电脑的局域网 IPv4：

```json5
"API_BASE_URL": "http://192.168.x.x:3000"
```

Windows 可以使用以下命令查看地址：

```powershell
ipconfig
```

只需要修改不受 Git 跟踪的本机配置，不再改 `ApiConstants.ets`。如果电脑的 DHCP 地址经常变化，可以在路由器中为电脑设置固定租约，进一步避免重复配置。

修改 `API_BASE_URL` 后，在 DevEco Studio 中选中 `common` 模块并执行：

```text
Build > Generate Build Profile 'common'
```

也可以在命令行构建时使用 `--generate-build-profile`。生成文件会包含当前本机的构建字段，所以 `common/BuildProfile.ets` 和 `chat/BuildProfile.ets` 同样不能被 Git 跟踪。

## 五、自动签名的正确流程

首次复制模板后，在 DevEco Studio 中进入：

```text
File > Project Structure > Project > Signing Configs
```

勾选 `Automatically generate signature`。DevEco Studio 会在本机补充 `signingConfigs`，并让 Product 引用生成的签名方案。

这些内容可以存在于本机，但必须满足两条边界：

- 不提交 `build-profile.json5`；
- 不提交 `.cer`、`.p7b`、`.p12`、`.csr` 等签名材料。

证书过期后，旧证书无法通过 `SignHap`。应在 DevEco Studio 中重新生成有效的自动签名，而不是修改系统时间或绕过证书校验。

## 六、为什么删除根 package-lock.json

根锁文件只有一个空包结构，根目录又不存在 `package.json`。Next.js 启动时向父目录搜索锁文件，发现根锁文件和 `server/package-lock.json` 后，会错误地把项目根目录当作前端 workspace root。

本项目不是 npm monorepo，因此最小修复是：

- 删除根 `package-lock.json`；
- 保留 `server/package-lock.json`；
- 不额外配置 `turbopack.root`。

如果未来根目录真正增加 npm workspace，再恢复根 `package.json` 和统一锁文件，而不是同时维护两个彼此无关的锁文件。

## 七、用契约测试阻止配置回归

新增的 `server/tests/project-config.contract.test.mjs` 检查四件事：

1. Git 不再跟踪根 `build-profile.json5` 和各 HAR 的 `BuildProfile.ets`；
2. Git 不跟踪常见签名文件；
3. 安全模板不包含签名字段、本机绝对路径和密码；
4. `ApiConstants` 必须从 `BuildProfile` 读取地址，并且根目录不能出现多余 npm 锁文件。

执行方式：

```bash
cd server
npm run test:config
```

该检查也已接入默认测试入口，可以直接执行 `npm test`。需要在线服务的商品接口契约仍保留在独立的 `npm run test:api` 中。

这类测试不是为了验证某一个页面，而是保护工程边界。将来如果有人误把自动签名后的文件重新加入 Git，测试会直接失败。

## 八、最难处理的三个点

### 1. 不能简单删除 build-profile.json5

删除后可以保护密码，但 DevEco Studio 无法获得完整的工程级构建结构。本次方案是“Git 不跟踪，本机仍保留”，并提供可复制模板兼顾安全和可运行性。

### 2. API 地址不能只换一个常量文件

把 IP 从 `ApiConstants.ets` 移到另一个受跟踪的 ArkTS 文件，只是移动了硬编码。真正的边界应该位于构建配置，由 Hvigor 在构建时注入。

### 3. 删除当前文件不等于清除 Git 历史

如果签名配置曾经提交，旧内容仍可能存在于历史提交中。本次改造阻止它继续出现在新版本，但不会自动改写历史。

仓库曾公开、上传远程或分享给其他人时，应先重新生成签名材料。是否使用 `git filter-repo` 清理历史，需要团队单独决定，因为历史重写会改变提交哈希并影响所有已有分支。

## 九、最终检查清单

- [ ] 根目录存在本机 `build-profile.json5`，但 `git status` 不显示它；
- [ ] 已为 `common` 生成本机 `BuildProfile.ets`，且 `git status` 不显示它；
- [ ] 仓库包含 `build-profile.example.json5`；
- [ ] 本机 `API_BASE_URL` 与运行设备相匹配；
- [ ] DevEco Studio 已生成有效的自动签名；
- [ ] `npm run test:config` 通过；
- [ ] `npm run dev` 不再输出 multiple lockfiles 警告；
- [ ] 真机可以访问 `http://<电脑IPv4>:3000/api/products`；
- [ ] HarmonyOS 应用登录、商品和 SSE 聊天请求正常。

## 总结

环境化并不是创建更多常量，而是明确哪些配置属于仓库、哪些配置属于开发者本机：

- 模块结构、SDK 和字段名称属于仓库；
- 证书、密码、本机路径和局域网地址属于本机；
- ArkTS 业务代码只消费构建结果。

一旦边界建立起来，换电脑、换网络和重新生成证书就不会继续污染业务源码，也不会把个人签名材料带入下一次提交。
