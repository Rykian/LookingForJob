import { gql } from '@apollo/client'
import { useQuery } from '@apollo/client/react'
import { Link, useSearchParams } from 'react-router'
import { Badge } from '@/components/ui/badge'
import { Button } from '@/components/ui/button'
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card'
import {
  type JobOffersQuery,
  type JobOffersQueryVariables,
  LocationModeEnum,
} from '@/graphql/generated'
import { formatLocationMode } from '@/lib/location-mode'

const LOCATION_MODE_VALUES = Object.values(LocationModeEnum)
const SCORED_VALUES = ['any', 'true', 'false'] as const
const SORT_BY_VALUES = ['first_seen_at', 'last_seen_at', 'score', 'company', 'title'] as const
const SORT_DIRECTION_VALUES = ['asc', 'desc'] as const

type SortBy = (typeof SORT_BY_VALUES)[number]
type SortDirection = (typeof SORT_DIRECTION_VALUES)[number]

function isOneOf<T extends readonly string[]>(value: string, values: T): value is T[number] {
  return values.includes(value)
}

const JOB_OFFERS_QUERY = gql`
  query JobOffers(
    $page: Int!
    $perPage: Int!
    $source: String
    $locationMode: LocationModeEnum
    $scored: Boolean
    $sortBy: String
    $sortDirection: String
  ) {
    jobOffers(
      page: $page
      perPage: $perPage
      source: $source
      locationMode: $locationMode
      scored: $scored
      sortBy: $sortBy
      sortDirection: $sortDirection
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
  const [searchParams, setSearchParams] = useSearchParams()

  const pageParam = Number.parseInt(searchParams.get('page') ?? '1', 10)
  const page = Number.isFinite(pageParam) && pageParam > 0 ? pageParam : 1
  const source = searchParams.get('source') ?? ''

  const locationModeParam = searchParams.get('locationMode')
  const locationMode: LocationModeEnum | '' =
    locationModeParam && isOneOf(locationModeParam, LOCATION_MODE_VALUES) ? locationModeParam : ''

  const scoredParam = searchParams.get('scored')
  const scored = scoredParam && isOneOf(scoredParam, SCORED_VALUES) ? scoredParam : 'any'

  const sortByParam = searchParams.get('sortBy')
  const sortBy: SortBy = sortByParam && isOneOf(sortByParam, SORT_BY_VALUES) ? sortByParam : 'score'

  const sortDirectionParam = searchParams.get('sortDirection')
  const sortDirection: SortDirection =
    sortDirectionParam && isOneOf(sortDirectionParam, SORT_DIRECTION_VALUES)
      ? sortDirectionParam
      : 'desc'

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
    ...(source ? { source } : {}),
    ...(locationMode ? { locationMode } : {}),
    ...(scored === 'any' ? {} : { scored: scored === 'true' }),
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
          <div className="grid grid-cols-1 gap-3 md:grid-cols-4">
            <input
              className="h-10 rounded-md border bg-background px-3 text-sm"
              placeholder="Source (e.g. linkedin)"
              value={source}
              onChange={(event) => {
                updateSearchParams({
                  page: null,
                  source: event.target.value || null,
                })
              }}
            />

            <select
              className="h-10 rounded-md border bg-background px-3 text-sm"
              value={locationMode}
              onChange={(event) => {
                updateSearchParams({
                  page: null,
                  locationMode: event.target.value || null,
                })
              }}
            >
              <option value="">All location modes</option>
              <option value={LocationModeEnum.Remote}>Remote</option>
              <option value={LocationModeEnum.Hybrid}>Hybrid</option>
              <option value={LocationModeEnum.OnSite}>On-site</option>
            </select>

            <select
              className="h-10 rounded-md border bg-background px-3 text-sm"
              value={scored}
              onChange={(event) => {
                updateSearchParams({
                  page: null,
                  scored: event.target.value === 'any' ? null : event.target.value,
                })
              }}
            >
              <option value="any">Scoring: any</option>
              <option value="true">Scored only</option>
              <option value="false">Unscored only</option>
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
