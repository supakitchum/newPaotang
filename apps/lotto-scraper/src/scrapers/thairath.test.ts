import assert from 'node:assert/strict'
import test from 'node:test'
import { buildThairathUrl, parseThairathLottoHtml } from './thairath.js'

test('buildThairathUrl uses ISO draw date query string', () => {
  assert.equal(
    buildThairathUrl('https://www.thairath.co.th/lottery/check', '16062569'),
    'https://www.thairath.co.th/lottery/check?date=2026-06-16'
  )
})

test('parseThairathLottoHtml reads Next.js lottery prizes', () => {
  const result = parseThairathLottoHtml(html({
    prizes: {
      1: ['287184'],
      2: ['327953'],
      3: [],
      4: [],
      5: ['271385', '632212', '271385'],
      6: ['758', '434'],
      7: ['48'],
      10: ['007', '721'],
      11: ['287183', '287185']
    }
  }), '16062569', 'https://www.thairath.co.th/lottery/check?date=2026-06-16')

  assert.equal(result.source, 'thairath')
  assert.equal(result.draw_date, '2026-06-16')
  assert.deepEqual(result.prizes.find((prize) => prize.prize_type === 'first_prize')?.prize_numbers, ['287184'])
  assert.deepEqual(result.prizes.find((prize) => prize.prize_type === 'front3')?.prize_numbers, ['007', '721'])
  assert.deepEqual(result.prizes.find((prize) => prize.prize_type === 'back3')?.prize_numbers, ['758', '434'])
  assert.deepEqual(result.prizes.find((prize) => prize.prize_type === 'back2')?.prize_numbers, ['48'])
  assert.deepEqual(result.prizes.find((prize) => prize.prize_type === 'near_first_prize')?.prize_numbers, ['287183', '287185'])
  assert.deepEqual(result.prizes.find((prize) => prize.prize_type === 'fifth_prize')?.prize_numbers.slice(0, 3), ['271385', '632212', 'xxxxxx'])
  assert.equal(result.is_complete, false)
})

test('parseThairathLottoHtml can keep platform draw code while using trigger draw date', () => {
  const result = parseThairathLottoHtml(html({
    prizes: {
      1: ['287184']
    }
  }), '01062569', 'https://www.thairath.co.th/lottery/check?date=2026-06-16', '2026-06-16T10:00:00.000Z', '2026-06-16')

  assert.equal(result.draw_code, '01062569')
  assert.equal(result.draw_date, '2026-06-16')
})

test('parseThairathLottoHtml converts uppercase pending marks to placeholders', () => {
  const result = parseThairathLottoHtml(html({
    prizes: {
      1: ['X', 'X', 'X', 'X', 'X', 'X'],
      6: ['XXX', 'XXX'],
      7: ['XX'],
      10: ['X', 'X', 'X'],
      11: ['XXXXXX', 'XXXXXX']
    }
  }), '16062569', 'https://www.thairath.co.th/lottery/check?date=2026-06-16')

  assert.equal(result.completion_percent, 0)
  assert.deepEqual(result.prizes.find((prize) => prize.prize_type === 'first_prize')?.prize_numbers, ['xxxxxx'])
  assert.deepEqual(result.prizes.find((prize) => prize.prize_type === 'front3')?.prize_numbers, ['xxx', 'xxx'])
  assert.deepEqual(result.prizes.find((prize) => prize.prize_type === 'back3')?.prize_numbers, ['xxx', 'xxx'])
  assert.deepEqual(result.prizes.find((prize) => prize.prize_type === 'back2')?.prize_numbers, ['xx'])
})

test('parseThairathLottoHtml computes nearby prizes when source omits them after first prize appears', () => {
  const result = parseThairathLottoHtml(html({
    prizes: {
      1: ['000000'],
      11: []
    }
  }), '16062569', 'https://www.thairath.co.th/lottery/check?date=2026-06-16')

  assert.deepEqual(result.prizes.find((prize) => prize.prize_type === 'near_first_prize')?.prize_numbers, ['999999', '000001'])
})

const html = (values: { prizes: Record<string, string[]> }) => `
  <html>
    <body>
      <script id="__NEXT_DATA__" type="application/json">
        ${JSON.stringify({
          props: {
            initialState: {
              lottery: {
                data: {
                  items: {
                    prizes: Object.fromEntries(Object.entries(values.prizes).map(([key, data]) => [
                      key,
                      { info: [data.length, 0], data }
                    ]))
                  }
                }
              }
            }
          }
        })}
      </script>
    </body>
  </html>
`
