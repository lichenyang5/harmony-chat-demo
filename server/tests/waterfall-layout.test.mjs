import assert from 'node:assert/strict'
import test from 'node:test'

import {
  distributeWaterfall,
  estimateWaterfallCardHeight,
  matchesWaterfallSearch
} from '../../entry/src/main/ets/utils/WaterfallLayout.ts'

function card(id, coverHeight, name = '短标题', desc = '简短描述') {
  return { id, coverHeight, name, desc }
}

test('places each next card into the currently shorter column', () => {
  const result = distributeWaterfall([
    card('a', 220),
    card('b', 100),
    card('c', 100),
    card('d', 100)
  ])

  assert.deepEqual(result.left.map((item) => item.id), ['a', 'd'])
  assert.deepEqual(result.right.map((item) => item.id), ['b', 'c'])
})

test('estimates a taller card when visible text needs more lines', () => {
  const shortCard = card('short', 150, '标题', '一句话')
  const longCard = card(
    'long',
    150,
    '这是一个需要显示两行的提示词标题',
    '这是一段明显更长的说明文字，用来验证描述文本行数确实参与卡片高度预估，而不只是比较图片高度。'
  )

  assert.ok(
    estimateWaterfallCardHeight(longCard) >
      estimateWaterfallCardHeight(shortCard)
  )
})

test('returns two empty columns for an empty feed', () => {
  const result = distributeWaterfall([])

  assert.deepEqual(result.left, [])
  assert.deepEqual(result.right, [])
  assert.equal(result.leftHeight, 0)
  assert.equal(result.rightHeight, 0)
})

test('matches the visible Chinese labels for prompt and assistant cards', () => {
  const prompt = { ...card('prompt', 150), contentType: 'prompt' }
  const assistant = { ...card('assistant', 150), contentType: 'assistant' }

  assert.equal(matchesWaterfallSearch(prompt, '提示词'), true)
  assert.equal(matchesWaterfallSearch(assistant, 'AI 助手'), true)
  assert.equal(matchesWaterfallSearch(prompt, 'AI 助手'), false)
})
