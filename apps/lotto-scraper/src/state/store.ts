import { createClient, type RedisClientType } from 'redis'
import { logger } from '../logger.js'

export class StateStore {
  private client: RedisClientType | null = null
  private fallback = new Map<string, { value: string, expiresAt: number | null }>()

  constructor(private readonly redisUrl: string) {
  }

  async connect() {
    this.client = createClient({ url: this.redisUrl })
    this.client.on('error', (error) => {
      logger.warn({ error }, 'Redis state store error; scraper will keep running with local fallback when needed.')
    })

    await this.client.connect()
  }

  async ready() {
    if (!this.client?.isOpen) {
      return false
    }

    return (await this.client.ping()) === 'PONG'
  }

  async acquireLock(key: string, owner: string, ttlMs: number) {
    if (!this.client?.isOpen) {
      return this.acquireFallbackLock(key, owner, ttlMs)
    }

    const result = await this.client.set(`lotto-scraper:lock:${key}`, owner, {
      NX: true,
      PX: ttlMs
    })

    return result === 'OK'
  }

  async getHash(key: string) {
    if (!this.client?.isOpen) {
      return this.getFallback(`lotto-scraper:hash:${key}`)
    }

    return this.client.get(`lotto-scraper:hash:${key}`)
  }

  async setHash(key: string, hash: string) {
    if (!this.client?.isOpen) {
      this.setFallback(`lotto-scraper:hash:${key}`, hash, null)
      return
    }

    await this.client.set(`lotto-scraper:hash:${key}`, hash)
  }

  async getJson<T>(key: string): Promise<T | null> {
    const raw = !this.client?.isOpen
      ? this.getFallback(key)
      : await this.client.get(key)

    if (!raw) {
      return null
    }

    try {
      return JSON.parse(raw) as T
    } catch (error) {
      logger.warn({ error, key }, 'Invalid JSON in scraper state store; dropping cached value.')

      return null
    }
  }

  async setJson(key: string, value: unknown, ttlMs: number | null = null) {
    const serialized = JSON.stringify(value)

    if (!this.client?.isOpen) {
      this.setFallback(key, serialized, ttlMs === null ? null : Date.now() + ttlMs)
      return
    }

    if (ttlMs === null) {
      await this.client.set(key, serialized)
      return
    }

    await this.client.set(key, serialized, { PX: ttlMs })
  }

  async delete(key: string) {
    if (!this.client?.isOpen) {
      this.fallback.delete(key)
      return
    }

    await this.client.del(key)
  }

  async close() {
    if (this.client?.isOpen) {
      await this.client.quit()
    }
  }

  private acquireFallbackLock(key: string, owner: string, ttlMs: number) {
    const lockKey = `lotto-scraper:lock:${key}`
    const current = this.fallback.get(lockKey)
    const now = Date.now()

    if (current && (current.expiresAt === null || current.expiresAt > now)) {
      return false
    }

    this.setFallback(lockKey, owner, now + ttlMs)

    return true
  }

  private getFallback(key: string) {
    const current = this.fallback.get(key)

    if (!current) {
      return null
    }

    if (current.expiresAt !== null && current.expiresAt <= Date.now()) {
      this.fallback.delete(key)
      return null
    }

    return current.value
  }

  private setFallback(key: string, value: string, expiresAt: number | null) {
    this.fallback.set(key, { value, expiresAt })
  }
}
