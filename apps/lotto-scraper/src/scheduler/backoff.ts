const backoffSteps = [60_000, 120_000, 300_000, 600_000]

export class BackoffState {
  private attempt = 0
  private until = 0

  active(now = Date.now()) {
    return this.until > now
  }

  remainingMs(now = Date.now()) {
    return Math.max(0, this.until - now)
  }

  recordFailure(now = Date.now()) {
    const delay = backoffSteps[Math.min(this.attempt, backoffSteps.length - 1)]
    this.attempt += 1
    this.until = now + delay

    return delay
  }

  recordSuccess() {
    this.attempt = 0
    this.until = 0
  }
}

export const shouldBackoffForStatus = (statusCode: number | undefined) => {
  if (!statusCode) {
    return false
  }

  return statusCode === 403 || statusCode === 429 || statusCode >= 500
}
