import { Link } from 'react-router'
import { Badge } from '@/components/ui/badge'
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card'
import { TechIcon } from '@/features/offers/utils/tech-icons'
import type { CompaniesQuery } from '@/graphql/generated'
import type { SortBy } from '../hooks/use-filters'

interface TableProps {
  loading: boolean
  error?: boolean
  totalCount: number
  companies: CompaniesQuery['companies']['nodes']
  onToggleSort: (column: SortBy) => void
  getSortIndicator: (column: SortBy) => string
}

export function Table({
  loading,
  error,
  totalCount,
  companies,
  onToggleSort,
  getSortIndicator,
}: TableProps) {
  return (
    <Card>
      <CardHeader>
        <CardTitle className="text-base">
          {loading ? 'Loading companies...' : `${totalCount} companies`}
        </CardTitle>
      </CardHeader>
      <CardContent>
        {error ? <p className="text-destructive">Failed to load companies.</p> : null}

        {!loading && !error && companies.length === 0 ? (
          <p className="text-sm text-muted-foreground">No companies found with current filters.</p>
        ) : null}

        <div className="overflow-x-auto">
          <table className="w-full min-w-160 text-left text-sm">
            <thead>
              <tr className="border-b text-muted-foreground">
                <th className="px-3 py-2 font-medium">
                  <button
                    className="inline-flex items-center gap-1 hover:text-foreground"
                    onClick={() => onToggleSort('name')}
                    type="button"
                  >
                    Name <span>{getSortIndicator('name')}</span>
                  </button>
                </th>
                <th className="px-3 py-2 font-medium">Tags</th>
                <th className="px-3 py-2 font-medium">
                  <button
                    className="inline-flex items-center gap-1 hover:text-foreground"
                    onClick={() => onToggleSort('offers_count')}
                    type="button"
                  >
                    Offers <span>{getSortIndicator('offers_count')}</span>
                  </button>
                </th>
                <th className="px-3 py-2 font-medium">Technologies</th>
              </tr>
            </thead>
            <tbody>
              {companies.map((company) => (
                <tr key={company.id} className="border-b last:border-0">
                  <td className="px-3 py-2 font-medium">
                    <Link
                      className="text-primary visited:text-muted-foreground hover:underline"
                      to={`/companies/${company.id}`}
                    >
                      {company.name}
                    </Link>
                  </td>
                  <td className="px-3 py-2">
                    <div className="flex flex-wrap gap-1.5">
                      {company.postsAsRecruiter ? <Badge variant="outline">Recruiter</Badge> : null}
                      {company.postsAsFinalClient ? (
                        <Badge variant="secondary">Final client</Badge>
                      ) : null}
                    </div>
                  </td>
                  <td className="px-3 py-2">
                    {company.offerCount}
                    {company.finalClientOfferCount > 0 ? (
                      <span className="text-muted-foreground">
                        {' '}
                        (+{company.finalClientOfferCount} as client)
                      </span>
                    ) : null}
                  </td>
                  <td className="px-3 py-2">
                    <div className="flex gap-1.5 flex-wrap">
                      {company.topTechnologies.map((tech) => (
                        <TechIcon key={tech} name={tech} />
                      ))}
                    </div>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </CardContent>
    </Card>
  )
}
