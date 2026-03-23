import { gql } from '@apollo/client'
import { useMutation } from '@apollo/client/react'
import { Button } from '@/components/ui/button'
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from '@/components/ui/card'
import type { LaunchDiscoveryMutation, RecomputeOfferScoresMutation } from '@/graphql/generated'

const LAUNCH_DISCOVERY_MUTATION = gql`
  mutation LaunchDiscovery {
    launchDiscovery(input: {}) {
      message
    }
  }
`

const RECOMPUTE_OFFER_SCORES_MUTATION = gql`
  mutation RecomputeOfferScores {
    recomputeOfferScores(input: {}) {
      message
      enqueuedCount
    }
  }
`

export default function SourcingPage() {
  const [launchDiscovery, { loading, error, data }] = useMutation<LaunchDiscoveryMutation>(
    LAUNCH_DISCOVERY_MUTATION,
  )
  const [recomputeOfferScores, { loading: recomputeLoading, error: recomputeError, data: recomputeData }] =
    useMutation<RecomputeOfferScoresMutation>(RECOMPUTE_OFFER_SCORES_MUTATION)

  return (
    <div className="space-y-6 p-8">
      <div>
        <h1 className="text-2xl font-semibold">Sourcing</h1>
        <p className="mt-1 text-sm text-muted-foreground">Trigger a full discovery run over configured keywords and sources.</p>
      </div>

      <Card className="max-w-2xl">
        <CardHeader>
          <CardTitle>Launch Discovery</CardTitle>
          <CardDescription>
            This enqueues one discovery job per source x keyword x work mode combination.
          </CardDescription>
        </CardHeader>
        <CardContent className="space-y-3">
          <Button disabled={loading} onClick={() => launchDiscovery()}>
            {loading ? 'Launching...' : 'Launch Discovery'}
          </Button>

          {data?.launchDiscovery?.message ? (
            <p className="text-sm text-green-700">{data.launchDiscovery.message}</p>
          ) : null}

          {error ? <p className="text-sm text-destructive">Failed to enqueue discovery job.</p> : null}
        </CardContent>
      </Card>

      <Card className="max-w-2xl">
        <CardHeader>
          <CardTitle>Recompute Scores</CardTitle>
          <CardDescription>
            This enqueues one scoring job for each existing offer.
          </CardDescription>
        </CardHeader>
        <CardContent className="space-y-3">
          <Button disabled={recomputeLoading} onClick={() => recomputeOfferScores()}>
            {recomputeLoading ? 'Recomputing...' : 'Recompute All Scores'}
          </Button>

          {recomputeData?.recomputeOfferScores?.message ? (
            <p className="text-sm text-green-700">{recomputeData.recomputeOfferScores.message}</p>
          ) : null}

          {recomputeError ? <p className="text-sm text-destructive">Failed to enqueue scoring jobs.</p> : null}
        </CardContent>
      </Card>
    </div>
  )
}
