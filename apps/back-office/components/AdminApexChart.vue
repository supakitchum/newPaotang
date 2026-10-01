<template>
  <div ref="chartEl" class="admin-apex-chart" :style="{ minHeight: `${height}px` }" />
</template>

<script setup lang="ts">
const props = withDefaults(defineProps<{
  type: string
  height?: number
  options?: Record<string, any>
  series?: any[]
}>(), {
  height: 280,
  options: () => ({}),
  series: () => [],
})

const chartEl = ref<HTMLElement | null>(null)
let chart: any = null
let ApexChartsCtor: any = null
let renderToken = 0

async function ensureApexCharts() {
  if (ApexChartsCtor) return ApexChartsCtor
  const module = await import('apexcharts')
  ApexChartsCtor = module.default || module
  return ApexChartsCtor
}

async function renderChart() {
  if (!process.client || !chartEl.value) return
  const token = ++renderToken
  const ApexCharts = await ensureApexCharts()
  if (token !== renderToken || !chartEl.value) return
  if (chart) {
    chart.destroy()
    chart = null
  }
  chart = new ApexCharts(chartEl.value, {
    ...props.options,
    chart: {
      toolbar: { show: false },
      animations: { enabled: true },
      ...(props.options?.chart || {}),
      type: props.type,
      height: props.height,
    },
    series: props.series,
  })
  await chart.render()
}

watch(
  () => [props.type, props.height, props.options, props.series],
  () => {
    void renderChart()
  },
  { deep: true },
)

onMounted(() => {
  void renderChart()
})

onBeforeUnmount(() => {
  renderToken++
  if (chart) {
    chart.destroy()
    chart = null
  }
})
</script>

<style scoped>
.admin-apex-chart {
  min-height: 180px;
  width: 100%;
}

.admin-apex-chart-loading {
  align-items: center;
  color: var(--default-text-color);
  display: flex;
  font-size: .8125rem;
  justify-content: center;
  opacity: .65;
}
</style>
