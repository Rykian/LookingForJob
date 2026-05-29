import { gql } from '@apollo/client'

export const PROVIDERS_QUERY = gql`
  query Providers {
    providers
  }
`

export const TECHNOLOGIES_QUERY = gql`
  query Technologies {
    technologies
  }
`

export const LAUNCH_DISCOVERY_MUTATION = gql`
  mutation LaunchDiscovery($keywords: [String!], $providers: [ProviderEnum!]) {
    launchDiscovery(input: { keywords: $keywords, providers: $providers }) {
      message
      runId
    }
  }
`

export const RECOMPUTE_OFFER_SCORES_MUTATION = gql`
  mutation RecomputeOfferScores {
    recomputeOfferScores(input: {}) {
      message
      enqueuedCount
    }
  }
`
