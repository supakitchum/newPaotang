import { existsSync, mkdirSync, symlinkSync, writeFileSync } from 'node:fs'
import { dirname, isAbsolute, join, resolve } from 'node:path'

const buildDir = process.env.NUXT_BUILD_DIR

if (!buildDir) {
  process.exit(0)
}

const resolvedBuildDir = isAbsolute(buildDir) ? buildDir : resolve(process.cwd(), buildDir)
mkdirSync(resolvedBuildDir, { recursive: true })

const appNodeModules = resolve(process.cwd(), 'node_modules')
const buildNodeModules = join(resolvedBuildDir, 'node_modules')

if (existsSync(appNodeModules) && !existsSync(buildNodeModules)) {
  symlinkSync(appNodeModules, buildNodeModules, 'dir')
}

const tmpNodeModules = '/tmp/node_modules'

if (isAbsolute(resolvedBuildDir) && existsSync(appNodeModules) && !existsSync(tmpNodeModules)) {
  try {
    mkdirSync(dirname(tmpNodeModules), { recursive: true })
    symlinkSync(appNodeModules, tmpNodeModules, 'dir')
  } catch {
    // Best-effort compatibility for Nuxt's generated relative paths in Docker dev.
  }
}

const shimPath = join(resolvedBuildDir, 'nuxt-paths-shim.mjs')
const packagePath = join(resolvedBuildDir, 'package.json')

writeFileSync(
  shimPath,
  `import { joinRelativeURL } from 'ufo'

const appConfig = globalThis.__NUXT__?.config?.app || {}
const fallbackBaseURL = process.env.NUXT_APP_BASE_URL || '/'
const fallbackBuildAssetsDir = process.env.NUXT_APP_BUILD_ASSETS_DIR || '/_nuxt/'
const fallbackCdnURL = process.env.NUXT_APP_CDN_URL || ''

export function baseURL() {
  return appConfig.baseURL || fallbackBaseURL
}

export function buildAssetsDir() {
  return appConfig.buildAssetsDir || fallbackBuildAssetsDir
}

export function publicAssetsURL(...path) {
  const publicBase = appConfig.cdnURL || fallbackCdnURL || baseURL()
  return path.length ? joinRelativeURL(publicBase, ...path) : publicBase
}

export function buildAssetsURL(...path) {
  return joinRelativeURL(publicAssetsURL(), buildAssetsDir(), ...path)
}
`,
)

writeFileSync(
  packagePath,
  `${JSON.stringify(
    {
      type: 'module',
      imports: {
        '#internal/nuxt/paths': './nuxt-paths-shim.mjs',
      },
    },
    null,
    2,
  )}\n`,
)
