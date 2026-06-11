import { PersistenceV2 } from '@kit.ArkUI'

/**
 * 全局主题状态：亮色 / 暗黑
 *
 * 放在 common 模块的原因：
 * - entry 模块依赖 common
 * - chat 模块也依赖 common
 * - 所以主题状态放 common 后，entry 和 chat 都可以直接复用
 */
@ObservedV2
export class ThemeState {
  @Trace isDark: boolean = false

  // ================= 页面 / 容器 =================

  get bg(): string {
    return this.isDark ? '#1C1C1E' : '#F5F7FA'
  }

  get surface(): string {
    return this.isDark ? '#2C2C2E' : '#FFFFFF'
  }

  get cardBg(): string {
    return this.surface
  }

  get placeholderBg(): string {
    return this.isDark ? '#3A3A3C' : '#EEF2FF'
  }

  // ================= 文字 =================

  get textPrimary(): string {
    return this.isDark ? '#F2F2F7' : '#1C1C1E'
  }

  get textSecondary(): string {
    return this.isDark ? '#C7C7CC' : '#666666'
  }

  get textTertiary(): string {
    return this.isDark ? '#8E8E93' : '#AAAAAA'
  }

  get textPlaceholder(): string {
    return this.isDark ? '#8E8E93' : '#CCCCCC'
  }

  // ================= 边框 / 分割线 / 阴影 =================

  get divider(): string {
    return this.isDark ? '#38383A' : '#EBEBEB'
  }

  get border(): string {
    return this.isDark ? '#48484A' : '#F0F0F0'
  }

  get shadowColor(): string {
    return this.isDark ? '#66000000' : '#0A000000'
  }

  get drawerShadowColor(): string {
    return this.isDark ? '#99000000' : '#33000000'
  }

  // ================= 品牌色 / 语义色 =================

  get primary(): string {
    return '#007DFF'
  }

  get onPrimary(): string {
    return '#FFFFFF'
  }

  get danger(): string {
    return '#FF4D4F'
  }

  get dangerBg(): string {
    return this.isDark ? '#3A1F20' : '#FFF1F0'
  }

  get dangerBorder(): string {
    return this.isDark ? '#7A2E30' : '#FFCCC7'
  }

  get onDanger(): string {
    return '#FFFFFF'
  }

  get warningBg(): string {
    return this.isDark ? '#332A12' : '#FFFBF0'
  }

  get warningBorder(): string {
    return this.isDark ? '#66521A' : '#FFE8A0'
  }

  get disabledBg(): string {
    return this.isDark ? '#3A3A3C' : '#CCCCCC'
  }

  // ================= 表单 =================

  get inputBg(): string {
    return this.isDark ? '#3A3A3C' : '#F5F5F5'
  }

  get inputText(): string {
    return this.textPrimary
  }

  get placeholderText(): string {
    return this.textTertiary
  }

  // ================= 聊天气泡 =================

  get assistantBubbleBg(): string {
    return this.isDark ? '#3A3A3C' : '#F0F0F0'
  }

  get userBubbleBg(): string {
    return this.primary
  }

  get loadingBubbleBg(): string {
    return this.assistantBubbleBg
  }

  // ================= Tab =================

  get tabActive(): string {
    return this.primary
  }

  get tabInactive(): string {
    return this.isDark ? '#8E8E93' : '#AAAAAA'
  }

  // ================= 按钮 =================

  get secondaryButtonBg(): string {
    return this.isDark ? '#3A3A3C' : '#F0F0F0'
  }

  get secondaryButtonText(): string {
    return this.isDark ? '#F2F2F7' : '#333333'
  }

  // ================= 信息块 =================

  get infoBg(): string {
    return this.isDark ? '#242B3D' : '#F8F9FF'
  }

  get infoBorder(): string {
    return this.isDark ? '#35415E' : '#DDEAFF'
  }

  // ================= 票根卡（行程确认 / 上车点确认）=================
  // 亮色值 = 组件里原本的硬编码值（零视觉变化），暗色值为深色推导

  /** 品牌蓝：抬头底色 / 主按钮 / 序号圆（亮暗一致） */
  get ticketBrand(): string {
    return '#FF00B5D9'
  }

  /** 品牌蓝浅底：选择车型 / 查看更多按钮底 */
  get ticketBrandThin(): string {
    return this.isDark ? '#3300B5D9' : '#1A00B5D9'
  }

  /** 黄色高亮条（亮暗一致） */
  get ticketYellow(): string {
    return '#FFD91A'
  }

  /** 卡片底色（暗色转深灰） */
  get ticketSurface(): string {
    return this.isDark ? '#2C2C2E' : '#FFFFFF'
  }

  /** 品牌上的文字：序号圆字 / 问号字 / 主按钮字（亮暗都白） */
  get ticketOnBrand(): string {
    return '#FFFFFF'
  }

  /** 主文字（90%） */
  get ticketTextHeavy(): string {
    return this.isDark ? '#E6FFFFFF' : '#E6000000'
  }

  /** 次文字（60%） */
  get ticketTextLite(): string {
    return this.isDark ? '#99FFFFFF' : '#99000000'
  }

  /** 弱文字（40%） */
  get ticketTextMuted(): string {
    return this.isDark ? '#66FFFFFF' : '#66000000'
  }

  /** 撕线 / 分隔线 / 边框（10%） */
  get ticketLine(): string {
    return this.isDark ? '#1AFFFFFF' : '#1A000000'
  }

  /** 竖向行程虚线 */
  get ticketDash(): string {
    return this.isDark ? '#5A5A5E' : '#B5BAC4'
  }

  /** 卡片阴影 */
  get ticketShadow(): string {
    return this.isDark ? '#44000000' : '#22000000'
  }

  /** 渐变·不透明卡片色（横向起点 + 纵向终点，融入卡底） */
  get ticketGradOpaque(): string {
    return this.isDark ? '#FF2C2C2E' : '#FFFFFFFF'
  }

  /** 渐变·透明（横向终点，透出品牌蓝） */
  get ticketGradClear(): string {
    return this.isDark ? '#002C2C2E' : '#00FFFFFF'
  }

  /** 渐变·70% 卡片色（纵向起点） */
  get ticketGradVTop(): string {
    return this.isDark ? '#B32C2C2E' : '#B3FFFFFF'
  }
}

/**
 * 全局主题单例
 * PersistenceV2 会根据 app_theme 这个 key 复用同一个实例，并支持持久化。
 */
export function getThemeState(): ThemeState {
  return PersistenceV2.connect(ThemeState, 'app_theme', () => new ThemeState())!
}