import { MockedProvider } from '@apollo/client/testing/react'
import { render, screen, waitFor } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { describe, expect, it, vi } from 'vitest'
import {
  LAUNCH_DISCOVERY_MUTATION,
  PROVIDERS_QUERY,
  TECHNOLOGIES_QUERY,
} from '@/features/sourcing/queries/documents'
import { LaunchDiscovery } from './launch-discovery'

const mockProvidersQuery = {
  request: { query: PROVIDERS_QUERY },
  result: {
    data: { providers: ['linkedin', 'indeed', 'apec'] },
  },
}

const mockTechnologiesQuery = {
  request: { query: TECHNOLOGIES_QUERY },
  result: {
    data: { technologies: ['ruby', 'nodejs', 'java'] },
  },
}

const mockSuccessMutation = {
  request: {
    query: LAUNCH_DISCOVERY_MUTATION,
    variables: {
      keywords: ['ruby', 'nodejs', 'java'],
      providers: ['linkedin', 'indeed', 'apec'],
    },
  },
  result: {
    data: {
      launchDiscovery: { message: 'Discovery job enqueued.' },
    },
  },
}

async function waitForAllSelectionsLoaded() {
  await screen.findByText('apec')
  await screen.findByText('java')
}

describe('LaunchDiscovery', () => {
  it('pre-selects all providers on mount', async () => {
    render(
      <MockedProvider mocks={[mockProvidersQuery, mockTechnologiesQuery]}>
        <LaunchDiscovery />
      </MockedProvider>,
    )

    expect(await screen.findByText('linkedin')).toBeInTheDocument()
    expect(await screen.findByText('indeed')).toBeInTheDocument()
    expect(await screen.findByText('apec')).toBeInTheDocument()
  })

  it('pre-selects all keywords on mount', async () => {
    render(
      <MockedProvider mocks={[mockProvidersQuery, mockTechnologiesQuery]}>
        <LaunchDiscovery />
      </MockedProvider>,
    )

    expect(await screen.findByText('ruby')).toBeInTheDocument()
    expect(await screen.findByText('nodejs')).toBeInTheDocument()
    expect(await screen.findByText('java')).toBeInTheDocument()
  })

  it('shows success message after successful launch', async () => {
    const user = userEvent.setup()

    render(
      <MockedProvider mocks={[mockProvidersQuery, mockTechnologiesQuery, mockSuccessMutation]}>
        <LaunchDiscovery />
      </MockedProvider>,
    )

    await waitForAllSelectionsLoaded()

    await user.click(screen.getByRole('button', { name: 'Launch Discovery' }))

    expect(await screen.findByText('Discovery job enqueued.')).toBeInTheDocument()
  })

  it('calls onSuccess callback when mutation succeeds', async () => {
    const user = userEvent.setup()
    const onSuccess = vi.fn()

    render(
      <MockedProvider mocks={[mockProvidersQuery, mockTechnologiesQuery, mockSuccessMutation]}>
        <LaunchDiscovery onSuccess={onSuccess} />
      </MockedProvider>,
    )

    await waitForAllSelectionsLoaded()

    await user.click(screen.getByRole('button', { name: 'Launch Discovery' }))

    await waitFor(() => {
      expect(onSuccess).toHaveBeenCalledTimes(1)
    })
  })

  it('shows error message when mutation fails', async () => {
    const user = userEvent.setup()
    const errorMutation = {
      request: {
        query: LAUNCH_DISCOVERY_MUTATION,
        variables: {
          keywords: ['ruby', 'nodejs', 'java'],
          providers: ['linkedin', 'indeed', 'apec'],
        },
      },
      error: new Error('Network error'),
    }

    render(
      <MockedProvider mocks={[mockProvidersQuery, mockTechnologiesQuery, errorMutation]}>
        <LaunchDiscovery />
      </MockedProvider>,
    )

    await waitForAllSelectionsLoaded()

    await user.click(screen.getByRole('button', { name: 'Launch Discovery' }))

    expect(await screen.findByText('Failed to enqueue discovery job.')).toBeInTheDocument()
  })

  it('does not call onSuccess when mutation fails', async () => {
    const user = userEvent.setup()
    const onSuccess = vi.fn()
    const errorMutation = {
      request: {
        query: LAUNCH_DISCOVERY_MUTATION,
        variables: {
          keywords: ['ruby', 'nodejs', 'java'],
          providers: ['linkedin', 'indeed', 'apec'],
        },
      },
      error: new Error('Network error'),
    }

    render(
      <MockedProvider mocks={[mockProvidersQuery, mockTechnologiesQuery, errorMutation]}>
        <LaunchDiscovery onSuccess={onSuccess} />
      </MockedProvider>,
    )

    await waitForAllSelectionsLoaded()

    await user.click(screen.getByRole('button', { name: 'Launch Discovery' }))

    expect(await screen.findByText('Failed to enqueue discovery job.')).toBeInTheDocument()

    expect(onSuccess).not.toHaveBeenCalled()
  })

  it('shows launching state while mutation is in flight', async () => {
    const user = userEvent.setup()
    const delayedMutation = { ...mockSuccessMutation, delay: 100 }

    render(
      <MockedProvider mocks={[mockProvidersQuery, mockTechnologiesQuery, delayedMutation]}>
        <LaunchDiscovery />
      </MockedProvider>,
    )

    await waitForAllSelectionsLoaded()

    await user.click(screen.getByRole('button', { name: 'Launch Discovery' }))

    expect(screen.getByRole('button', { name: 'Launching...' })).toBeDisabled()
  })

  it('disables launch button while providers are loading', async () => {
    const slowProviders = {
      ...mockProvidersQuery,
      delay: 1000,
    }

    render(
      <MockedProvider mocks={[slowProviders, mockTechnologiesQuery]}>
        <LaunchDiscovery />
      </MockedProvider>,
    )

    expect(screen.getByRole('button', { name: 'Launch Discovery' })).toBeDisabled()
  })

  it('disables launch button while keywords are loading', async () => {
    const slowKeywords = {
      ...mockTechnologiesQuery,
      delay: 1000,
    }

    render(
      <MockedProvider mocks={[mockProvidersQuery, slowKeywords]}>
        <LaunchDiscovery />
      </MockedProvider>,
    )

    expect(screen.getByRole('button', { name: 'Launch Discovery' })).toBeDisabled()
  })
})
