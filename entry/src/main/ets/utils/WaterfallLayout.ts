export interface WaterfallCardMetric {
  name: string
  desc: string
  coverHeight: number
}

export interface WaterfallSearchCard extends WaterfallCardMetric {
  contentType: string
}

export class WaterfallColumns<T extends WaterfallCardMetric> {
  left: T[] = []
  right: T[] = []
  leftHeight: number = 0
  rightHeight: number = 0
}

const MIN_COVER_HEIGHT: number = 120
const TITLE_CHARS_PER_LINE: number = 10
const DESCRIPTION_CHARS_PER_LINE: number = 15
const TITLE_MAX_LINES: number = 2
const DESCRIPTION_MAX_LINES: number = 3
const TITLE_LINE_HEIGHT: number = 20
const DESCRIPTION_LINE_HEIGHT: number = 17
const CARD_FIXED_HEIGHT: number = 70
const COLUMN_GAP: number = 12

function estimateVisibleLines(text: string, charsPerLine: number, maxLines: number): number {
  const length = Math.max(1, text.trim().length)
  return Math.min(maxLines, Math.max(1, Math.ceil(length / charsPerLine)))
}

export function estimateWaterfallCardHeight(card: WaterfallCardMetric): number {
  const coverHeight = Math.max(MIN_COVER_HEIGHT, card.coverHeight)
  const titleLines = estimateVisibleLines(card.name, TITLE_CHARS_PER_LINE, TITLE_MAX_LINES)
  const descriptionLines = estimateVisibleLines(
    card.desc,
    DESCRIPTION_CHARS_PER_LINE,
    DESCRIPTION_MAX_LINES
  )

  return coverHeight +
    titleLines * TITLE_LINE_HEIGHT +
    descriptionLines * DESCRIPTION_LINE_HEIGHT +
    CARD_FIXED_HEIGHT
}

/** 搜索范围与卡片上真实可见的信息保持一致。 */
export function matchesWaterfallSearch(card: WaterfallSearchCard, keyword: string): boolean {
  const normalizedKeyword = keyword.trim().toLowerCase()
  if (!normalizedKeyword) {
    return true
  }

  const typeLabel = card.contentType === 'assistant' ? 'ai 助手' : '提示词'
  return card.name.toLowerCase().includes(normalizedKeyword) ||
    card.desc.toLowerCase().includes(normalizedKeyword) ||
    typeLabel.includes(normalizedKeyword)
}

export function distributeWaterfall<T extends WaterfallCardMetric>(
  cards: T[]
): WaterfallColumns<T> {
  const columns = new WaterfallColumns<T>()

  cards.forEach((card: T) => {
    const estimatedHeight = estimateWaterfallCardHeight(card)
    if (columns.leftHeight <= columns.rightHeight) {
      columns.left.push(card)
      columns.leftHeight += estimatedHeight + COLUMN_GAP
    } else {
      columns.right.push(card)
      columns.rightHeight += estimatedHeight + COLUMN_GAP
    }
  })

  return columns
}
