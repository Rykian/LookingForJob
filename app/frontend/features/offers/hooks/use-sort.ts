import type { SortBy, SortDirection } from './use-filters'

const DEFAULT_SORT_COLUMN: SortBy = 'score'

export type SortableColumn = 'first_seen_at' | 'score' | 'company' | 'title'

interface UseJobOffersSortParams {
  sortBy: SortBy
  sortDirection: SortDirection
  updateSearchParams: (updates: Record<string, string | null>) => void
}

export function useJobOffersSort({
  sortBy,
  sortDirection,
  updateSearchParams,
}: UseJobOffersSortParams) {
  const toggleSort = (column: SortableColumn) => {
    if (sortBy === column) {
      updateSearchParams({
        page: null,
        sortDirection: sortDirection === 'asc' ? 'desc' : 'asc',
      })
      return
    }

    updateSearchParams({
      page: null,
      sortBy: column === DEFAULT_SORT_COLUMN ? null : column,
      sortDirection: null,
    })
  }

  const sortIndicator = (column: SortableColumn) => {
    if (sortBy !== column) return '↕'
    return sortDirection === 'asc' ? '↑' : '↓'
  }

  return {
    toggleSort,
    sortIndicator,
  }
}
