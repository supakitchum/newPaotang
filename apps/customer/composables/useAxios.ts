import type { AxiosInstance } from 'axios'

export const useAxios = (): AxiosInstance => {
  return useNuxtApp().$axios
}

export const useApi = (): AxiosInstance => {
  return useNuxtApp().$api
}
