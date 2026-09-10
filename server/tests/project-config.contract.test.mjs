import assert from 'node:assert/strict'
import { execFileSync } from 'node:child_process'
import { existsSync, readFileSync } from 'node:fs'
import { dirname, join, resolve } from 'node:path'
import test from 'node:test'
import { fileURLToPath } from 'node:url'

const testDir = dirname(fileURLToPath(import.meta.url))
const projectRoot = resolve(testDir, '..', '..')

function readProjectFile(relativePath) {
  return readFileSync(join(projectRoot, relativePath), 'utf8')
}

function trackedFiles() {
  const output = execFileSync('git', ['ls-files', '-z'], {
    cwd: projectRoot,
    encoding: 'utf8'
  })
  return output.split('\0').filter((file) => file.length > 0)
}

function isIgnored(relativePath) {
  try {
    execFileSync(
      'git',
      ['check-ignore', '--quiet', '--no-index', relativePath],
      { cwd: projectRoot, stdio: 'ignore' }
    )
    return true
  } catch {
    return false
  }
}

test('keeps signing material out of tracked project files', () => {
  const tracked = trackedFiles()

  assert.equal(tracked.includes('build-profile.json5'), false)
  assert.equal(
    tracked.some((file) => /(^|\/)BuildProfile\.ets$/.test(file)),
    false
  )
  assert.equal(isIgnored('build-profile.json5'), true)
  assert.equal(isIgnored('common/BuildProfile.ets'), true)
  assert.equal(isIgnored('chat/BuildProfile.ets'), true)
  assert.equal(
    tracked.some((file) => /\.(cer|p7b|p12|csr)$/i.test(file)),
    false
  )

  for (const file of tracked.filter((item) => item.endsWith('.json5'))) {
    const content = readProjectFile(file)
    assert.doesNotMatch(content, /(?:keyPassword|storePassword)\s*:/)
    assert.doesNotMatch(content, /C:\\\\Users\\\\[^\\]+/i)
  }
})

test('provides a sanitized local build profile template', () => {
  assert.equal(trackedFiles().includes('build-profile.example.json5'), true)

  const templatePath = join(projectRoot, 'build-profile.example.json5')
  assert.equal(existsSync(templatePath), true)

  const template = readFileSync(templatePath, 'utf8')
  assert.doesNotMatch(template, /signingConfigs|keyPassword|storePassword/)
  assert.doesNotMatch(template, /C:\\\\Users\\\\/i)
  assert.match(template, /['"]API_BASE_URL['"]\s*:\s*['"]http:\/\/127\.0\.0\.1:3000['"]/)
})

test('reads the API base URL from BuildProfile instead of a source literal', () => {
  const apiConstants = readProjectFile(
    'common/src/main/ets/constants/ApiConstants.ets'
  )

  assert.match(apiConstants, /import BuildProfile from ['"]\.\.\/\.\.\/\.\.\/\.\.\/BuildProfile['"]/)
  assert.match(apiConstants, /BASE_URL:\s*string\s*=\s*BuildProfile\.API_BASE_URL/)
  assert.doesNotMatch(apiConstants, /http:\/\/\d{1,3}(?:\.\d{1,3}){3}:\d+/)
})

test('keeps only the server npm lockfile', () => {
  const tracked = trackedFiles()

  assert.equal(existsSync(join(projectRoot, 'package-lock.json')), false)
  assert.equal(existsSync(join(projectRoot, 'server', 'package-lock.json')), true)
  assert.equal(tracked.includes('package-lock.json'), false)
  assert.equal(tracked.includes('server/package-lock.json'), true)
})
