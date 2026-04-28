import type { Meta, StoryObj } from '@storybook/react'
import { MemoryRouter } from 'react-router'
import { LocationModeEnum } from '@/graphql/generated'
import { Table } from './table'

const meta = {
  title: 'Offers/Table',
  component: Table,
  parameters: { layout: 'padded' },
  tags: ['autodocs'],
  decorators: [
    (Story) => (
      <MemoryRouter>
        <Story />
      </MemoryRouter>
    ),
  ],
} satisfies Meta<typeof Table>

export default meta
type Story = StoryObj<typeof meta>

const offers = [
  {
    id: '1',
    title: 'Senior Fullstack Engineer',
    url: 'https://example.test/offers/1',
    company: 'Acme',
    source: 'linkedin',
    city: 'Paris',
    locationMode: LocationModeEnum.Hybrid,
    score: 87,
    firstSeenAt: new Date().toISOString(),
  },
  {
    id: '2',
    title: 'Rails Developer',
    url: 'https://example.test/offers/2',
    company: 'Globex',
    source: 'wttj',
    city: 'Lyon',
    locationMode: LocationModeEnum.Remote,
    score: 79,
    firstSeenAt: new Date().toISOString(),
  },
] as const

export const Default: Story = {
  args: {
    loading: false,
    error: false,
    totalCount: 2,
    isSourcingActive: false,
    sourcingStatusText: 'Sourcing idle',
    offers: [...offers],
    onToggleSort: () => {},
    getSortIndicator: () => '↕',
  },
}

export const Loading: Story = {
  args: {
    ...Default.args,
    loading: true,
    offers: [],
    totalCount: 0,
  },
}

export const Empty: Story = {
  args: {
    ...Default.args,
    offers: [],
    totalCount: 0,
  },
}
