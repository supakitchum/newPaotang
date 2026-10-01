<template>
  <AdminPartnerLotteryBranding :partner-id="partnerId" />
</template>

<script setup lang="ts">
definePageMeta({ layout: 'admin' })

const route = useRoute()
const partnerId = computed(() => String(route.params.partner_id || ''))
</script>

