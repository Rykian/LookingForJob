import { useQuery } from '@apollo/client/react'
import type {
  PipelineErrorFacetsQuery,
  PipelineErrorsQuery,
  PipelineErrorsQueryVariables,
} from '@/graphql/generated'
import { PIPELINE_ERROR_FACETS_QUERY, PIPELINE_ERRORS_QUERY } from '../queries/documents'

interface UsePipelineErrorsDataParams {
  variables: PipelineErrorsQueryVariables
}

export function usePipelineErrorsData({ variables }: UsePipelineErrorsDataParams) {
  const { data: facetsData, loading: facetsLoading } = useQuery<PipelineErrorFacetsQuery>(
    PIPELINE_ERROR_FACETS_QUERY,
  )
  const errorClasses = facetsData?.pipelineErrorClasses || []
  const sources = facetsData?.pipelineErrorSources || []

  const { data, loading, error } = useQuery<PipelineErrorsQuery, PipelineErrorsQueryVariables>(
    PIPELINE_ERRORS_QUERY,
    { variables },
  )

  return {
    errorClasses,
    sources,
    facetsLoading,
    data,
    loading,
    error,
  }
}
