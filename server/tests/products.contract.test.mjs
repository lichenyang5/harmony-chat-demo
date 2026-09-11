import assert from 'node:assert/strict'
import test from 'node:test'

test('products API supplies varied cover heights for a waterfall feed', async () => {
  const response = await fetch('http://127.0.0.1:3000/api/products')
  assert.equal(response.status, 200)

  const payload = await response.json()
  assert.equal(payload.code, 200)
  assert.equal(payload.data.length, 28)
  assert.ok(payload.data.every((product) => product.id.startsWith('ai-')))
  assert.equal(new Set(payload.data.map((product) => product.id)).size, payload.data.length)

  const heights = payload.data.map((product) => product.coverHeight)
  assert.ok(heights.every((height) => Number.isInteger(height) && height >= 120))
  assert.ok(new Set(heights).size >= 8)

  const contentTypes = new Set(payload.data.map((product) => product.contentType))
  assert.deepEqual(contentTypes, new Set(['prompt', 'assistant']))
  assert.ok(payload.data.every((product) => product.image === 'images/1.png'))

  const descriptionLengths = payload.data.map((product) => product.desc.length)
  assert.ok(Math.max(...descriptionLengths) - Math.min(...descriptionLengths) >= 24)
})
