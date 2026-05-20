import { appTasks } from '@ohos/hvigor-ohos-plugin'
import { appPlugin } from '@hadss/hmrouter-plugin'

export default {
  system: appTasks,
  plugins: [
    appPlugin({
      ignoreModuleNames: []
    })
  ]
}