export type DrawWindowPhase = 'idle' | 'warmup' | 'live' | 'tail' | 'done'

export type DrawWindow = {
  phase: DrawWindowPhase
  drawCode: string
  shouldPoll: boolean
  intervalMs: number
}

type PollConfig = {
  timezone: string
  configuredDrawCode: string
  minCrawlDelayMs: number
  warmupPollMs: number
  livePollMinMs: number
  livePollMaxMs: number
  tailPollMinMs: number
  tailPollMaxMs: number
}

export const currentDrawWindow = (now: Date, config: PollConfig): DrawWindow => {
  const parts = bangkokParts(now, config.timezone)
  const drawCode = config.configuredDrawCode || drawCodeFromParts(parts)
  const isDrawDay = config.configuredDrawCode !== '' || parts.day === 1 || parts.day === 16
  const minutes = parts.hour * 60 + parts.minute

  if (!isDrawDay) {
    return idle(drawCode)
  }

  if (minutes < toMinutes('14:45')) {
    return idle(drawCode)
  }

  if (minutes < toMinutes('15:00')) {
    return {
      phase: 'warmup',
      drawCode,
      shouldPoll: true,
      intervalMs: Math.max(config.minCrawlDelayMs, config.warmupPollMs)
    }
  }

  if (minutes < toMinutes('16:30')) {
    return {
      phase: 'live',
      drawCode,
      shouldPoll: true,
      intervalMs: Math.max(config.minCrawlDelayMs, randomBetween(config.livePollMinMs, config.livePollMaxMs))
    }
  }

  if (minutes < toMinutes('18:00')) {
    return {
      phase: 'tail',
      drawCode,
      shouldPoll: true,
      intervalMs: Math.max(config.minCrawlDelayMs, randomBetween(config.tailPollMinMs, config.tailPollMaxMs))
    }
  }

  return {
    phase: 'done',
    drawCode,
    shouldPoll: false,
    intervalMs: 60_000
  }
}

export const applyJitter = (intervalMs: number, ratio = 0.2) => {
  const delta = intervalMs * ratio

  return Math.max(1000, Math.round(intervalMs - delta + Math.random() * delta * 2))
}

const idle = (drawCode: string): DrawWindow => ({
  phase: 'idle',
  drawCode,
  shouldPoll: false,
  intervalMs: 60_000
})

const randomBetween = (min: number, max: number) => Math.round(min + Math.random() * Math.max(0, max - min))

const toMinutes = (value: string) => {
  const [hour, minute] = value.split(':').map(Number)

  return hour * 60 + minute
}

const bangkokParts = (date: Date, timezone: string) => {
  const formatter = new Intl.DateTimeFormat('en-CA', {
    timeZone: timezone,
    year: 'numeric',
    month: '2-digit',
    day: '2-digit',
    hour: '2-digit',
    minute: '2-digit',
    hourCycle: 'h23'
  })
  const parts = Object.fromEntries(formatter.formatToParts(date).map((part) => [part.type, part.value]))

  return {
    year: Number(parts.year),
    month: Number(parts.month),
    day: Number(parts.day),
    hour: Number(parts.hour),
    minute: Number(parts.minute)
  }
}

const drawCodeFromParts = (parts: { year: number, month: number, day: number }) => {
  const buddhistYear = parts.year + 543

  return `${String(parts.day).padStart(2, '0')}${String(parts.month).padStart(2, '0')}${buddhistYear}`
}
