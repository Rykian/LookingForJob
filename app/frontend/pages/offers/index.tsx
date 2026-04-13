import { gql } from '@apollo/client'
import { useQuery } from '@apollo/client/react'
import { useMemo } from 'react'
import { Link, useSearchParams } from 'react-router'
import { Badge } from '@/components/ui/badge'
import { Button } from '@/components/ui/button'
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card'
import {
  Combobox,
  ComboboxChip,
  ComboboxChips,
  ComboboxChipsInput,
  ComboboxContent,
  ComboboxEmpty,
  ComboboxItem,
  ComboboxList,
  ComboboxValue,
} from '@/components/ui/combobox'

// Static list from scoring_profile.json (primary + secondary)
const TECHNOLOGIES = [
  'ruby',
  'react',
  'nodejs',
  'postgresql',
  'sidekiq',
  'typescript',
  'docker',
  'elm',
  'javascript',
  'redis',
  'node',
  'express',
  'graphql',
  'rails',
  'ruby on rails',
]

const PROVIDERS = gql`
  query Providers {
    providers
  }
`

import {
  type JobOffersQuery,
  type JobOffersQueryVariables,
  LocationModeEnum,
  type ProvidersQuery,
} from '@/graphql/generated'
import { formatLocationMode } from '@/lib/location-mode'

const LOCATION_MODE_VALUES = Object.values(LocationModeEnum)
const SEEN_FIELD_VALUES = ['first_seen_at', 'last_seen_at'] as const
const DATE_PRESET_VALUES = ['today', 'yesterday', 'last_7_days', 'last_30_days'] as const
const SORT_BY_VALUES = ['first_seen_at', 'last_seen_at', 'score', 'company', 'title'] as const
const SORT_DIRECTION_VALUES = ['asc', 'desc'] as const

type SeenField = (typeof SEEN_FIELD_VALUES)[number]
type DatePreset = (typeof DATE_PRESET_VALUES)[number]
type SortBy = (typeof SORT_BY_VALUES)[number]
type SortDirection = (typeof SORT_DIRECTION_VALUES)[number]

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

const JOB_OFFERS_QUERY = gql`
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

export default function OffersPage() {
  // Fetch provider keys (sources) from backend
  const { data: providerData, loading: providerLoading } = useQuery<ProvidersQuery>(PROVIDERS)
  const providerKeys = providerData?.providers || []
  const [searchParams, setSearchParams] = useSearchParams()
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

  const toggleSort = (column: 'first_seen_at' | 'score' | 'company' | 'title') => {
    if (sortBy === column) {
      updateSearchParams({
        page: null,
        sortDirection: sortDirection === 'asc' ? 'desc' : 'asc',
      })
      return
    }

    updateSearchParams({
      page: null,
      sortBy: column === 'score' ? null : column,
      sortDirection: null,
    })
  }

  const sortIndicator = (column: 'first_seen_at' | 'score' | 'company' | 'title') => {
    if (sortBy !== column) return '↕'
    return sortDirection === 'asc' ? '↑' : '↓'
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

  const { data, loading, error } = useQuery<JobOffersQuery, JobOffersQueryVariables>(
    JOB_OFFERS_QUERY,
    {
      variables,
    },
  )

  const totalPages = data?.jobOffers.totalPages ?? 1

  return (
    <div className="space-y-6 p-8">
      <div>
        <h1 className="text-2xl font-semibold">Offers</h1>
        <p className="mt-1 text-sm text-muted-foreground">Browse and filter sourced job offers.</p>
      </div>

      <Card>
        <CardHeader>
          <CardTitle className="text-base">Filters</CardTitle>
        </CardHeader>
        <CardContent>
          <div className="grid grid-cols-1 gap-3 md:grid-cols-6">
            <Combobox
              multiple
              items={TECHNOLOGIES}
              onValueChange={(techs: string[]) => {
                const val = techs.length > 0 ? techs.join(',') : null
                updateSearchParams({ page: null, technologies: val })
              }}
            >
              <ComboboxChips>
                <ComboboxValue>
                  {selectedTechnologies.map((item) => (
                    <ComboboxChip key={item}>{item}</ComboboxChip>
                  ))}
                </ComboboxValue>
                <ComboboxChipsInput placeholder="Filter by technology..." />
              </ComboboxChips>

              <ComboboxContent>
                <ComboboxEmpty>All technologies</ComboboxEmpty>
                <ComboboxList>
                  {(item) => (
                    <ComboboxItem key={item} value={item}>
                      {item}
                    </ComboboxItem>
                  )}
                </ComboboxList>
              </ComboboxContent>
            </Combobox>

            <Combobox
              multiple
              items={providerKeys}
              onValueChange={(sources: string[]) => {
                const val = sources.length > 0 ? sources.join(',') : null
                updateSearchParams({ page: null, source: val })
              }}
              disabled={providerLoading}
            >
              <ComboboxChips>
                <ComboboxValue>
                  {selectedSources.map((item) => (
                    <ComboboxChip key={item}>{item}</ComboboxChip>
                  ))}
                </ComboboxValue>
                <ComboboxChipsInput placeholder="Filter by source..." />
              </ComboboxChips>

              <ComboboxContent>
                <ComboboxEmpty>All sources</ComboboxEmpty>
                <ComboboxList>
                  {(item) => (
                    <ComboboxItem key={item} value={item}>
                      {item}
                    </ComboboxItem>
                  )}
                </ComboboxList>
              </ComboboxContent>
            </Combobox>

            <Combobox
              multiple
              items={LOCATION_MODE_VALUES}
              onValueChange={(locationModes: string[]) => {
                const val = locationModes.length > 0 ? locationModes.join(',') : null
                updateSearchParams({ page: null, locationModes: val })
              }}
            >
              <ComboboxChips>
                <ComboboxValue>
                  {selectedLocationModes.map((item) => (
                    <ComboboxChip key={item}>{formatLocationMode(item)}</ComboboxChip>
                  ))}
                </ComboboxValue>
                <ComboboxChipsInput placeholder="Filter by location mode..." />
              </ComboboxChips>

              <ComboboxContent>
                <ComboboxEmpty>All location modes</ComboboxEmpty>
                <ComboboxList>
                  {(item) => (
                    <ComboboxItem key={item} value={item}>
                      {formatLocationMode(item)}
                    </ComboboxItem>
                  )}
                </ComboboxList>
              </ComboboxContent>
            </Combobox>

            <select
              className="h-10 rounded-md border bg-background px-3 text-sm"
              value={seenField}
              onChange={(event) => {
                updateSearchParams({
                  page: null,
                  seenField: event.target.value,
                })
              }}
            >
              <option value="first_seen_at">Seen field: first seen</option>
              <option value="last_seen_at">Seen field: last seen</option>
            </select>

            <select
              className="h-10 rounded-md border bg-background px-3 text-sm"
              value={datePreset}
              onChange={(event) => {
                updateSearchParams({
                  page: null,
                  datePreset: event.target.value,
                })
              }}
            >
              <option value="today">Date: today</option>
              <option value="yesterday">Date: yesterday</option>
              <option value="last_7_days">Date: last 7 days</option>
              <option value="last_30_days">Date: last 30 days</option>
            </select>

            <Button
              variant="outline"
              onClick={() => {
                setSearchParams(new URLSearchParams())
              }}
            >
              Reset
            </Button>
          </div>
        </CardContent>
      </Card>

      <Card>
        <CardHeader>
          <CardTitle className="text-base">
            {loading ? 'Loading offers...' : `${data?.jobOffers.totalCount ?? 0} offers`}
          </CardTitle>
        </CardHeader>
        <CardContent>
          {error ? <p className="text-destructive">Failed to load offers.</p> : null}

          {!loading && !error && (data?.jobOffers.nodes.length ?? 0) === 0 ? (
            <p className="text-sm text-muted-foreground">No offers found with current filters.</p>
          ) : null}

          <div className="overflow-x-auto">
            <table className="w-full min-w-[860px] text-left text-sm">
              <thead>
                <tr className="border-b text-muted-foreground">
                  <th className="px-3 py-2 font-medium">
                    <button
                      className="inline-flex items-center gap-1 hover:text-foreground"
                      onClick={() => toggleSort('title')}
                      type="button"
                    >
                      Title <span>{sortIndicator('title')}</span>
                    </button>
                  </th>
                  <th className="px-3 py-2 font-medium">
                    <button
                      className="inline-flex items-center gap-1 hover:text-foreground"
                      onClick={() => toggleSort('company')}
                      type="button"
                    >
                      Company <span>{sortIndicator('company')}</span>
                    </button>
                  </th>
                  <th className="px-3 py-2 font-medium">Source</th>
                  <th className="px-3 py-2 font-medium">Location</th>
                  <th className="px-3 py-2 font-medium">Mode</th>
                  <th className="px-3 py-2 font-medium">
                    <button
                      className="inline-flex items-center gap-1 hover:text-foreground"
                      onClick={() => toggleSort('score')}
                      type="button"
                    >
                      Score <span>{sortIndicator('score')}</span>
                    </button>
                  </th>
                  <th className="px-3 py-2 font-medium">
                    <button
                      className="inline-flex items-center gap-1 hover:text-foreground"
                      onClick={() => toggleSort('first_seen_at')}
                      type="button"
                    >
                      Seen <span>{sortIndicator('first_seen_at')}</span>
                    </button>
                  </th>
                </tr>
              </thead>
              <tbody>
                {(data?.jobOffers.nodes ?? []).map((offer) => (
                  <tr key={offer.id} className="border-b last:border-0">
                    <td className="px-3 py-2 font-medium">
                      <div className="space-y-1">
                        <Link className="hover:underline" to={`/offers/${offer.id}`}>
                          {offer.title || 'Untitled role'}
                        </Link>
                      </div>
                    </td>
                    <td className="px-3 py-2">{offer.company || '-'}</td>
                    <td className="px-3 py-2">{offer.source}</td>
                    <td className="px-3 py-2">{offer.city || '-'}</td>
                    <td className="px-3 py-2">
                      <Badge variant="outline">{formatLocationMode(offer.locationMode)}</Badge>
                    </td>
                    <td className="px-3 py-2">{offer.score ?? '-'}</td>
                    <td className="px-3 py-2">
                      {new Date(offer.firstSeenAt).toLocaleDateString()}
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>

          <div className="mt-4 flex items-center justify-between">
            <span className="text-sm text-muted-foreground">
              Page {page} of {Math.max(totalPages, 1)}
            </span>
            <div className="flex gap-2">
              <Button
                variant="outline"
                size="sm"
                disabled={page <= 1}
                onClick={() => {
                  const previousPage = page - 1
                  updateSearchParams({ page: previousPage <= 1 ? null : String(previousPage) })
                }}
              >
                Previous
              </Button>
              <Button
                variant="outline"
                size="sm"
                disabled={page >= totalPages}
                onClick={() => {
                  updateSearchParams({ page: String(page + 1) })
                }}
              >
                Next
              </Button>
            </div>
          </div>
        </CardContent>
      </Card>
    </div>
  )
}
