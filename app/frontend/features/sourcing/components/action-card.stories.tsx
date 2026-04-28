import type { Meta, StoryObj } from '@storybook/react'
import { ActionCard } from './action-card'

const meta = {
  title: 'Sourcing/ActionCard',
  component: ActionCard,
  parameters: { layout: 'padded' },
  tags: ['autodocs'],
  decorators: [
    (Story) => (
      <div className="max-w-3xl">
        <Story />
      </div>
    ),
  ],
} satisfies Meta<typeof ActionCard>

export default meta
type Story = StoryObj<typeof meta>

export const Default: Story = {
  args: {
    title: 'Launch Discovery',
    description: 'Enqueue a full discovery run.',
    actionLabel: 'Launch Discovery',
    pendingLabel: 'Launching...',
    loading: false,
    error: false,
    successMessage: null,
    errorMessage: 'Failed to enqueue discovery job.',
    onTrigger: () => {},
  },
}

export const Success: Story = {
  args: {
    ...Default.args,
    successMessage: 'Discovery jobs enqueued.',
  },
}

export const ErrorState: Story = {
  args: {
    ...Default.args,
    error: true,
  },
}
