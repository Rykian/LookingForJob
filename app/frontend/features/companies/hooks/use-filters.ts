import type { CompaniesQueryVariables } from '@/graphql/generated'

const SORT_BY_VALUES = ['name', 'created_at', 'offers_count'] as const
const SORT_DIRECTION_VALUES = ['asc', 'desc'] as const

export type SortBy = (typeof SORT_BY_VALUES)[number]
export type SortDirection = (typeof SORT_DIRECTION_VALUES)[number]

function isOneOf<T extends readonly string[]>(value: string, values: T): value is T[number] {
  return values.includes(value)
}

interface UseCompaniesFiltersParams {
  searchParams: URLSearchParams
  setSearchParams: (
    next: URLSearchParams,
    options?: { replace?: boolean; preventScrollReset?: boolean },
  ) => void
}

export function useCompaniesFilters({ searchParams, setSearchParams }: UseCompaniesFiltersParams) {
  const pageParam = Number.parseInt(searchParams.get('page') ?? '1', 10)
  const page = Number.isFinite(pageParam) && pageParam > 0 ? pageParam : 1

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

  const updateSearchParams = (updates: Record<string, string | null>) => {
    const next = new URLSearchParams(searchParams)

    Object.entries(updates).forEach(([key, value]) => {
      if (!value) {
        next.delete(key)
      } else {
        next.set(key, value)
      }
    })

    setSearchParams(next, { preventScrollReset: true })
  }

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
