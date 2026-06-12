import { useQuery } from '@apollo/client/react'
import { useSearchParams } from 'react-router'
import { Filters } from '@/features/companies/components/filters'
import { Table } from '@/features/companies/components/table'
import { type SortBy, useCompaniesFilters } from '@/features/companies/hooks/use-filters'
import { COMPANIES_QUERY } from '@/features/companies/queries/documents'
import { Pagination } from '@/features/offers/components/pagination'
import type { CompaniesQuery, CompaniesQueryVariables } from '@/graphql/generated'

export default function CompaniesPage() {
  const [searchParams, setSearchParams] = useSearchParams()
  const {
    page,
    variables,
    search,
    postsAsRecruiter,
    postsAsFinalClient,
    sortBy,
    sortDirection,
    updateSearchParams,
  } = useCompaniesFilters({ searchParams, setSearchParams })

  const { data, loading, error } = useQuery<CompaniesQuery, CompaniesQueryVariables>(
    COMPANIES_QUERY,
    { variables },
  )

  const toggleSort = (column: SortBy) => {
    if (sortBy === column) {
      updateSearchParams({
        page: null,
        sortDirection: sortDirection === 'asc' ? 'desc' : 'asc',
      })
      return
    }

    updateSearchParams({
      page: null,
      sortBy: column === 'name' ? null : column,
      sortDirection: null,
    })
  }

  const sortIndicator = (column: SortBy) => {
    if (sortBy !== column) return '↕'
    return sortDirection === 'asc' ? '↑' : '↓'
  }

  return (
    <div className="space-y-6 p-8">
      <div>
        <h1 className="text-2xl font-semibold">Companies</h1>
        <p className="mt-1 text-sm text-muted-foreground">
          Companies extracted from sourced offers: recruiters and final clients.
        </p>
      </div>

      <Filters
        search={search}
        postsAsRecruiter={postsAsRecruiter}
        postsAsFinalClient={postsAsFinalClient}
        onChangeSearch={(value) => updateSearchParams({ page: null, search: value || null })}
        onToggleRecruiter={() =>
          updateSearchParams({ page: null, recruiter: postsAsRecruiter ? null : 'true' })
        }
        onToggleFinalClient={() =>
          updateSearchParams({ page: null, finalClient: postsAsFinalClient ? null : 'true' })
        }
      />

      <div className="space-y-2">
        <Table
          loading={loading}
          error={Boolean(error)}
          totalCount={data?.companies.totalCount ?? 0}
          companies={data?.companies.nodes ?? []}
          onToggleSort={toggleSort}
          getSortIndicator={sortIndicator}
        />

        <Pagination
          page={page}
          totalPages={data?.companies.totalPages ?? 1}
          onPageChange={(p) => {
            updateSearchParams({ page: p <= 1 ? null : String(p) })
          }}
        />
      </div>
    </div>
  )
}
