import { useSearchParams } from 'react-router'
import { FiltersPanel } from '@/features/offers/components/filters-panel'
import { Pagination } from '@/features/offers/components/pagination'
import { Table } from '@/features/offers/components/table'
import { useJobOffersData } from '@/features/offers/hooks/use-data'
import { useJobOffersFilters } from '@/features/offers/hooks/use-filters'
import { useJobOffersSort } from '@/features/offers/hooks/use-sort'

export default function OffersPage() {
  const [searchParams, setSearchParams] = useSearchParams()
  const {
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
  } = useJobOffersFilters({
    searchParams,
    setSearchParams,
  })

  const { toggleSort, sortIndicator } = useJobOffersSort({
    sortBy,
    sortDirection,
    updateSearchParams,
  })

  const {
    providerKeys,
    providerLoading,
    technologyKeys,
    technologiesLoading,
    sourcingStatus,
    isSourcingActive,
    data,
    loading,
    error,
  } = useJobOffersData({ variables })

  const totalPages = data?.jobOffers.totalPages ?? 1
  const offers = data?.jobOffers.nodes ?? []
  const sourcingStatusText = sourcingStatus
    ? isSourcingActive
      ? `Sourcing running (queued: ${sourcingStatus.queuedCount}, running: ${sourcingStatus.runningCount})`
      : 'Sourcing idle'
    : null

  return (
    <div className="space-y-6 p-8">
      <div>
        <h1 className="text-2xl font-semibold">Offers</h1>
        <p className="mt-1 text-sm text-muted-foreground">Browse and filter sourced job offers.</p>
      </div>

      <FiltersPanel
        providerKeys={providerKeys}
        providerLoading={providerLoading}
        technologyKeys={technologyKeys}
        technologiesLoading={technologiesLoading}
        selectedTechnologies={selectedTechnologies}
        selectedSources={selectedSources}
        selectedLocationModes={selectedLocationModes}
        seenField={seenField}
        datePreset={datePreset}
        onChangeTechnologies={(items) => {
          updateSearchParams({
            page: null,
            technologies: items.length > 0 ? items.join(',') : null,
          })
        }}
        onChangeSources={(items) => {
          updateSearchParams({
            page: null,
            source: items.length > 0 ? items.join(',') : null,
          })
        }}
        onChangeLocationModes={(items) => {
          updateSearchParams({
            page: null,
            locationModes: items.length > 0 ? items.join(',') : null,
          })
        }}
        onChangeSeenField={(value) => {
          updateSearchParams({
            page: null,
            seenField: value,
          })
        }}
        onChangeDatePreset={(value) => {
          updateSearchParams({
            page: null,
            datePreset: value,
          })
        }}
        onReset={resetSearchParams}
      />

      <div className="space-y-2">
        <Table
          loading={loading}
          error={Boolean(error)}
          totalCount={data?.jobOffers.totalCount ?? 0}
          isSourcingActive={isSourcingActive}
          sourcingStatusText={sourcingStatusText}
          offers={offers}
          onToggleSort={toggleSort}
          getSortIndicator={sortIndicator}
        />

        <Pagination
          page={page}
          totalPages={totalPages}
          onPrevious={() => {
            const previousPage = page - 1
            updateSearchParams({ page: previousPage <= 1 ? null : String(previousPage) })
          }}
          onNext={() => {
            updateSearchParams({ page: String(page + 1) })
          }}
        />
      </div>
    </div>
  )
}
