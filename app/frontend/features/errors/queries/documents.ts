import { gql } from '@apollo/client'

export const PIPELINE_ERRORS_QUERY = gql`
  query PipelineErrors(
    $page: Int!
    $perPage: Int!
    $resolved: Boolean
    $steps: [String!]
    $sources: [String!]
    $errorClass: String
    $runId: ID
    $jobOfferId: ID
    $createdAfter: ISO8601DateTime
    $createdBefore: ISO8601DateTime
  ) {
    pipelineErrors(
      page: $page
      perPage: $perPage
      resolved: $resolved
      steps: $steps
      sources: $sources
      errorClass: $errorClass
      runId: $runId
      jobOfferId: $jobOfferId
      createdAfter: $createdAfter
      createdBefore: $createdBefore
    ) {
      totalCount
      totalPages
      nodes {
        id
        jobOfferId
        runId
        step
        source
        stepVersion
        errorClass
        errorMessage
        arguments
        resolved
        createdAt
      }
    }
  }
`

export const PIPELINE_ERROR_FACETS_QUERY = gql`
  query PipelineErrorFacets {
    pipelineErrorClasses
    pipelineErrorSources
  }
`
