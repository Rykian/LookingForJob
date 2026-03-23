import type { CodegenConfig } from '@graphql-codegen/cli'

const config: CodegenConfig = {
  schema: 'tmp/schema.graphql',
  documents: ['app/frontend/**/*.{ts,tsx}'],
  generates: {
    'app/frontend/graphql/generated.ts': {
      plugins: ['typescript', 'typescript-operations', 'typed-document-node'],
      config: {
        scalars: {
          JSON: 'Record<string, unknown>',
        },
      },
    },
  },
  ignoreNoDocuments: true,
}

export default config
