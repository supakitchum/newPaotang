<template>
  <div class="d-flex align-items-center justify-content-center py-5">
    <div class="text-center">
      <h1 class="display-4">404</h1>
      <p class="text-muted">The admin page was not found.</p>
      <NuxtLink to="/admin" class="btn btn-primary btn-wave">Back to dashboard</NuxtLink>
    </div>
  </div>
</template>

<script setup lang="ts">
definePageMeta({ layout: 'admin' })
</script>
