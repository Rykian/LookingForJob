import type { PipelineErrorsQueryVariables } from '@/graphql/generated'

const STEP_VALUES = ['discovery', 'fetch', 'analyze', 'enrich', 'commute', 'score'] as const
const RESOLVED_VALUES = ['all', 'unresolved', 'resolved'] as const

export type Step = (typeof STEP_VALUES)[number]
export type ResolvedFilter = (typeof RESOLVED_VALUES)[number]

function isOneOf<T extends readonly string[]>(value: string, values: T): value is T[number] {
  return values.includes(value)
}

interface UsePipelineErrorsFiltersParams {
  searchParams: URLSearchParams
  setSearchParams: (next: URLSearchParams) => void
}

export function usePipelineErrorsFilters({
  searchParams,
  setSearchParams,
}: UsePipelineErrorsFiltersParams) {
  const pageParam = Number.parseInt(searchParams.get('page') ?? '1', 10)
  const page = Number.isFinite(pageParam) && pageParam > 0 ? pageParam : 1

  const resolvedParam = searchParams.get('resolved')
  const resolved: ResolvedFilter =
    resolvedParam && isOneOf(resolvedParam, RESOLVED_VALUES) ? resolvedParam : 'unresolved'

  const stepsParam = searchParams.get('steps') || ''
  const selectedSteps = stepsParam
    ? stepsParam.split(',').filter((value): value is Step => isOneOf(value, STEP_VALUES))
    : []

  const sourcesParam = searchParams.get('sources') || ''
  const selectedSources = sourcesParam ? sourcesParam.split(',').filter(Boolean) : []

  const errorClass = searchParams.get('errorClass') || ''

  const runId = searchParams.get('runId') || null
  const jobOfferId = searchParams.get('jobOfferId') || null

  const updateSearchParams = (updates: Record<string, string | null>) => {
    const next = new URLSearchParams(searchParams)

    for (const [key, value] of Object.entries(updates)) {
      if (!value) {
        next.delete(key)
      } else {
        next.set(key, value)
      }
    }

    setSearchParams(next)
  }

  const resetSearchParams = () => {
    setSearchParams(new URLSearchParams())
  }

  const resolvedVariable = resolved === 'all' ? undefined : resolved === 'resolved'

  const variables: PipelineErrorsQueryVariables = {
    page,
    perPage: 25,
    ...(resolvedVariable === undefined ? {} : { resolved: resolvedVariable }),
    ...(selectedSteps.length > 0 ? { steps: selectedSteps } : {}),
    ...(selectedSources.length > 0 ? { sources: selectedSources } : {}),
    ...(errorClass ? { errorClass } : {}),
    ...(runId ? { runId } : {}),
    ...(jobOfferId ? { jobOfferId } : {}),
  }

  return {
    page,
    variables,
    resolved,
    selectedSteps,
    selectedSources,
    errorClass,
    runId,
    jobOfferId,
    updateSearchParams,
    resetSearchParams,
  }
}

export const stepValues = STEP_VALUES
export const resolvedValues = RESOLVED_VALUES
