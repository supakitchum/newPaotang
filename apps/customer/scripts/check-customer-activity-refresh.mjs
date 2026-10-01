import assert from 'node:assert/strict'
import test from 'node:test'
import { setTimeout as delay } from 'node:timers/promises'
import { useCustomerActivityRefresh } from '../composables/useCustomerActivityRefresh.ts'

test('activity refresh responds to settlement and resume without stale listeners', async () => {
  const windowTarget = new EventTarget()
  const documentTarget = new EventTarget()
  documentTarget.hidden = false
  const originals = ['window', 'document', 'onMounted', 'onBeforeUnmount']
    .map((key) => [key, Object.getOwnPropertyDescriptor(globalThis, key)])
  let mount
  let unmount
  Object.assign(globalThis, {
    window: windowTarget,
    document: documentTarget,
    onMounted: (callback) => { mount = callback },
    onBeforeUnmount: (callback) => { unmount = callback }
  })
  try {
    let reloads = 0
    useCustomerActivityRefresh(async () => { reloads++ })
    mount()
    windowTarget.dispatchEvent(new Event('customer:purchase-settled'))
    windowTarget.dispatchEvent(new Event('focus'))
    await delay(100)
    assert.equal(reloads, 1)

    documentTarget.hidden = true
    documentTarget.dispatchEvent(new Event('visibilitychange'))
    await delay(100)
    assert.equal(reloads, 1)
    documentTarget.hidden = false
    documentTarget.dispatchEvent(new Event('visibilitychange'))
    await delay(100)
    assert.equal(reloads, 2)

    windowTarget.dispatchEvent(new Event('customer:purchase-settled'))
    unmount()
    await delay(100)
    windowTarget.dispatchEvent(new Event('focus'))
    await delay(100)
    assert.equal(reloads, 2)
  } finally {
    unmount?.()
    for (const [key, descriptor] of originals) {
      if (descriptor) Object.defineProperty(globalThis, key, descriptor)
      else delete globalThis[key]
    }
  }
})
