export class RouteConstants {
  static readonly MAIN_NAVIGATION_ID: string = 'MainNavigation'

  static readonly TAB_HOME: string = 'pages/TabHome'
  static readonly HOME: string = 'pages/Home'
  static readonly SETTING: string = 'pages/Setting'
  static readonly PRODUCT_DETAIL: string = 'pages/ProductDetail'
  static readonly LOGIN: string = 'pages/Login'
}

export class RouteTitle {
  static readonly TAB_HOME: string = '首页'
  static readonly HOME: string = 'Home'
  static readonly SETTING: string = 'Setting'
}

export class RouteFrom {
  static readonly TAB_BAR: string = '底部导航栏'
}

export class TabRouteItem {
  title: string = ''
  pageUrl: string = ''
}

export const TAB_ROUTES: TabRouteItem[] = [
  {
    title: RouteTitle.TAB_HOME,
    pageUrl: RouteConstants.TAB_HOME
  },
  {
    title: RouteTitle.HOME,
    pageUrl: RouteConstants.HOME
  },
  {
    title: RouteTitle.SETTING,
    pageUrl: RouteConstants.SETTING
  }
]