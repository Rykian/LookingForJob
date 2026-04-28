import { gql } from '@apollo/client'

export const SCORING_PROFILE_QUERY = gql`
  query ScoringProfile {
    scoringProfile
  }
`

export const UPDATE_SCORING_PROFILE_MUTATION = gql`
  mutation UpdateScoringProfile($profile: JSON!) {
    updateScoringProfile(input: { profile: $profile }) {
      profile
    }
  }
`
