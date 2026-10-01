export interface SerializableError {
  message: string
  status?: number
  code?: string
  name?: string
}

const isRecord = (value: unknown): value is Record<string, unknown> => (
  Boolean(value) && typeof value === 'object'
)

const stringValue = (value: unknown) => {
  if (typeof value !== 'string') {
    return undefined
  }

  const normalized = value.trim()

  return normalized || undefined
}

const numberValue = (value: unknown) => {
  const normalized = typeof value === 'number' ? value : Number(value)

  return Number.isFinite(normalized) ? normalized : undefined
}

const getNestedRecord = (source: Record<string, unknown>, key: string) => {
  const value = source[key]

  return isRecord(value) ? value : null
}

export const toSerializableError = (error: unknown): SerializableError => {
  if (typeof error === 'string') {
    return { message: stringValue(error) || 'Request failed' }
  }

  if (!isRecord(error)) {
    return { message: 'Request failed' }
  }

  const response = getNestedRecord(error, 'response')
  const responseData = response ? getNestedRecord(response, 'data') : null
  const responseError = responseData ? getNestedRecord(responseData, 'error') : null

  const message = (
    stringValue(error.message) ||
    stringValue(error.statusMessage) ||
    (responseError ? stringValue(responseError.message) : undefined) ||
    (responseData ? stringValue(responseData.message) : undefined) ||
    'Request failed'
  )
  const status = (
    numberValue(error.status) ||
    numberValue(error.statusCode) ||
    (response ? numberValue(response.status) : undefined) ||
    (response ? numberValue(response.statusCode) : undefined)
  )
  const code = (
    stringValue(error.code) ||
    (responseError ? stringValue(responseError.code) : undefined) ||
    (responseData ? stringValue(responseData.code) : undefined)
  )
  const name = stringValue(error.name)

  return {
    message,
    ...(status ? { status } : {}),
    ...(code ? { code } : {}),
    ...(name ? { name } : {})
  }
}
