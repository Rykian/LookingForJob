import { useQuery } from '@apollo/client/react'
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card'
import { DashboardMetricsDocument, DashboardMetricsQuery } from '@/graphql/generated'

function MetricCard({ label, value }: { label: string; value: string | number }) {
  return (
    <Card>
      <CardHeader className="pb-2">
        <CardTitle className="text-sm font-medium text-muted-foreground">{label}</CardTitle>
      </CardHeader>
      <CardContent>
        <div className="text-3xl font-semibold tracking-tight">{value}</div>
      </CardContent>
    </Card>
  )
}

export default function DashboardPage() {
  const { data, loading, error } = useQuery<DashboardMetricsQuery>(DashboardMetricsDocument)

  if (loading) {
    return <div className="p-8 text-muted-foreground">Loading dashboard...</div>
  }

  if (error || !data) {
    return <div className="p-8 text-destructive">Failed to load dashboard metrics.</div>
  }

  const metrics = data.dashboardMetrics

  return (
    <div className="space-y-6 p-8">
      <div>
        <h1 className="text-2xl font-semibold">Dashboard</h1>
        <p className="mt-1 text-sm text-muted-foreground">Pipeline health and sourcing coverage.</p>
      </div>

      <section className="grid grid-cols-1 gap-4 md:grid-cols-2 xl:grid-cols-5">
        <MetricCard label="Total offers" value={metrics.total} />
        <MetricCard label="Fetched" value={metrics.fetched} />
        <MetricCard label="Enriched" value={metrics.enriched} />
        <MetricCard label="Scored" value={metrics.scored} />
        <MetricCard label="Avg score" value={metrics.averageScore ?? '-'} />
      </section>

      <Card>
        <CardHeader>
          <CardTitle className="text-lg">Top Sources</CardTitle>
        </CardHeader>
        <CardContent>
          {metrics.topSources.length === 0 ? (
            <p className="text-sm text-muted-foreground">No source data yet.</p>
          ) : (
            <ul className="space-y-2">
              {metrics.topSources.map((entry) => (
                <li key={entry.source} className="flex items-center justify-between rounded-md border px-3 py-2">
                  <span className="font-medium">{entry.source}</span>
                  <span className="text-sm text-muted-foreground">{entry.count} offers</span>
                </li>
              ))}
            </ul>
          )}
        </CardContent>
      </Card>
    </div>
  )
}
