import fs from 'node:fs/promises'
import os from 'node:os'
import path from 'node:path'
import process from 'node:process'
import { fileURLToPath } from 'node:url'

const kitRoot = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..')
const textExtensions = new Set(['.ets', '.json', '.json5', '.md', '.mjs', '.ts', '.txt'])

function usage() {
  return [
    'Usage: node HarmonyKit/scripts/new-app.mjs <App Name> [--slug slug] [--tagline text] [--accent #F7B733] [--out dir]',
    'Example: node HarmonyKit/scripts/new-app.mjs Simmer --tagline "Parallel kitchen timers"'
  ].join('\n')
}

function slugify(value) {
  return value
    .trim()
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, '-')
    .replace(/^-+|-+$/g, '')
}

function bundleSegmentFromSlug(slug) {
  const compact = slug.replace(/[^a-z0-9]/g, '')
  if (!compact) {
    throw new Error('App bundle segment must contain at least one letter or number.')
  }
  return /^[a-z]/.test(compact) ? compact : `app${compact}`
}

function toPosixPath(value) {
  return value.split(path.sep).join('/')
}

function parseArgs(args) {
  if (args.includes('--self-test')) {
    return { selfTest: true }
  }

  const nameParts = []
  const options = new Map()
  for (let i = 0; i < args.length; i += 1) {
    const arg = args[i]
    if (arg.startsWith('--')) {
      const value = args[i + 1]
      if (!value || value.startsWith('--')) {
        throw new Error(`Missing value for ${arg}`)
      }
      options.set(arg.slice(2), value)
      i += 1
    } else {
      nameParts.push(arg)
    }
  }

  const name = nameParts.join(' ').trim()
  if (!name) {
    throw new Error(usage())
  }

  const slug = slugify(options.get('slug') || name)
  if (!slug) {
    throw new Error('App slug must contain at least one letter or number.')
  }

  return {
    name,
    slug,
    bundleSegment: bundleSegmentFromSlug(slug),
    tagline: options.get('tagline') || 'Small, polished tool.',
    accent: options.get('accent') || '#F7B733',
    out: path.resolve(options.get('out') || path.join(kitRoot, 'apps'))
  }
}

async function pathExists(filePath) {
  try {
    await fs.access(filePath)
    return true
  } catch {
    return false
  }
}

function replaceTokens(text, replacements) {
  return text
    .replaceAll('{{APP_NAME}}', replacements.name)
    .replaceAll('{{APP_SLUG}}', replacements.slug)
    .replaceAll('{{APP_BUNDLE_SEGMENT}}', replacements.bundleSegment)
    .replaceAll('{{APP_TAGLINE}}', replacements.tagline)
    .replaceAll('{{ACCENT}}', replacements.accent)
    .replaceAll('{{KIT_ROOT}}', replacements.kitRoot)
    .replaceAll('{{UI_PACKAGE_FROM_APP}}', replacements.uiPackageFromApp)
    .replaceAll('{{UI_PACKAGE_FROM_ENTRY}}', replacements.uiPackageFromEntry)
}

function shouldReplaceText(filePath) {
  return textExtensions.has(path.extname(filePath))
}

async function copyTemplate(src, dest, replacements) {
  await fs.mkdir(dest, { recursive: true })
  for (const entry of await fs.readdir(src, { withFileTypes: true })) {
    const targetName = replaceTokens(entry.name, replacements)
    const from = path.join(src, entry.name)
    const to = path.join(dest, targetName)
    if (entry.isDirectory()) {
      await copyTemplate(from, to, replacements)
    } else if (shouldReplaceText(from)) {
      const text = await fs.readFile(from, 'utf8')
      await fs.writeFile(to, replaceTokens(text, replacements))
    } else {
      await fs.copyFile(from, to)
    }
  }
}

async function createApp(config) {
  const template = path.join(kitRoot, 'templates/tool-app')
  await fs.mkdir(config.out, { recursive: true })
  const realOut = await fs.realpath(config.out)
  const realKitRoot = await fs.realpath(kitRoot)
  const destination = path.join(realOut, config.slug)
  if (await pathExists(destination)) {
    throw new Error(`Refusing to overwrite existing app: ${destination}`)
  }
  const uiPackage = path.join(realKitRoot, 'packages/sunpebble_ui')
  const replacements = {
    ...config,
    kitRoot: toPosixPath(realKitRoot),
    uiPackageFromApp: toPosixPath(path.relative(destination, uiPackage)),
    uiPackageFromEntry: toPosixPath(path.relative(path.join(destination, 'entry'), uiPackage))
  }
  await copyTemplate(template, destination, replacements)
  return destination
}

async function selfTest() {
  const temp = await fs.mkdtemp(path.join(os.tmpdir(), 'sunpebble-harmonykit-'))
  const source = path.join(temp, 'template')
  const target = path.join(temp, 'out')
  await fs.mkdir(source, { recursive: true })
  await fs.writeFile(
    path.join(source, '{{APP_SLUG}}.txt'),
    '{{APP_NAME}}|{{APP_SLUG}}|{{APP_BUNDLE_SEGMENT}}|{{APP_TAGLINE}}|{{ACCENT}}|{{KIT_ROOT}}|{{UI_PACKAGE_FROM_APP}}|{{UI_PACKAGE_FROM_ENTRY}}'
  )
  await copyTemplate(source, target, {
    name: 'Demo App',
    slug: 'demo-app',
    bundleSegment: 'demoapp',
    tagline: 'One line',
    accent: '#F7B733',
    kitRoot: '/tmp/HarmonyKit',
    uiPackageFromApp: '../../packages/sunpebble_ui',
    uiPackageFromEntry: '../../../packages/sunpebble_ui'
  })
  const actual = await fs.readFile(path.join(target, 'demo-app.txt'), 'utf8')
  if (actual !== 'Demo App|demo-app|demoapp|One line|#F7B733|/tmp/HarmonyKit|../../packages/sunpebble_ui|../../../packages/sunpebble_ui') {
    throw new Error(`Self-test failed: ${actual}`)
  }
  await fs.rm(temp, { recursive: true, force: true })
}

async function main() {
  const config = parseArgs(process.argv.slice(2))
  if (config.selfTest) {
    await selfTest()
    console.log('ok')
    return
  }
  const destination = await createApp(config)
  console.log(`created ${path.relative(process.cwd(), destination)}`)
}

main().catch((error) => {
  console.error(error.message)
  process.exit(1)
})
