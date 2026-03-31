import type { CodegenConfig } from '@graphql-codegen/cli'
import { documents, schema } from './graphql.config'

const config: CodegenConfig = {
  schema,
  documents,
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
