import { X } from 'lucide-react'
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
    runId,
    newOnly,
    selectedTechnologies,
    selectedSources,
    selectedLocationModes,
    filterLanguage,
    maxLanguageLevel,
    seenField,
    datePreset,
    sortBy,
    sortDirection,
    onlyWithinCommute,
    minCommuteMinutes,
    maxCommuteMinutes,
    search,
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
    languageCodes,
    sourcingStatus,
    isSourcingActive,
    commuteMaxMinutes,
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

      {runId && (
        <div className="flex items-center gap-2 rounded-md border border-border bg-muted/40 px-3 py-2 text-sm">
          <span className="text-muted-foreground">Filtered by run</span>
          <span className="font-medium">#{runId}</span>
          <label className="ml-4 flex cursor-pointer items-center gap-1.5">
            <input
              type="checkbox"
              checked={newOnly}
              onChange={(e) =>
                updateSearchParams({ page: null, newOnly: e.target.checked ? null : 'false' })
              }
            />
            New only
          </label>
          <button
            type="button"
            className="ml-auto rounded p-0.5 hover:bg-muted"
            onClick={() => updateSearchParams({ runId: null, newOnly: null })}
            aria-label="Clear run filter"
          >
            <X className="h-3.5 w-3.5 text-muted-foreground" />
          </button>
        </div>
      )}

      <FiltersPanel
        providerKeys={providerKeys}
        providerLoading={providerLoading}
        technologyKeys={technologyKeys}
        technologiesLoading={technologiesLoading}
        selectedTechnologies={selectedTechnologies}
        selectedSources={selectedSources}
        selectedLocationModes={selectedLocationModes}
        languageCodes={languageCodes}
        filterLanguage={filterLanguage}
        maxLanguageLevel={maxLanguageLevel}
        seenField={seenField}
        datePreset={datePreset}
        onlyWithinCommute={onlyWithinCommute}
        minCommuteMinutes={minCommuteMinutes}
        maxCommuteMinutes={maxCommuteMinutes}
        commuteMaxMinutes={commuteMaxMinutes}
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
        onChangeLanguageFilter={(language, level) => {
          updateSearchParams({
            page: null,
            lang: language,
            langLevel: level,
          })
        }}
        onChangeSeenField={(value) => {
          updateSearchParams({ page: null, seenField: value })
        }}
        onChangeDatePreset={(value) => {
          updateSearchParams({ page: null, datePreset: value })
        }}
        onChangeOnlyWithinCommute={(checked) => {
          if (checked) {
            updateSearchParams({
              page: null,
              onlyWithinCommute: 'true',
              minCommute: null,
              maxCommute: commuteMaxMinutes != null ? String(commuteMaxMinutes) : null,
            })
          } else {
            updateSearchParams({ page: null, onlyWithinCommute: null })
          }
        }}
        onChangeMinCommuteMinutes={(value) => {
          updateSearchParams({
            page: null,
            onlyWithinCommute: null,
            minCommute: value != null ? String(value) : null,
          })
        }}
        onChangeMaxCommuteMinutes={(value) => {
          updateSearchParams({
            page: null,
            onlyWithinCommute: null,
            maxCommute: value != null ? String(value) : null,
          })
        }}
        search={search}
        onChangeSearch={(value) => updateSearchParams({ page: null, search: value || null })}
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
          onPageChange={(p) => {
            updateSearchParams({ page: p <= 1 ? null : String(p) })
          }}
        />
      </div>
    </div>
  )
}
