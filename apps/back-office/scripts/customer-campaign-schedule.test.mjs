import assert from 'node:assert/strict'
import test from 'node:test'

import { dateTimeLocalToIso, dateToLocalInputValue } from '../utils/campaignSchedule.mjs'

test('Bangkok campaign schedule round-trips through an offset-aware UTC instant', () => {
  assert.equal(Intl.DateTimeFormat().resolvedOptions().timeZone, 'Asia/Bangkok')

  const requestValue = dateTimeLocalToIso('2026-08-16T13:40')

  assert.equal(requestValue, '2026-08-16T06:40:00.000Z')
  assert.equal(dateToLocalInputValue(new Date(requestValue)), '2026-08-16T13:40')
})

test('campaign schedule conversion rejects an invalid local value', () => {
  assert.throws(() => dateTimeLocalToIso('not-a-date'), RangeError)
})
