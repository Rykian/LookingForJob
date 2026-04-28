import { gql } from '@apollo/client'

export const LAUNCH_DISCOVERY_MUTATION = gql`
  mutation LaunchDiscovery {
    launchDiscovery(input: {}) {
      message
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
