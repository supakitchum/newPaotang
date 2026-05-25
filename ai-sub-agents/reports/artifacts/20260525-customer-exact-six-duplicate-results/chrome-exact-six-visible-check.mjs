import { writeFile } from 'node:fs/promises'
import { createRequire } from 'node:module'

const require = createRequire(new URL('../../../../apps/customer/package.json', import.meta.url))
const WebSocket = require('ws')

const port = Number(process.env.CHROME_DEBUG_PORT || 9223)
const appUrl = process.env.QA_CUSTOMER_URL || 'http://localhost:3010'
const artifactDir = process.env.QA_ARTIFACT_DIR || '.'
const phone = process.env.QA_CUSTOMER_PHONE || '0806543210'
const password = process.env.QA_CUSTOMER_PASSWORD || 'qa-password-654321'
const exactNumber = process.env.QA_EXACT_NUMBER || '654321'

const json = async (url, init) => {
  const response = await fetch(url, init)

  if (!response.ok) {
    throw new Error(`${url} returned ${response.status}`)
  }

  return response.json()
}

class Cdp {
  constructor(wsUrl) {
    this.wsUrl = wsUrl
    this.nextId = 1
    this.pending = new Map()
  }

  async connect() {
    this.ws = new WebSocket(this.wsUrl)

    await new Promise((resolve, reject) => {
      this.ws.once('open', resolve)
      this.ws.once('error', reject)
    })

    this.ws.on('message', (buffer) => {
      const message = JSON.parse(buffer.toString())

      if (!message.id) {
        return
      }

      const pending = this.pending.get(message.id)
      if (!pending) {
        return
      }

      this.pending.delete(message.id)

      if (message.error) {
        pending.reject(new Error(`${message.error.message}: ${JSON.stringify(message.error.data || '')}`))
        return
      }

      pending.resolve(message.result || {})
    })
  }

  send(method, params = {}) {
    const id = this.nextId++
    const payload = JSON.stringify({ id, method, params })

    return new Promise((resolve, reject) => {
      this.pending.set(id, { resolve, reject })
      this.ws.send(payload)
    })
  }

  close() {
    this.ws?.close()
  }
}

const waitFor = async (cdp, expression, timeoutMs = 15000) => {
  const started = Date.now()

  while (Date.now() - started < timeoutMs) {
    const result = await cdp.send('Runtime.evaluate', {
      expression,
      awaitPromise: true,
      returnByValue: true
    })

    if (result.result?.value) {
      return result.result.value
    }

    await new Promise((resolve) => setTimeout(resolve, 250))
  }

  throw new Error(`Timed out waiting for expression: ${expression}`)
}

const login = await json(`${appUrl}/api/v1/customer/auth/login`, {
  method: 'POST',
  headers: {
    accept: 'application/json',
    'content-type': 'application/json'
  },
  body: JSON.stringify({
    username: phone,
    phone,
    password
  })
})

if (!login.token || !login.refresh_token) {
  throw new Error('Login did not return both access and refresh tokens')
}

const targets = await json(`http://127.0.0.1:${port}/json/list`)
const target = targets.find((item) => item.type === 'page' && item.webSocketDebuggerUrl) || targets[0]

if (!target?.webSocketDebuggerUrl) {
  throw new Error('No debuggable Chrome page target found')
}

const cdp = new Cdp(target.webSocketDebuggerUrl)
await cdp.connect()

try {
  await cdp.send('Page.enable')
  await cdp.send('Runtime.enable')
  await cdp.send('Network.enable')
  await cdp.send('Network.setCookie', {
    url: `${appUrl}/`,
    name: 'auth_token_localhost',
    value: login.token,
    path: '/',
    sameSite: 'Lax'
  })
  await cdp.send('Network.setCookie', {
    url: `${appUrl}/`,
    name: 'auth_refresh_token_localhost',
    value: login.refresh_token,
    path: '/',
    sameSite: 'Lax'
  })

  await cdp.send('Page.navigate', { url: `${appUrl}/buy/search` })
  await waitFor(cdp, 'location.pathname === "/buy/search" && document.querySelectorAll(".draw-box-input").length === 6')

  await cdp.send('Runtime.evaluate', {
    expression: `
      (async () => {
        const digits = ${JSON.stringify(exactNumber)}.split('');
        const inputs = Array.from(document.querySelectorAll('.draw-box-input'));
        for (let index = 0; index < digits.length; index += 1) {
          const input = inputs[index];
          input.focus();
          input.value = digits[index];
          input.dispatchEvent(new InputEvent('input', {
            bubbles: true,
            data: digits[index],
            inputType: 'insertText'
          }));
          await new Promise((resolve) => setTimeout(resolve, 40));
        }
        const button = Array.from(document.querySelectorAll('button'))
          .find((candidate) => candidate.textContent.includes('ค้นหาเลข'));
        button.click();
        return true;
      })()
    `,
    awaitPromise: true,
    returnByValue: true
  })

  await waitFor(cdp, `
    Array.from(document.querySelectorAll('.lottery-row:not(.is-lazy) .ticket-number'))
      .map((node) => node.textContent.replace(/\\D/g, ''))
      .filter((number) => number === ${JSON.stringify(exactNumber)})
      .length >= 3
  `)

  const evidence = await cdp.send('Runtime.evaluate', {
    expression: `
      (() => {
        const rows = Array.from(document.querySelectorAll('.lottery-row:not(.is-lazy)'));
        const tickets = rows.map((row, index) => ({
          index,
          number: Array.from(row.querySelectorAll('.ticket-number span'))
            .map((digit) => digit.textContent || '')
            .join(''),
          count_badge: row.querySelector('.ticket-count-badge')?.textContent?.trim() || null,
          text: row.innerText.replace(/\\s+/g, ' ').trim()
        }));

        return {
          url: location.href,
          title: document.title,
          search_digits: Array.from(document.querySelectorAll('.draw-box-input')).map((input) => input.value).join(''),
          result_row_count: rows.length,
          exact_number_row_count: tickets.filter((ticket) => ticket.number === ${JSON.stringify(exactNumber)}).length,
          tickets,
          page_text_sample: document.body.innerText.replace(/\\s+/g, ' ').trim().slice(0, 2000)
        };
      })()
    `,
    returnByValue: true
  })

  const screenshot = await cdp.send('Page.captureScreenshot', {
    format: 'png',
    captureBeyondViewport: true,
    fromSurface: true
  })

  await writeFile(`${artifactDir}/chrome-cdp-exact-six-results.json`, JSON.stringify(evidence.result.value, null, 2))
  await writeFile(`${artifactDir}/chrome-cdp-exact-six-results.png`, Buffer.from(screenshot.data, 'base64'))
  console.log(JSON.stringify(evidence.result.value, null, 2))
} finally {
  cdp.close()
}
