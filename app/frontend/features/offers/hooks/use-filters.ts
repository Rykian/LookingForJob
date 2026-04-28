import { useMemo } from 'react'
import { type JobOffersQueryVariables, LocationModeEnum } from '@/graphql/generated'

const LOCATION_MODE_VALUES = Object.values(LocationModeEnum)
const SEEN_FIELD_VALUES = ['first_seen_at', 'last_seen_at'] as const
const DATE_PRESET_VALUES = ['today', 'yesterday', 'last_7_days', 'last_30_days'] as const
const SORT_BY_VALUES = ['first_seen_at', 'last_seen_at', 'score', 'company', 'title'] as const
const SORT_DIRECTION_VALUES = ['asc', 'desc'] as const

export type SeenField = (typeof SEEN_FIELD_VALUES)[number]
export type DatePreset = (typeof DATE_PRESET_VALUES)[number]
export type SortBy = (typeof SORT_BY_VALUES)[number]
export type SortDirection = (typeof SORT_DIRECTION_VALUES)[number]

function isOneOf<T extends readonly string[]>(value: string, values: T): value is T[number] {
  return values.includes(value)
}

function getPresetRange(preset: DatePreset): { after: string; before: string } {
  const now = new Date()
  const startOfToday = new Date(now.getFullYear(), now.getMonth(), now.getDate())

  switch (preset) {
    case 'today': {
      return {
        after: startOfToday.toISOString(),
        before: now.toISOString(),
      }
    }
    case 'yesterday': {
      const start = new Date(startOfToday)
      start.setDate(start.getDate() - 1)
      const end = new Date(startOfToday)
      end.setMilliseconds(end.getMilliseconds() - 1)
      return {
        after: start.toISOString(),
        before: end.toISOString(),
      }
    }
    case 'last_7_days': {
      const start = new Date(startOfToday)
      start.setDate(start.getDate() - 6)
      return {
        after: start.toISOString(),
        before: now.toISOString(),
      }
    }
    case 'last_30_days': {
      const start = new Date(startOfToday)
      start.setDate(start.getDate() - 29)
      return {
        after: start.toISOString(),
        before: now.toISOString(),
      }
    }
  }
}

interface UseJobOffersFiltersParams {
  searchParams: URLSearchParams
  setSearchParams: (next: URLSearchParams) => void
}

export function useJobOffersFilters({ searchParams, setSearchParams }: UseJobOffersFiltersParams) {
  const techParam = searchParams.get('technologies') || ''
  const selectedTechnologies = techParam ? techParam.split(',').filter(Boolean) : []

  const pageParam = Number.parseInt(searchParams.get('page') ?? '1', 10)
  const page = Number.isFinite(pageParam) && pageParam > 0 ? pageParam : 1

  const sourceParam = searchParams.get('source') || ''
  const selectedSources = sourceParam ? sourceParam.split(',').filter(Boolean) : []

  const locationModesParam = searchParams.get('locationModes') || ''
  const selectedLocationModes = locationModesParam
    ? locationModesParam
        .split(',')
        .filter((value): value is LocationModeEnum => isOneOf(value, LOCATION_MODE_VALUES))
    : []

  const seenFieldParam = searchParams.get('seenField')
  const seenField: SeenField =
    seenFieldParam && isOneOf(seenFieldParam, SEEN_FIELD_VALUES) ? seenFieldParam : 'first_seen_at'

  const datePresetParam = searchParams.get('datePreset')
  const datePreset: DatePreset =
    datePresetParam && isOneOf(datePresetParam, DATE_PRESET_VALUES) ? datePresetParam : 'today'

  const sortByParam = searchParams.get('sortBy')
  const sortBy: SortBy = sortByParam && isOneOf(sortByParam, SORT_BY_VALUES) ? sortByParam : 'score'

  const sortDirectionParam = searchParams.get('sortDirection')
  const sortDirection: SortDirection =
    sortDirectionParam && isOneOf(sortDirectionParam, SORT_DIRECTION_VALUES)
      ? sortDirectionParam
      : 'desc'

  const seenDateVariables = useMemo<
    Pick<
      JobOffersQueryVariables,
      'firstSeenAfter' | 'firstSeenBefore' | 'lastSeenAfter' | 'lastSeenBefore'
    >
  >(() => {
    const { after: seenAfter, before: seenBefore } = getPresetRange(datePreset)

    if (seenField === 'first_seen_at') {
      return {
        firstSeenAfter: seenAfter,
        firstSeenBefore: seenBefore,
      }
    }

    return {
      lastSeenAfter: seenAfter,
      lastSeenBefore: seenBefore,
    }
  }, [datePreset, seenField])

  const updateSearchParams = (updates: Record<string, string | null>) => {
    const next = new URLSearchParams(searchParams)

    Object.entries(updates).forEach(([key, value]) => {
      if (!value) {
        next.delete(key)
      } else {
        next.set(key, value)
      }
    })

    setSearchParams(next)
  }

  const resetSearchParams = () => {
    setSearchParams(new URLSearchParams())
  }

  const variables: JobOffersQueryVariables = {
    page,
    perPage: 25,
    sortBy,
    sortDirection,
    ...(selectedSources.length > 0 ? { source: selectedSources.join(',') } : {}),
    ...(selectedLocationModes.length > 0 ? { locationModes: selectedLocationModes } : {}),
    ...seenDateVariables,
    ...(selectedTechnologies.length > 0 ? { technologies: selectedTechnologies } : {}),
  }

  return {
    page,
    variables,
    selectedTechnologies,
    selectedSources,
    selectedLocationModes,
    seenField,
    datePreset,
    sortBy,
    sortDirection,
    updateSearchParams,
    resetSearchParams,
  }
}

export const locationModeValues = LOCATION_MODE_VALUES
