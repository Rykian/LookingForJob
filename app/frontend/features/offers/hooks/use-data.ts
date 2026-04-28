import { useQuery, useSubscription } from '@apollo/client/react'
import type {
  JobOffersQuery,
  JobOffersQueryVariables,
  ProvidersQuery,
  SourcingStatusSubscription,
  TechnologiesQuery,
} from '@/graphql/generated'
import {
  ACTIVE_SOURCING_POLL_INTERVAL_MS,
  JOB_OFFERS_QUERY,
  PROVIDERS_QUERY,
  SOURCING_STATUS_SUBSCRIPTION,
  TECHNOLOGIES_QUERY,
} from '../queries/documents'

interface UseJobOffersDataParams {
  variables: JobOffersQueryVariables
}

export function useJobOffersData({ variables }: UseJobOffersDataParams) {
  const { data: providerData, loading: providerLoading } = useQuery<ProvidersQuery>(PROVIDERS_QUERY)
  const providerKeys = providerData?.providers || []

  const { data: technologiesData, loading: technologiesLoading } =
    useQuery<TechnologiesQuery>(TECHNOLOGIES_QUERY)
  const technologyKeys = technologiesData?.technologies || []

  const { data: sourcingStatusData } = useSubscription<SourcingStatusSubscription>(
    SOURCING_STATUS_SUBSCRIPTION,
    { fetchPolicy: 'cache-first' },
  )
  const sourcingStatus = sourcingStatusData?.sourcingStatus
  const isSourcingActive = sourcingStatus?.active ?? false

  const queryState = useQuery<JobOffersQuery, JobOffersQueryVariables>(JOB_OFFERS_QUERY, {
    variables,
    pollInterval: isSourcingActive ? ACTIVE_SOURCING_POLL_INTERVAL_MS : undefined,
  })

  return {
    providerKeys,
    providerLoading,
    technologyKeys,
    technologiesLoading,
    sourcingStatus,
    isSourcingActive,
    ...queryState,
  }
}
