import type { CompaniesQueryVariables } from '@/graphql/generated'
import { isOneOf, parsePage, useUrlParams } from '@/lib/url-params'

const SORT_BY_VALUES = ['name', 'created_at', 'offers_count'] as const
const SORT_DIRECTION_VALUES = ['asc', 'desc'] as const

export type SortBy = (typeof SORT_BY_VALUES)[number]
export type SortDirection = (typeof SORT_DIRECTION_VALUES)[number]

interface UseCompaniesFiltersParams {
  searchParams: URLSearchParams
  setSearchParams: (
    next: URLSearchParams,
    options?: { replace?: boolean; preventScrollReset?: boolean },
  ) => void
}

export function useCompaniesFilters({ searchParams, setSearchParams }: UseCompaniesFiltersParams) {
  const { update: updateSearchParams } = useUrlParams(searchParams, setSearchParams)

  const page = parsePage(searchParams)
  const search = searchParams.get('search') ?? ''
  const postsAsRecruiter = searchParams.get('recruiter') === 'true'
  const postsAsFinalClient = searchParams.get('finalClient') === 'true'

  const sortByParam = searchParams.get('sortBy')
  const sortBy: SortBy = sortByParam && isOneOf(sortByParam, SORT_BY_VALUES) ? sortByParam : 'name'

  const sortDirectionParam = searchParams.get('sortDirection')
  const sortDirection: SortDirection =
    sortDirectionParam && isOneOf(sortDirectionParam, SORT_DIRECTION_VALUES)
      ? sortDirectionParam
      : 'asc'

  const variables: CompaniesQueryVariables = {
    page,
    perPage: 25,
    sortBy,
    sortDirection,
    ...(search ? { search } : {}),
    ...(postsAsRecruiter ? { postsAsRecruiter: true } : {}),
    ...(postsAsFinalClient ? { postsAsFinalClient: true } : {}),
  }

  return {
    page,
    variables,
    search,
    postsAsRecruiter,
    postsAsFinalClient,
    sortBy,
    sortDirection,
    updateSearchParams,
  }
}
