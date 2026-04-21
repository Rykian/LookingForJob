import type { Meta, StoryObj } from '@storybook/react'
import { MemoryRouter } from 'react-router'
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
}

export const ActiveSourcing: Story = {
  parameters: { route: '/sourcing' },
}
