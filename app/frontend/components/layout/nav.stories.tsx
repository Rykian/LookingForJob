import type { Meta, StoryObj } from '@storybook/react'
import { MemoryRouter } from 'react-router'
import { expect, within } from 'storybook/test'
import Nav from './nav'

const meta = {
  title: 'Layout/Nav',
  component: Nav,
  parameters: { layout: 'centered' },
  tags: ['autodocs'],
  decorators: [
    (Story, context) => {
      const route = context.parameters.route || '/'

      return (
        <MemoryRouter initialEntries={[route]}>
          <div className="w-56 bg-sidebar-background rounded-lg py-4">
            <Story />
          </div>
        </MemoryRouter>
      )
    },
  ],
} satisfies Meta<typeof Nav>

export default meta
type Story = StoryObj<typeof meta>

export const Default: Story = {}

export const ActiveOffers: Story = {
  parameters: { route: '/offers' },
  play: async ({ canvasElement }) => {
    const canvas = within(canvasElement)
    await expect(canvas.getByRole('link', { name: 'Offers' })).toHaveAttribute(
      'aria-current',
      'page',
    )
    await expect(canvas.getByRole('link', { name: 'Dashboard' })).not.toHaveAttribute(
      'aria-current',
    )
  },
}

export const ActiveSourcing: Story = {
  parameters: { route: '/sourcing' },
  play: async ({ canvasElement }) => {
    const canvas = within(canvasElement)
    await expect(canvas.getByRole('link', { name: 'Sourcing' })).toHaveAttribute(
      'aria-current',
      'page',
    )
  },
}
