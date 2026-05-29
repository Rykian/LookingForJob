import { ChevronDown, ChevronRight } from 'lucide-react'
import { useState } from 'react'
import { Link } from 'react-router'
import { Badge } from '@/components/ui/badge'
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card'
import type { PipelineErrorsQuery } from '@/graphql/generated'

type ErrorNode = PipelineErrorsQuery['pipelineErrors']['nodes'][number]

interface TableProps {
  loading: boolean
  error?: boolean
  totalCount: number
  errors: ErrorNode[]
}

function formatDate(iso: string) {
  return new Date(iso).toLocaleString(undefined, {
    dateStyle: 'medium',
    timeStyle: 'short',
  })
}

function ErrorRow({ row }: { row: ErrorNode }) {
  const [expanded, setExpanded] = useState(false)

  return (
    <>
      <tr
        className="cursor-pointer border-b transition-colors hover:bg-muted/40"
        onClick={() => setExpanded((v) => !v)}
      >
        <td className="px-3 py-2 align-top">
          {expanded ? (
            <ChevronDown className="h-4 w-4 text-muted-foreground" />
          ) : (
            <ChevronRight className="h-4 w-4 text-muted-foreground" />
          )}
        </td>
        <td className="px-3 py-2 align-top whitespace-nowrap text-muted-foreground">
          {formatDate(row.createdAt)}
        </td>
        <td className="px-3 py-2 align-top">
          <Badge variant="outline">{row.step}</Badge>
        </td>
        <td className="px-3 py-2 align-top">{row.source ?? '-'}</td>
        <td className="px-3 py-2 align-top font-medium">{row.errorClass}</td>
        <td className="px-3 py-2 align-top">
          <div className="line-clamp-2 text-muted-foreground">{row.errorMessage}</div>
        </td>
        <td className="px-3 py-2 align-top">
          <Badge variant={row.resolved ? 'secondary' : 'destructive'}>
            {row.resolved ? 'resolved' : 'unresolved'}
          </Badge>
        </td>
      </tr>
      {expanded && (
        <tr className="border-b bg-muted/20">
          <td colSpan={7} className="px-6 py-4">
            <dl className="grid grid-cols-1 gap-3 text-sm md:grid-cols-2">
              <div>
                <dt className="text-xs font-medium uppercase text-muted-foreground">
                  Error message
                </dt>
                <dd className="mt-1 whitespace-pre-wrap break-words">{row.errorMessage}</dd>
              </div>
              <div>
                <dt className="text-xs font-medium uppercase text-muted-foreground">References</dt>
                <dd className="mt-1 space-y-1">
                  {row.jobOfferId && (
                    <div>
                      Job offer:{' '}
                      <Link
                        className="text-primary hover:underline"
                        to={`/offers/${row.jobOfferId}`}
                      >
                        #{row.jobOfferId}
                      </Link>
                    </div>
                  )}
                  {row.runId && (
                    <div>
                      Run:{' '}
                      <Link
                        className="text-primary hover:underline"
                        to={`/offers?runId=${row.runId}`}
                      >
                        #{row.runId}
                      </Link>
                    </div>
                  )}
                  {row.stepVersion != null && <div>Step version: {row.stepVersion}</div>}
                </dd>
              </div>
              <div className="md:col-span-2">
                <dt className="text-xs font-medium uppercase text-muted-foreground">Arguments</dt>
                <dd className="mt-1">
                  <pre className="overflow-x-auto rounded-md border bg-background p-3 text-xs">
                    {JSON.stringify(row.arguments, null, 2)}
                  </pre>
                </dd>
              </div>
            </dl>
          </td>
        </tr>
      )}
    </>
  )
}

export function Table({ loading, error, totalCount, errors }: TableProps) {
  return (
    <Card>
      <CardHeader>
        <CardTitle className="text-base">
          {loading ? 'Loading errors...' : `${totalCount} errors`}
        </CardTitle>
      </CardHeader>
      <CardContent>
        {error ? <p className="text-destructive">Failed to load errors.</p> : null}

        {!loading && !error && errors.length === 0 ? (
          <p className="text-sm text-muted-foreground">No errors found with current filters.</p>
        ) : null}

        <div className="overflow-x-auto">
          <table className="w-full min-w-215 text-left text-sm">
            <thead>
              <tr className="border-b text-muted-foreground">
                <th className="w-8 px-3 py-2" />
                <th className="px-3 py-2 font-medium">Created</th>
                <th className="px-3 py-2 font-medium">Step</th>
                <th className="px-3 py-2 font-medium">Source</th>
                <th className="px-3 py-2 font-medium">Class</th>
                <th className="px-3 py-2 font-medium">Message</th>
                <th className="px-3 py-2 font-medium">Status</th>
              </tr>
            </thead>
            <tbody>
              {errors.map((row) => (
                <ErrorRow key={row.id} row={row} />
              ))}
            </tbody>
          </table>
        </div>
      </CardContent>
    </Card>
  )
}
