const YOUTUBE_VIDEO_ID_PATTERN = /^[A-Za-z0-9_-]{11}$/

const isAllowedHost = (host, domain) => host === domain || host.endsWith(`.${domain}`)

const firstPathSegment = (pathname) => pathname.split('/').filter(Boolean)[0] || ''

const youtubePathVideoId = (url) => {
  const segments = url.pathname.split('/').filter(Boolean)
  const route = segments[0] || ''

  if (route === 'watch') {
    return url.searchParams.get('v') || ''
  }

  if (['embed', 'live', 'shorts', 'v'].includes(route)) {
    return segments[1] || ''
  }

  return ''
}

export const sanitizeYoutubeEmbedUrl = (value) => {
  if (typeof value !== 'string') {
    return ''
  }

  const rawUrl = value.trim()

  if (!rawUrl) {
    return ''
  }

  let url

  try {
    url = new URL(rawUrl)
  } catch {
    return ''
  }

  if (!['http:', 'https:'].includes(url.protocol)) {
    return ''
  }

  const host = url.hostname.toLowerCase()
  const videoId = isAllowedHost(host, 'youtu.be')
    ? firstPathSegment(url.pathname)
    : isAllowedHost(host, 'youtube.com') || isAllowedHost(host, 'youtube-nocookie.com')
      ? youtubePathVideoId(url)
      : ''

  return YOUTUBE_VIDEO_ID_PATTERN.test(videoId)
    ? `https://www.youtube.com/embed/${videoId}`
    : ''
}
