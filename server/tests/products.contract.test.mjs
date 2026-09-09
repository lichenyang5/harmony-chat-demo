import assert from 'node:assert/strict'
import test from 'node:test'

test('products API supplies varied cover heights for a waterfall feed', async () => {
  const response = await fetch('http://127.0.0.1:3000/api/products')
  assert.equal(response.status, 200)

  const payload = await response.json()
  assert.equal(payload.code, 200)
  assert.ok(payload.data.length >= 2)

  const heights = payload.data.map((product) => product.coverHeight)
  assert.ok(heights.every((height) => Number.isInteger(height) && height >= 120))
  assert.ok(new Set(heights).size >= 3)
})
