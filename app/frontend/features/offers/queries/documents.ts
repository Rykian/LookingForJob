import { gql } from '@apollo/client'

export const TECHNOLOGIES_QUERY = gql`
  query Technologies {
    technologies
  }
`

export const PROVIDERS_QUERY = gql`
  query Providers {
    providers
  }
`

export const JOB_OFFERS_QUERY = gql`
  query JobOffers(
    $page: Int!
    $perPage: Int!
    $source: String
    $locationModes: [LocationModeEnum!]
    $firstSeenAfter: ISO8601DateTime
    $firstSeenBefore: ISO8601DateTime
    $lastSeenAfter: ISO8601DateTime
    $lastSeenBefore: ISO8601DateTime
    $sortBy: String
    $sortDirection: String
    $technologies: [String!]
  ) {
    jobOffers(
      page: $page
      perPage: $perPage
      source: $source
      locationModes: $locationModes
      firstSeenAfter: $firstSeenAfter
      firstSeenBefore: $firstSeenBefore
      lastSeenAfter: $lastSeenAfter
      lastSeenBefore: $lastSeenBefore
      sortBy: $sortBy
      sortDirection: $sortDirection
      technologies: $technologies
    ) {
      totalCount
      totalPages
      nodes {
        id
        title
        url
        company
        source
        city
        locationMode
        score
        firstSeenAt
      }
    }
  }
`

export const SOURCING_STATUS_SUBSCRIPTION = gql`
  subscription SourcingStatus {
    sourcingStatus {
      active
      queuedCount
      runningCount
      updatedAt
    }
  }
`

export const ACTIVE_SOURCING_POLL_INTERVAL_MS = 5000
