import { AppStorageV2 } from '@kit.ArkUI'

@ObservedV2
export class AppTabState {
  @Trace currentIndex: number = 0
}

// 全局单例：任何地方 connect 同一个 key，拿到的是同一个对象实例
export const tabState: AppTabState =
  AppStorageV2.connect(AppTabState, 'AppTabState', () => new AppTabState())!
