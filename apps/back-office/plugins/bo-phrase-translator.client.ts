export default defineNuxtPlugin(() => {
  const adminLocale = useAdminLocale()
  const originalText = new WeakMap<Text, string>()
  const originalAttributes = new WeakMap<Element, Map<string, string>>()
  const translatedAttributes = ['placeholder', 'title', 'aria-label', 'alt', 'data-bs-title', 'data-bs-original-title']

  let scheduled = false

  const normalize = (value: string) => value.replace(/\s+/g, ' ').trim()
  const currentMap = () => adminLocale.phraseMap.value
  const translatePhrase = (source: unknown) => {
    const text = String(source || '')
    const normalized = normalize(text)
    const translated = normalized ? currentMap()[normalized] : ''

    return translated ? text.replace(normalized, translated) : text
  }

  const shouldSkipTextElement = (element: Element | null): boolean => {
    if (!element) {
      return false
    }

    return Boolean(element.closest([
      'script',
      'style',
      'textarea',
      'input',
      'code',
      'pre',
      '[data-i18n-skip]',
      '.translation-copy',
      '.translation-textarea',
    ].join(',')))
  }

  const shouldSkipAttributeElement = (element: Element | null): boolean => {
    if (!element) {
      return false
    }

    return Boolean(element.closest([
      'script',
      'style',
      'code',
      'pre',
      '[data-i18n-skip]',
      '.translation-copy',
      '.translation-textarea',
    ].join(',')))
  }

  const translateTextNode = (node: Text, phrases: Record<string, string>) => {
    if (shouldSkipTextElement(node.parentElement)) {
      return
    }

    if (!originalText.has(node)) {
      originalText.set(node, node.nodeValue || '')
    }

    const source = originalText.get(node) || ''
    const normalized = normalize(source)
    const translated = normalized ? phrases[normalized] : ''
    const nextValue = translated ? source.replace(normalized, translated) : source

    if (node.nodeValue !== nextValue) {
      node.nodeValue = nextValue
    }
  }

  const setAttributeIfChanged = (element: Element, attr: string, value: string) => {
    if (element.getAttribute(attr) !== value) {
      element.setAttribute(attr, value)
    }
  }

  const translateElementAttributes = (element: Element, phrases: Record<string, string>) => {
    if (shouldSkipAttributeElement(element)) {
      return
    }

    let attrs = originalAttributes.get(element)
    if (!attrs) {
      attrs = new Map()
      originalAttributes.set(element, attrs)
    }

    for (const attr of translatedAttributes) {
      const value = attrs.get(attr) || element.getAttribute(attr) || ''
      if (!value) {
        continue
      }

      if (!attrs.has(attr)) {
        attrs.set(attr, value)
      }

      const translated = phrases[normalize(value)]
      setAttributeIfChanged(element, attr, translated || value)
    }
  }

  const walk = (root: ParentNode) => {
    const phrases = currentMap()
    const walker = document.createTreeWalker(root, NodeFilter.SHOW_TEXT | NodeFilter.SHOW_ELEMENT)

    let node = walker.currentNode
    while (node) {
      if (node.nodeType === Node.TEXT_NODE) {
        translateTextNode(node as Text, phrases)
      } else if (node.nodeType === Node.ELEMENT_NODE) {
        translateElementAttributes(node as Element, phrases)
      }

      node = walker.nextNode()
    }
  }

  const schedule = () => {
    if (scheduled) {
      return
    }

    scheduled = true
    window.requestAnimationFrame(() => {
      scheduled = false
      walk(document.body)
    })
  }

  onNuxtReady(() => {
    const nativeConfirm = window.confirm.bind(window)
    const nativeAlert = window.alert.bind(window)
    window.confirm = (message?: string) => nativeConfirm(translatePhrase(message))
    window.alert = (message?: string) => nativeAlert(translatePhrase(message))

    schedule()

    const observer = new MutationObserver((mutations) => {
      if (mutations.some((mutation) => mutation.addedNodes.length > 0 || mutation.type === 'characterData' || mutation.type === 'attributes')) {
        schedule()
      }
    })

    observer.observe(document.body, {
      childList: true,
      subtree: true,
      characterData: true,
      attributes: true,
      attributeFilter: translatedAttributes,
    })
  })

  watch([adminLocale.locale, adminLocale.runtimePhrases], () => {
    nextTick(schedule)
  }, { deep: true })
})
