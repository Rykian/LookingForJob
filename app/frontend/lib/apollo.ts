import { ApolloClient, ApolloLink, HttpLink, InMemoryCache } from '@apollo/client'
import { createConsumer } from '@rails/actioncable'
import * as ActionCableLinkModule from 'graphql-ruby-client/subscriptions/ActionCableLink'

const cable = createConsumer()

const httpLink = new HttpLink({ uri: '/graphql' })

const ActionCableLinkResolved = ActionCableLinkModule.default as
  | typeof ActionCableLinkModule.default
  | { default: typeof ActionCableLinkModule.default }
const ActionCableLink =
  'default' in ActionCableLinkResolved ? ActionCableLinkResolved.default : ActionCableLinkResolved

const link = ApolloLink.split(
  ({ query: { definitions } }) => {
    return definitions.some(
      (definition) =>
        definition.kind === 'OperationDefinition' && definition.operation === 'subscription',
    )
  },
  new ActionCableLink({ cable }),
  httpLink,
)

const client = new ApolloClient({
  link,
  cache: new InMemoryCache(),
})

export default client
