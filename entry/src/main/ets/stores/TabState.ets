import { RouteConstants } from '../constants/RouteConstants'

@ObservedV2
export class TabState {
  @Trace currentTab: string = RouteConstants.TAB_HOME

  setCurrentTab(pageUrl: string): void {
    this.currentTab = pageUrl
  }
}

export const globalTabState: TabState = new TabState()