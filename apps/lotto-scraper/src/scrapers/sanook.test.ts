import assert from 'node:assert/strict'
import test from 'node:test'
import { drawDateFromCode, parseSanookLottoHtml } from './sanook.js'

test('drawDateFromCode converts Buddhist year draw codes', () => {
  assert.equal(drawDateFromCode('01062569'), '2026-06-01')
})

test('parseSanookLottoHtml reads pending placeholders', () => {
  const result = parseSanookLottoHtml(html({
    first: 'xxxxxx',
    front3: ['xxx', 'xxx'],
    back3: ['xxx', 'xxx'],
    back2: 'xx',
    second: ['xxxxxx', 'xxxxxx', 'xxxxxx', 'xxxxxx', 'xxxxxx']
  }), '01062569', 'https://news.sanook.com/lotto/check/01062569/')

  assert.equal(result.completion_percent, 0)
  assert.equal(result.is_complete, false)
  assert.deepEqual(result.prizes.find((prize) => prize.prize_type === 'first_prize')?.prize_numbers, ['xxxxxx'])
  assert.deepEqual(result.prizes.find((prize) => prize.prize_type === 'back2')?.prize_numbers, ['xx'])
})

test('parseSanookLottoHtml reads partial results and pads missing rows', () => {
  const result = parseSanookLottoHtml(html({
    first: '123456',
    front3: ['111', '222'],
    back3: ['333', 'xxx'],
    back2: '44',
    near: ['รอผล', '-'],
    second: ['555555']
  }), '01062569', 'https://news.sanook.com/lotto/check/01062569/')

  assert.equal(result.is_complete, false)
  assert.deepEqual(result.prizes.find((prize) => prize.prize_type === 'first_prize')?.prize_numbers, ['123456'])
  assert.deepEqual(result.prizes.find((prize) => prize.prize_type === 'near_first_prize')?.prize_numbers, ['123455', '123457'])
  assert.deepEqual(result.prizes.find((prize) => prize.prize_type === 'second_prize')?.prize_numbers, ['555555', 'xxxxxx', 'xxxxxx', 'xxxxxx', 'xxxxxx'])
  assert.ok(result.completion_percent > 0)
  assert.ok(result.payload_hash.length >= 16)
})

test('parseSanookLottoHtml wraps computed nearby prizes at numeric boundaries', () => {
  const lower = parseSanookLottoHtml(html({
    first: '000000',
    front3: ['xxx', 'xxx'],
    back3: ['xxx', 'xxx'],
    back2: 'xx',
    second: []
  }), '16052569', 'https://news.sanook.com/lotto/check/16052569/')
  const upper = parseSanookLottoHtml(html({
    first: '999999',
    front3: ['xxx', 'xxx'],
    back3: ['xxx', 'xxx'],
    back2: 'xx',
    second: []
  }), '16052569', 'https://news.sanook.com/lotto/check/16052569/')

  assert.deepEqual(lower.prizes.find((prize) => prize.prize_type === 'near_first_prize')?.prize_numbers, ['999999', '000001'])
  assert.deepEqual(upper.prizes.find((prize) => prize.prize_type === 'near_first_prize')?.prize_numbers, ['999998', '000000'])
})

test('parseSanookLottoHtml converts invalid pending labels to placeholders', () => {
  const result = parseSanookLottoHtml(html({
    first: 'รอผล',
    front3: ['-', 'รอผล'],
    back3: ['รอผล', 'xxx'],
    back2: '-',
    near: ['123456', 'รอผล'],
    second: ['55555', '1234567', 'รอผล', '-', 'xxxxxx']
  }), '16052569', 'https://news.sanook.com/lotto/check/16052569/')

  assert.deepEqual(result.prizes.find((prize) => prize.prize_type === 'first_prize')?.prize_numbers, ['xxxxxx'])
  assert.deepEqual(result.prizes.find((prize) => prize.prize_type === 'front3')?.prize_numbers, ['xxx', 'xxx'])
  assert.deepEqual(result.prizes.find((prize) => prize.prize_type === 'back2')?.prize_numbers, ['xx'])
  assert.deepEqual(result.prizes.find((prize) => prize.prize_type === 'near_first_prize')?.prize_numbers, ['xxxxxx', 'xxxxxx'])
  assert.deepEqual(result.prizes.find((prize) => prize.prize_type === 'second_prize')?.prize_numbers, ['xxxxxx', 'xxxxxx', 'xxxxxx', 'xxxxxx', 'xxxxxx'])
})

test('parseSanookLottoHtml removes duplicate live numbers in the same prize group', () => {
  const result = parseSanookLottoHtml(html({
    first: 'xxxxxx',
    front3: ['xxx', 'xxx'],
    back3: ['xxx', 'xxx'],
    back2: 'xx',
    second: [],
    fifth: ['086728', '607331', '086728', '607331', '123456']
  }), '16062569', 'https://news.sanook.com/lotto/check/16062569/')
  const fifthPrizeNumbers = result.prizes.find((prize) => prize.prize_type === 'fifth_prize')?.prize_numbers

  assert.deepEqual(fifthPrizeNumbers?.slice(0, 5), ['086728', '607331', '123456', 'xxxxxx', 'xxxxxx'])
  assert.equal(fifthPrizeNumbers?.filter((number) => number === '086728').length, 1)
  assert.equal(fifthPrizeNumbers?.filter((number) => number === '607331').length, 1)
  assert.equal(fifthPrizeNumbers?.length, 100)
})

const html = (values: {
  first: string
  front3: string[]
  back3: string[]
  back2: string
  near?: string[]
  second: string[]
  fifth?: string[]
}) => `
  <div class="lottocheck__resize">
    <div class="lottocheck__sec lottocheck__sec--bdnone">
      <div class="lottocheck__column">
        <span class="default-font--reward">รางวัลที่ 1</span>
        <strong class="lotto__number lotto__number--first">${values.first}</strong>
      </div>
      <div class="lottocheck__column">
        <span class="default-font--reward">เลขหน้า 3 ตัว</span>
        ${values.front3.map((number) => `<strong class="lotto__number">${number}</strong>`).join('')}
      </div>
      <div class="lottocheck__column">
        <span class="default-font--reward">เลขท้าย 3 ตัว</span>
        ${values.back3.map((number) => `<strong class="lotto__number">${number}</strong>`).join('')}
      </div>
      <div class="lottocheck__column">
        <span class="default-font--reward">เลขท้าย 2 ตัว</span>
        <strong class="lotto__number">${values.back2}</strong>
      </div>
    </div>
    <div class="lottocheck__sec--nearby lottocheck__sec">
      <span class="default-font--reward">รางวัลข้างเคียงรางวัลที่ 1</span>
      ${(values.near || ['xxxxxx', 'xxxxxx']).map((number) => `<strong class="lotto__number">${number}</strong>`).join('')}
    </div>
    <div class="lottocheck__sec">
      <span class="default-font--reward">รางวัลที่ 2 มี 5 รางวัล</span>
      ${values.second.map((number) => `<span class="lotto__number">${number}</span>`).join('')}
    </div>
    <div class="lottocheck__sec"><span class="default-font--reward">รางวัลที่ 3</span></div>
    <div class="lottocheck__sec"><span class="default-font--reward">รางวัลที่ 4</span></div>
    <div class="lottocheck__sec">
      <span class="default-font--reward">รางวัลที่ 5</span>
      ${(values.fifth || []).map((number) => `<span class="lotto__number">${number}</span>`).join('')}
    </div>
  </div>
`
