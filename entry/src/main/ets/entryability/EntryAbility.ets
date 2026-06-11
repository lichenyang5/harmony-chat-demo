import { AbilityConstant, ConfigurationConstant, UIAbility, Want, Configuration } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { window } from '@kit.ArkUI';
import { HMRouterMgr } from '@hadss/hmrouter'
import { SameRouteInterceptor } from '../interceptors/SameRouteInterceptor'
import { WindowUtil, getThemeState } from 'common'
import { ChatRdb } from 'chat';

const DOMAIN = 0x0000;

export default class EntryAbility extends UIAbility {
  onCreate(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    HMRouterMgr.openLog('INFO')
    HMRouterMgr.init({
      context: this.context
    })
    // 数据库初始化
    ChatRdb.init(this.context)
    HMRouterMgr.registerGlobalInterceptor({
      interceptor: new SameRouteInterceptor(),
      priority: 100,
      interceptorName: 'SameRouteInterceptor'
    })
    try {
      this.context.getApplicationContext().setColorMode(ConfigurationConstant.ColorMode.COLOR_MODE_NOT_SET);
    } catch (err) {
      hilog.error(DOMAIN, 'testTag', 'Failed to set colorMode. Cause: %{public}s', JSON.stringify(err));
    }
    // 冷启动：读系统当前深浅色同步到全局主题（手机已是暗色时，首屏就跟着暗）
    this.syncTheme(this.context.config.colorMode);
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onCreate');
  }

  /**
   * 系统深浅色（及其他配置）变化时回调。
   * 把系统 colorMode 同步到全局 ThemeState.isDark，
   * @Trace 驱动所有 this.theme.xxx 组件重渲，实现暗色跟随系统。
   */
  onConfigurationUpdate(newConfig: Configuration): void {
    this.syncTheme(newConfig.colorMode);
  }

  /** 把系统 colorMode 映射成 ThemeState.isDark（undefined / 非暗色都按亮色处理） */
  private syncTheme(colorMode?: ConfigurationConstant.ColorMode): void {
    const isDark = colorMode === ConfigurationConstant.ColorMode.COLOR_MODE_DARK;
    getThemeState().isDark = isDark;
    hilog.info(DOMAIN, 'EntryAbility', 'syncTheme isDark=%{public}s', isDark + '');
  }

  onDestroy(): void {
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onDestroy');
  }

  onWindowStageCreate(windowStage: window.WindowStage): void {
    // Main window is created, set main page for this ability
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onWindowStageCreate');

    windowStage.loadContent('pages/Index', async (err) => {//当前窗口的第一个页面内容，从 pages/Index 加载。
      if (err.code) {
        hilog.error(DOMAIN, 'testTag', 'Failed to load the content. Cause: %{public}s', JSON.stringify(err));
        return;
      }
      hilog.info(DOMAIN, 'testTag', 'Succeeded in loading the content.');
      // 页面加载完成后立即读取安全区高度并存入 AppStorage
      const lastWindow = await windowStage.getMainWindow()
      WindowUtil.init(lastWindow)
    });
  }

  onWindowStageDestroy(): void {
    // Main window is destroyed, release UI related resources
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onWindowStageDestroy');
  }

  onForeground(): void {
    // Ability has brought to foreground
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onForeground');
  }

  onBackground(): void {
    // Ability has back to background
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onBackground');
  }
}