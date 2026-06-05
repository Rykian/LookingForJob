import { X } from 'lucide-react'
import { useSearchParams } from 'react-router'
import { FiltersPanel } from '@/features/errors/components/filters-panel'
import { Table } from '@/features/errors/components/table'
import { usePipelineErrorsData } from '@/features/errors/hooks/use-data'
import { usePipelineErrorsFilters } from '@/features/errors/hooks/use-filters'
import { Pagination } from '@/features/offers/components/pagination'

export default function ErrorsPage() {
  const [searchParams, setSearchParams] = useSearchParams()
  const {
    page,
    variables,
    resolved,
    selectedSteps,
    selectedSources,
    errorClass,
    runId,
    jobOfferId,
    updateSearchParams,
    resetSearchParams,
  } = usePipelineErrorsFilters({ searchParams, setSearchParams })

  const { sources, errorClasses, facetsLoading, data, loading, error } = usePipelineErrorsData({
    variables,
  })

  const totalPages = data?.pipelineErrors.totalPages ?? 1
  const errors = data?.pipelineErrors.nodes ?? []

  return (
    <div className="space-y-6 p-8">
      <div>
        <h1 className="text-2xl font-semibold">Pipeline errors</h1>
        <p className="mt-1 text-sm text-muted-foreground">
          Sourcing pipeline failures, with auto-resolve when the offending step succeeds again.
        </p>
      </div>

      {(runId || jobOfferId) && (
        <div className="flex flex-wrap items-center gap-2 rounded-md border border-border bg-muted/40 px-3 py-2 text-sm">
          {runId && (
            <span className="inline-flex items-center gap-1">
              <span className="text-muted-foreground">Run</span>
              <span className="font-medium">#{runId}</span>
              <button
                type="button"
                className="rounded p-0.5 hover:bg-muted"
                onClick={() => updateSearchParams({ runId: null, page: null })}
                aria-label="Clear run filter"
              >
                <X className="h-3.5 w-3.5 text-muted-foreground" />
              </button>
            </span>
          )}
          {jobOfferId && (
            <span className="inline-flex items-center gap-1">
              <span className="text-muted-foreground">Offer</span>
              <span className="font-medium">#{jobOfferId}</span>
              <button
                type="button"
                className="rounded p-0.5 hover:bg-muted"
                onClick={() => updateSearchParams({ jobOfferId: null, page: null })}
                aria-label="Clear offer filter"
              >
                <X className="h-3.5 w-3.5 text-muted-foreground" />
              </button>
            </span>
          )}
        </div>
      )}

      <FiltersPanel
        resolved={resolved}
        selectedSteps={selectedSteps}
        selectedSources={selectedSources}
        errorClass={errorClass}
        sources={sources}
        errorClasses={errorClasses}
        facetsLoading={facetsLoading}
        onChangeResolved={(value) => {
          updateSearchParams({ page: null, resolved: value === 'unresolved' ? null : value })
        }}
        onChangeSteps={(items) => {
          updateSearchParams({
            page: null,
            steps: items.length > 0 ? items.join(',') : null,
          })
        }}
        onChangeSources={(items) => {
          updateSearchParams({
            page: null,
            sources: items.length > 0 ? items.join(',') : null,
          })
        }}
        onChangeErrorClass={(value) => {
          updateSearchParams({ page: null, errorClass: value || null })
        }}
        onReset={resetSearchParams}
      />

      <div className="space-y-2">
        <Table
          loading={loading}
          error={Boolean(error)}
          totalCount={data?.pipelineErrors.totalCount ?? 0}
          errors={errors}
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
