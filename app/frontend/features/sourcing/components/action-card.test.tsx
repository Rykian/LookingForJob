import { render, screen } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { describe, expect, it, vi } from 'vitest'
import { ActionCard } from './action-card'

describe('ActionCard', () => {
  it('renders success and error states', () => {
    render(
      <ActionCard
        title="Launch Discovery"
        description="desc"
        actionLabel="Launch"
        pendingLabel="Launching..."
        loading={false}
        error={true}
        successMessage="Done"
        errorMessage="Failed"
        onTrigger={vi.fn()}
      />,
    )

    expect(screen.getByText('Done')).toBeInTheDocument()
    expect(screen.getByText('Failed')).toBeInTheDocument()
  })

  it('triggers action callback', async () => {
    const user = userEvent.setup()
    const onTrigger = vi.fn()

    render(
      <ActionCard
        title="Launch Discovery"
        description="desc"
        actionLabel="Launch"
        pendingLabel="Launching..."
        loading={false}
        error={false}
        successMessage={null}
        errorMessage="Failed"
        onTrigger={onTrigger}
      />,
    )

    await user.click(screen.getByRole('button', { name: 'Launch' }))

    expect(onTrigger).toHaveBeenCalledTimes(1)
  })
})
