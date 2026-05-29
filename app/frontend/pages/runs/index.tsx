import { useQuery } from '@apollo/client/react'
import { History } from 'lucide-react'
import { useNavigate } from 'react-router'
import { Badge } from '@/components/ui/badge'
import { RUNS_QUERY } from '@/features/runs/queries/documents'
import type { RunsQuery } from '@/graphql/generated'

type Run = RunsQuery['runs'][number]

function formatDate(iso: string) {
  return new Date(iso).toLocaleString(undefined, {
    dateStyle: 'medium',
    timeStyle: 'short',
  })
}

function RunRow({ run, onClick }: { run: Run; onClick: () => void }) {
  return (
    <tr
      className="cursor-pointer border-b border-border transition-colors hover:bg-muted/50"
      onClick={onClick}
    >
      <td className="px-4 py-3 text-sm text-muted-foreground whitespace-nowrap">
        {formatDate(run.createdAt)}
      </td>
      <td className="px-4 py-3">
        <div className="flex flex-wrap gap-1">
          {run.keywords.map((kw) => (
            <Badge key={kw} variant="secondary" className="text-xs">
              {kw}
            </Badge>
          ))}
        </div>
      </td>
      <td className="px-4 py-3">
        <div className="flex flex-wrap gap-1">
          {run.providers.map((p) => (
            <Badge key={p} variant="outline" className="text-xs">
              {p}
            </Badge>
          ))}
        </div>
      </td>
      <td className="px-4 py-3">
        <div className="flex flex-wrap gap-1">
          {run.workModes.map((m) => (
            <Badge key={m} variant="outline" className="text-xs">
              {m}
            </Badge>
          ))}
        </div>
      </td>
      <td className="px-4 py-3 text-right text-sm font-medium tabular-nums">
        {run.jobOffersCount}
      </td>
    </tr>
  )
}

export default function RunsPage() {
  const navigate = useNavigate()
  const { data, loading, error } = useQuery<RunsQuery>(RUNS_QUERY)

  const runs = data?.runs ?? []

  return (
    <div className="space-y-6 p-8">
      <div>
        <h1 className="text-2xl font-semibold">Discovery Runs</h1>
        <p className="mt-1 text-sm text-muted-foreground">
          Each run represents a discovery launch. Click a run to browse its offers.
        </p>
      </div>

      {loading && <p className="text-sm text-muted-foreground">Loading…</p>}
      {error && <p className="text-sm text-destructive">Failed to load runs.</p>}

      {!loading && !error && runs.length === 0 && (
        <div className="flex flex-col items-center gap-3 py-16 text-muted-foreground">
          <History className="h-10 w-10 opacity-40" />
          <p className="text-sm">No discovery runs yet.</p>
        </div>
      )}

      {runs.length > 0 && (
        <div className="overflow-hidden rounded-lg border border-border">
          <table className="w-full">
            <thead>
              <tr className="border-b border-border bg-muted/30 text-left text-xs font-medium uppercase tracking-wide text-muted-foreground">
                <th className="px-4 py-2">Launched</th>
                <th className="px-4 py-2">Keywords</th>
                <th className="px-4 py-2">Providers</th>
                <th className="px-4 py-2">Work Modes</th>
                <th className="px-4 py-2 text-right">Offers</th>
              </tr>
            </thead>
            <tbody>
              {runs.map((run) => (
                <RunRow
                  key={run.id}
                  run={run}
                  onClick={() => navigate(`/offers?runId=${run.id}`)}
                />
              ))}
            </tbody>
          </table>
        </div>
      )}
    </div>
  )
}
