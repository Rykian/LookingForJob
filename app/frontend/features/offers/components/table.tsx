import { Link } from 'react-router'
import { Badge } from '@/components/ui/badge'
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card'
import type { SortableColumn } from '@/features/offers/hooks/use-sort'
import { formatLocationMode } from '@/features/offers/utils/location-mode'
import type { JobOffersQuery } from '@/graphql/generated'

interface TableProps {
  loading: boolean
  error?: boolean
  totalCount: number
  isSourcingActive: boolean
  sourcingStatusText?: string | null
  offers: JobOffersQuery['jobOffers']['nodes']
  onToggleSort: (column: SortableColumn) => void
  getSortIndicator: (column: SortableColumn) => string
}

export function Table({
  loading,
  error,
  totalCount,
  isSourcingActive,
  sourcingStatusText,
  offers,
  onToggleSort,
  getSortIndicator,
}: TableProps) {
  return (
    <Card>
      <CardHeader>
        <CardTitle className="text-base">
          {loading && !isSourcingActive ? 'Loading offers...' : `${totalCount} offers`}
        </CardTitle>
        {sourcingStatusText ? (
          <p className="text-sm text-muted-foreground">{sourcingStatusText}</p>
        ) : null}
      </CardHeader>
      <CardContent>
        {error ? <p className="text-destructive">Failed to load offers.</p> : null}

        {!loading && !error && offers.length === 0 ? (
          <p className="text-sm text-muted-foreground">No offers found with current filters.</p>
        ) : null}

        <div className="overflow-x-auto">
          <table className="w-full min-w-[860px] text-left text-sm">
            <thead>
              <tr className="border-b text-muted-foreground">
                <th className="px-3 py-2 font-medium">
                  <button
                    className="inline-flex items-center gap-1 hover:text-foreground"
                    onClick={() => onToggleSort('title')}
                    type="button"
                  >
                    Title <span>{getSortIndicator('title')}</span>
                  </button>
                </th>
                <th className="px-3 py-2 font-medium">
                  <button
                    className="inline-flex items-center gap-1 hover:text-foreground"
                    onClick={() => onToggleSort('company')}
                    type="button"
                  >
                    Company <span>{getSortIndicator('company')}</span>
                  </button>
                </th>
                <th className="px-3 py-2 font-medium">Source</th>
                <th className="px-3 py-2 font-medium">Location</th>
                <th className="px-3 py-2 font-medium">Mode</th>
                <th className="px-3 py-2 font-medium">
                  <button
                    className="inline-flex items-center gap-1 hover:text-foreground"
                    onClick={() => onToggleSort('score')}
                    type="button"
                  >
                    Score <span>{getSortIndicator('score')}</span>
                  </button>
                </th>
                <th className="px-3 py-2 font-medium">
                  <button
                    className="inline-flex items-center gap-1 hover:text-foreground"
                    onClick={() => onToggleSort('first_seen_at')}
                    type="button"
                  >
                    Seen <span>{getSortIndicator('first_seen_at')}</span>
                  </button>
                </th>
              </tr>
            </thead>
            <tbody>
              {offers.map((offer) => (
                <tr key={offer.id} className="border-b last:border-0">
                  <td className="px-3 py-2 font-medium">
                    <div className="space-y-1">
                      <Link
                        className="text-primary visited:text-muted-foreground hover:underline"
                        to={`/offers/${offer.id}`}
                      >
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
                  <td className="px-3 py-2">{new Date(offer.firstSeenAt).toLocaleDateString()}</td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </CardContent>
    </Card>
  )
}
