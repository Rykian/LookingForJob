import type { SimpleIcon } from 'simple-icons'
import {
  siAngular,
  siAstro,
  siDjango,
  siDocker,
  siElasticsearch,
  siExpress,
  siFirebase,
  siGit,
  siGo,
  siGooglecloud,
  siGraphql,
  siJavascript,
  siKotlin,
  siKubernetes,
  siLaravel,
  siMongodb,
  siMysql,
  siNestjs,
  siNextdotjs,
  siNginx,
  siNodedotjs,
  siPhp,
  siPostgresql,
  siPrisma,
  siPython,
  siReact,
  siRedis,
  siRuby,
  siRubyonrails,
  siRust,
  siSolid,
  siSupabase,
  siSvelte,
  siSwift,
  siTailwindcss,
  siTerraform,
  siTypescript,
  siVercel,
  siVuedotjs,
} from 'simple-icons'

const ICON_MAP: Record<string, SimpleIcon> = {
  angular: siAngular,
  astro: siAstro,
  django: siDjango,
  docker: siDocker,
  elasticsearch: siElasticsearch,
  express: siExpress,
  expressjs: siExpress,
  firebase: siFirebase,
  git: siGit,
  go: siGo,
  golang: siGo,
  googlecloud: siGooglecloud,
  gcp: siGooglecloud,
  graphql: siGraphql,
  javascript: siJavascript,
  js: siJavascript,
  kotlin: siKotlin,
  kubernetes: siKubernetes,
  k8s: siKubernetes,
  laravel: siLaravel,
  mongodb: siMongodb,
  mysql: siMysql,
  nestjs: siNestjs,
  nextjs: siNextdotjs,
  nginx: siNginx,
  nodejs: siNodedotjs,
  php: siPhp,
  postgresql: siPostgresql,
  postgres: siPostgresql,
  prisma: siPrisma,
  python: siPython,
  react: siReact,
  reactjs: siReact,
  redis: siRedis,
  ruby: siRuby,
  rails: siRubyonrails,
  rubyonrails: siRubyonrails,
  rust: siRust,
  solid: siSolid,
  solidjs: siSolid,
  supabase: siSupabase,
  svelte: siSvelte,
  swift: siSwift,
  tailwind: siTailwindcss,
  tailwindcss: siTailwindcss,
  terraform: siTerraform,
  typescript: siTypescript,
  ts: siTypescript,
  vercel: siVercel,
  vue: siVuedotjs,
  vuejs: siVuedotjs,
}

export function TechIcon({ name }: { name: string }) {
  const key = name.toLowerCase().replace(/[\s.]/g, '')
  const icon = ICON_MAP[key]
  if (!icon) return null
  return (
    <svg
      width="14"
      height="14"
      viewBox="0 0 24 24"
      fill={`#${icon.hex}`}
      aria-label={name}
      title={name}
      role="img"
    >
      <path d={icon.path} />
    </svg>
  )
}
