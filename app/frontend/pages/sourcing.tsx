import { ActionCard } from '@/features/sourcing/components/action-card'
import { LaunchDiscovery } from '@/features/sourcing/components/launch-discovery'
import { useMutationWithFeedback } from '@/features/sourcing/hooks/use-mutation'
import { RECOMPUTE_OFFER_SCORES_MUTATION } from '@/features/sourcing/queries/documents'
import type { RecomputeOfferScoresMutation } from '@/graphql/generated'

export default function SourcingPage() {
  const recomputeOfferScores = useMutationWithFeedback<RecomputeOfferScoresMutation>(
    RECOMPUTE_OFFER_SCORES_MUTATION,
  )

  return (
    <div className="space-y-6 p-8">
      <div>
        <h1 className="text-2xl font-semibold">Sourcing</h1>
        <p className="mt-1 text-sm text-muted-foreground">
          Trigger a full discovery run over configured keywords and sources.
        </p>
      </div>

      <LaunchDiscovery />

      <ActionCard
        title="Recompute Scores"
        description="This enqueues one scoring job for each existing offer."
        actionLabel="Recompute All Scores"
        pendingLabel="Recomputing..."
        loading={recomputeOfferScores.loading}
        error={recomputeOfferScores.error}
        successMessage={recomputeOfferScores.data?.recomputeOfferScores?.message}
        errorMessage="Failed to enqueue scoring jobs."
        onTrigger={() => {
          void recomputeOfferScores.trigger()
        }}
      />
    </div>
  )
}
