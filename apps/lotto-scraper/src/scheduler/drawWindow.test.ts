import assert from 'node:assert/strict'
import test from 'node:test'
import { currentDrawWindow } from './drawWindow.js'

const baseConfig = {
  timezone: 'Asia/Bangkok',
  configuredDrawCode: '',
  minCrawlDelayMs: 10000,
  warmupPollMs: 60000,
  livePollMinMs: 10000,
  livePollMaxMs: 15000,
  tailPollMinMs: 30000,
  tailPollMaxMs: 60000
}

test('currentDrawWindow idles outside draw days', () => {
  const window = currentDrawWindow(new Date('2026-05-26T08:00:00.000Z'), baseConfig)

  assert.equal(window.phase, 'idle')
  assert.equal(window.shouldPoll, false)
})

test('currentDrawWindow warms up before 15:00 on draw day', () => {
  const window = currentDrawWindow(new Date('2026-06-01T07:50:00.000Z'), baseConfig)

  assert.equal(window.phase, 'warmup')
  assert.equal(window.drawCode, '01062569')
  assert.equal(window.shouldPoll, true)
})

test('currentDrawWindow polls live after 15:00 on draw day', () => {
  const window = currentDrawWindow(new Date('2026-06-01T08:05:00.000Z'), baseConfig)

  assert.equal(window.phase, 'live')
  assert.equal(window.shouldPoll, true)
  assert.ok(window.intervalMs >= 10000)
})

test('configured draw code enables manual draw polling window', () => {
  const window = currentDrawWindow(new Date('2026-05-26T08:05:00.000Z'), {
    ...baseConfig,
    configuredDrawCode: '01062569'
  })

  assert.equal(window.phase, 'live')
  assert.equal(window.drawCode, '01062569')
})
