import { HMNavigation } from '@hadss/hmrouter'

@Entry
@ComponentV2
export struct Index {
  build() {
    Column() {
      HMNavigation({
        navigationId: 'MainNavigation',
        homePageUrl: 'pages/Home',   // ← Login 改成 Home
        options: {}
      })
    }
    .width('100%')
    .height('100%')
  }
}
