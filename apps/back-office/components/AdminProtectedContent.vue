<script lang="ts">
import { defineComponent, h } from 'vue'

export default defineComponent({
  props: {
    show: {
      type: Boolean,
      default: false,
    },
  },
  setup(props, { slots }) {
    if (import.meta.dev) {
      const nuxtApp = useNuxtApp() as { _isNuxtPageUsed?: boolean }
      nuxtApp._isNuxtPageUsed = true
    }

    return () => {
      if (props.show) {
        return slots.default?.()
      }

      return h('div', { class: 'd-flex align-items-center justify-content-center py-5' }, [
        h('div', { class: 'card custom-card np-admin-restore-card' }, [
          h('div', { class: 'card-body text-center' }, [
            h('div', { class: 'd-flex align-items-center justify-content-center py-5' }, [
              h('div', { class: 'spinner-border text-primary', role: 'status', 'aria-label': 'Loading' }),
              h('span', { class: 'ms-3 text-muted' }, 'Loading...'),
            ]),
            h('h6', { class: 'mt-3 mb-1' }, 'Restoring admin session'),
            h('p', { class: 'text-muted mb-0' }, 'Protected content loads after the browser session is verified.'),
          ]),
        ]),
      ])
    }
  },
})
</script>
