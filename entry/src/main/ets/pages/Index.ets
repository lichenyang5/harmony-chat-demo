import { HMNavigation } from '@hadss/hmrouter'

@Entry
@ComponentV2
export struct Index {
  build() {
    Column() {
      HMNavigation({
        navigationId: 'MainNavigation',
        homePageUrl: 'pages/Login',
        options: {}
      })
    }
    .width('100%')
    .height('100%')
  }
}
