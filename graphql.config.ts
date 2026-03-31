// graphql.config.ts
// Shared config for GraphQL tools and codegen

const schema = 'tmp/schema.graphql'
const documents = ['app/frontend/**/*.{ts,tsx}']

const config = {
  schema,
  documents,
  extensions: {
    codegen: require('./codegen'),
  },
}

export default config
export { documents, schema }
