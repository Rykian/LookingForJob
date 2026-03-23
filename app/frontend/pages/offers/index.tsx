import { gql } from '@apollo/client'
import { useQuery } from '@apollo/client/react'
import { useState } from 'react'
import { Link } from 'react-router'
import { Badge } from '@/components/ui/badge'
import { Button } from '@/components/ui/button'
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card'
import type { JobOffersQuery, JobOffersQueryVariables } from '@/graphql/generated'

const JOB_OFFERS_QUERY = gql`
  query JobOffers(
    $page: Int!
    $perPage: Int!
    $source: String
    $remote: String
    $scored: Boolean
    $sortBy: String
    $sortDirection: String
  ) {
    jobOffers(
      page: $page
      perPage: $perPage
      source: $source
      remote: $remote
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
        remote
        score
        firstSeenAt
      }
    }
  }
`

export default function OffersPage() {
  const [page, setPage] = useState(1)
  const [source, setSource] = useState('')
  const [remote, setRemote] = useState('')
  const [scored, setScored] = useState<'any' | 'true' | 'false'>('any')
  const [sortBy, setSortBy] = useState<
    'first_seen_at' | 'last_seen_at' | 'score' | 'company' | 'title'
  >('score')
  const [sortDirection, setSortDirection] = useState<'asc' | 'desc'>('desc')

  const toggleSort = (column: 'first_seen_at' | 'score' | 'company' | 'title') => {
    setPage(1)
    if (sortBy === column) {
      setSortDirection((prev) => (prev === 'asc' ? 'desc' : 'asc'))
      return
    }

    setSortBy(column)
    setSortDirection('desc')
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
    ...(remote ? { remote } : {}),
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
                setPage(1)
                setSource(event.target.value)
              }}
            />

            <select
              className="h-10 rounded-md border bg-background px-3 text-sm"
              value={remote}
              onChange={(event) => {
                setPage(1)
                setRemote(event.target.value)
              }}
            >
              <option value="">All remote modes</option>
              <option value="yes">Remote</option>
              <option value="hybrid">Hybrid</option>
              <option value="no">On-site</option>
            </select>

            <select
              className="h-10 rounded-md border bg-background px-3 text-sm"
              value={scored}
              onChange={(event) => {
                setPage(1)
                setScored(event.target.value as 'any' | 'true' | 'false')
              }}
            >
              <option value="any">Scoring: any</option>
              <option value="true">Scored only</option>
              <option value="false">Unscored only</option>
            </select>

            <Button
              variant="outline"
              onClick={() => {
                setPage(1)
                setSource('')
                setRemote('')
                setScored('any')
                setSortBy('score')
                setSortDirection('desc')
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
                      <Badge variant="outline">{offer.remote || 'unknown'}</Badge>
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
                onClick={() => setPage((p) => p - 1)}
              >
                Previous
              </Button>
              <Button
                variant="outline"
                size="sm"
                disabled={page >= totalPages}
                onClick={() => setPage((p) => p + 1)}
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
