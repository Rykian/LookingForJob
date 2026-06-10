import { useQuery, useSubscription } from '@apollo/client/react'
import { useEffect, useRef } from 'react'
import { SCORING_PROFILE_QUERY } from '@/features/profile/queries/documents'
import type {
  JobOfferLanguageCodesQuery,
  JobOffersQuery,
  JobOffersQueryVariables,
  ProvidersQuery,
  ScoringProfileQuery,
  SourcingStatusSubscription,
  TechnologiesQuery,
} from '@/graphql/generated'
import {
  ACTIVE_SOURCING_POLL_INTERVAL_MS,
  JOB_OFFER_LANGUAGE_CODES_QUERY,
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

  const { data: languageCodesData } = useQuery<JobOfferLanguageCodesQuery>(
    JOB_OFFER_LANGUAGE_CODES_QUERY,
  )
  const languageCodes = languageCodesData?.jobOfferLanguageCodes || []

  const { data: sourcingStatusData } = useSubscription<SourcingStatusSubscription>(
    SOURCING_STATUS_SUBSCRIPTION,
  )
  const sourcingStatus = sourcingStatusData?.sourcingStatus
  const isSourcingActive = sourcingStatus?.active ?? false

  const { data: profileData } = useQuery<ScoringProfileQuery>(SCORING_PROFILE_QUERY)
  const commuteCfg = (
    (profileData?.scoringProfile as Record<string, unknown> | undefined)?.location as
      | Record<string, unknown>
      | undefined
  )?.commute as Record<string, unknown> | undefined
  const commuteMaxMinutes =
    typeof commuteCfg?.max_minutes === 'number' ? commuteCfg.max_minutes : null

  const queryState = useQuery<JobOffersQuery, JobOffersQueryVariables>(JOB_OFFERS_QUERY, {
    variables,
  })

  const prevIsSourcingActive = useRef(isSourcingActive)
  useEffect(() => {
    if (isSourcingActive && !prevIsSourcingActive.current) {
      queryState.startPolling(ACTIVE_SOURCING_POLL_INTERVAL_MS)
    } else if (!isSourcingActive && prevIsSourcingActive.current) {
      queryState.stopPolling()
      void queryState.refetch()
    }
    prevIsSourcingActive.current = isSourcingActive
  }, [isSourcingActive, queryState])

  return {
    providerKeys,
    providerLoading,
    technologyKeys,
    technologiesLoading,
    languageCodes,
    sourcingStatus,
    isSourcingActive,
    commuteMaxMinutes,
    ...queryState,
  }
}
