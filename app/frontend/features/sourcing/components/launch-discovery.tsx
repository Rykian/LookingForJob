import { useMutation, useQuery } from '@apollo/client/react'
import { useEffect, useState } from 'react'
import { useNavigate } from 'react-router'
import {
  LAUNCH_DISCOVERY_MUTATION,
  PROVIDERS_QUERY,
  TECHNOLOGIES_QUERY,
} from '@/features/sourcing/queries/documents'
import type {
  LaunchDiscoveryMutation,
  ProvidersQuery,
  TechnologiesQuery,
} from '@/graphql/generated'
import { LaunchDiscoveryView } from './launch-discovery-view'

interface LaunchDiscoveryProps {
  onSuccess?: () => void
}

export function LaunchDiscovery({ onSuccess }: LaunchDiscoveryProps) {
  const navigate = useNavigate()
  const [selectedKeywords, setSelectedKeywords] = useState<string[]>([])
  const [selectedProviders, setSelectedProviders] = useState<string[]>([])

  const { data: providersData, loading: providersLoading } =
    useQuery<ProvidersQuery>(PROVIDERS_QUERY)
  const { data: technologiesData, loading: technologiesLoading } =
    useQuery<TechnologiesQuery>(TECHNOLOGIES_QUERY)

  const [launchDiscovery, { loading, error, data }] =
    useMutation<LaunchDiscoveryMutation>(LAUNCH_DISCOVERY_MUTATION)

  const providers = providersData?.providers || []
  const technologies = technologiesData?.technologies || []

  useEffect(() => {
    if (providers.length > 0) {
      setSelectedProviders(providers)
    }
  }, [providers])

  useEffect(() => {
    if (technologies.length > 0) {
      setSelectedKeywords(technologies)
    }
  }, [technologies])

  useEffect(() => {
    const runId = data?.launchDiscovery?.runId
    if (runId) {
      onSuccess?.()
      navigate(`/offers?runId=${runId}`)
    }
  }, [data?.launchDiscovery?.runId, onSuccess, navigate])

  const handleLaunch = () => {
    launchDiscovery({
      variables: {
        keywords: selectedKeywords,
        providers: selectedProviders,
      },
    }).catch(() => {
      // Apollo's useMutation hook captures the error in its state; swallow the
      // rejection so we don't trip the test runner with unhandled promise errors.
    })
  }

  return (
    <LaunchDiscoveryView
      providers={providers}
      providersLoading={providersLoading}
      selectedProviders={selectedProviders}
      onProvidersChange={setSelectedProviders}
      keywords={technologies}
      keywordsLoading={technologiesLoading}
      selectedKeywords={selectedKeywords}
      onKeywordsChange={setSelectedKeywords}
      isLaunching={loading}
      error={error}
      successMessage={data?.launchDiscovery?.message}
      onLaunch={handleLaunch}
    />
  )
}
