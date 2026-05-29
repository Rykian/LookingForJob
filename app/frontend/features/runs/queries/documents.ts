import { gql } from '@apollo/client'

export const RUNS_QUERY = gql`
  query Runs {
    runs {
      id
      keywords
      providers
      workModes
      newOffersCount
      updatedOffersCount
      errorCount
      createdAt
    }
  }
`
