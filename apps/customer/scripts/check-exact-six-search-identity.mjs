import assert from 'node:assert/strict'
import { readFileSync } from 'node:fs'

import {
  buildLegacyStockSearchParams,
  getStockSearchTicketIdentity,
  isExactSixDigitSearch,
  mergeStockSearchTickets
} from '../utils/stockSearchIdentity.js'

const exactParams = buildLegacyStockSearchParams({
  digits: ['1', '2', '3', '4', '5', '6'],
  storeId: 'store-1',
  limit: 50
}, 'game-1')

assert.equal(exactParams.game_id, 'game-1')
assert.equal(exactParams.number, '123456')
assert.equal(exactParams.store_id, 'store-1')
assert.equal(exactParams.mode, 'random')
assert.equal(exactParams.limit, 50)
for (const key of ['d1', 'd2', 'd3', 'd4', 'd5', 'd6']) {
  assert.equal(exactParams[key], undefined, `exact six search must not send ${key}`)
}

const partialParams = buildLegacyStockSearchParams({
  digits: ['1', '', '3', null, '5', '']
}, 'game-1')

assert.equal(partialParams.number, undefined)
assert.equal(partialParams.mode, 'random')
assert.deepEqual(
  Object.fromEntries(Object.entries(partialParams).filter(([key]) => /^d\d$/.test(key))),
  { d1: '1', d3: '3', d5: '5' }
)

const duplicateRows = [
  { id: 'copy-a', token: 'copy-a', number: '123456' },
  { id: 'copy-b', local_stock_item_id: 'copy-b', full_number: '123456' },
  { id: 'copy-a', token: 'copy-a', lottery_number: '123456' }
]
const exactRows = mergeStockSearchTickets(duplicateRows, { preserveDuplicateFullNumbers: true })
const partialRows = mergeStockSearchTickets(duplicateRows, { preserveDuplicateFullNumbers: false })

assert.equal(isExactSixDigitSearch(['1', '2', '3', '4', '5', '6']), true)
assert.equal(isExactSixDigitSearch(['1', '2', '', '4', '5', '6']), false)
assert.deepEqual(exactRows.map(getStockSearchTicketIdentity), ['copy-a', 'copy-b'])
assert.equal(partialRows.length, 1)
assert.equal(partialRows[0].id, 'copy-a')

const searchPage = readFileSync(new URL('../pages/buy/search.vue', import.meta.url), 'utf8')
const searchUtils = readFileSync(new URL('../utils/stockSearchIdentity.js', import.meta.url), 'utf8')

assert.match(searchPage, /:show-more-link="!lastSearchWasExact"/)
assert.match(searchPage, /lastSearchWasExact\.value = isExactResult/)
assert.match(searchPage, /randomSeed/)
assert.match(searchUtils, /mode: 'random'/)

console.log('PASS exact six stock search params, duplicate row identity, more-link visibility, and random search mode checks')
