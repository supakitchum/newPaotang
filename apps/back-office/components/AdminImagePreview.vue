<template>
  <span v-if="!imageUrl">-</span>
  <button v-else class="np-image-preview" type="button" @click="open = true">
    <img :src="thumbUrl" :alt="label">
  </button>
  <AdminModal v-model="open" :title="label" size="lg">
    <div class="np-image-preview-modal">
      <img :src="imageUrl" :alt="label">
    </div>
  </AdminModal>
</template>

<script setup lang="ts">
const props = withDefaults(defineProps<{
  image?: string | Record<string, any> | null
  label?: string
}>(), {
  image: null,
  label: 'Image',
})

const open = ref(false)

const imageUrl = computed(() => {
  if (typeof props.image === 'string') {
    const value = props.image.trim()

    return value === '-' ? '' : value
  }

  return String(props.image?.full_url || props.image?.url || '').trim()
})

const thumbUrl = computed(() => {
  if (typeof props.image === 'string') {
    const value = props.image.trim()

    return value === '-' ? '' : value
  }

  return String(props.image?.thumb_url || props.image?.full_url || props.image?.url || '').trim()
})
</script>

<style scoped>
.np-image-preview {
  width: 72px;
  height: 48px;
  border: 1px solid #dbe3ef;
  border-radius: 6px;
  padding: 2px;
  background: #fff;
}

.np-image-preview img {
  width: 100%;
  height: 100%;
  display: block;
  object-fit: cover;
  border-radius: 4px;
}

.np-image-preview-modal {
  display: grid;
  place-items: center;
}

.np-image-preview-modal img {
  width: min(100%, 960px);
  max-height: 72vh;
  object-fit: contain;
  border-radius: 8px;
}
</style>
