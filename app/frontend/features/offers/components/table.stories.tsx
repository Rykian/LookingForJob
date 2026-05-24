import type { Meta, StoryObj } from '@storybook/react'
import { MemoryRouter } from 'react-router'
import { expect } from 'storybook/test'

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
    primaryTechnologies: ['React', 'TypeScript', 'Node.js', 'PostgreSQL'] as string[],
    commuteDurationMinutes: 25,
    commuteWithinMax: true,
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
    primaryTechnologies: ['Ruby', 'Rails', 'PostgreSQL'] as string[],
    commuteDurationMinutes: null,
    commuteWithinMax: null,
  },
  {
    id: '3',
    title: 'Backend Engineer',
    url: 'https://example.test/offers/3',
    company: 'Tech Corp',
    source: 'linkedin',
    city: 'Berlin',
    locationMode: LocationModeEnum.OnSite,
    score: 65,
    firstSeenAt: new Date().toISOString(),
    primaryTechnologies: null,
    commuteDurationMinutes: 120,
    commuteWithinMax: false,
  },
  {
    id: '4',
    title: 'Full Stack with Many Techs',
    url: 'https://example.test/offers/4',
    company: 'StartupXYZ',
    source: 'wttj',
    city: 'Amsterdam',
    locationMode: LocationModeEnum.Hybrid,
    score: 92,
    firstSeenAt: new Date().toISOString(),
    primaryTechnologies: [
      'React',
      'Vue',
      'Angular',
      'TypeScript',
      'Python',
      'Go',
      'Docker',
      'Kubernetes',
    ] as string[],
    commuteDurationMinutes: 45,
    commuteWithinMax: true,
  },
] as const

export const Default: Story = {
  args: {
    loading: false,
    error: false,
    totalCount: 4,
    isSourcingActive: false,
    sourcingStatusText: 'Sourcing idle',
    offers: [...offers],
    onToggleSort: () => {},
    getSortIndicator: () => '↕',
  },
}

export const WithTechIcons: Story = {
  args: {
    ...Default.args,
  },
  play: async ({ canvasElement }) => {
    // Verify tech icons are rendered as SVG elements
    const svgs = canvasElement.querySelectorAll('svg[role="img"]')
    expect(svgs.length).toBeGreaterThan(0)

    // Verify first offer (id='1') has React, TypeScript, Node.js, PostgreSQL icons
    const firstRow = canvasElement.querySelector('tbody tr:first-child')
    expect(firstRow).toBeTruthy()

    const firstRowSvgs = firstRow?.querySelectorAll('svg[role="img"]')
    expect(firstRowSvgs?.length).toBeGreaterThanOrEqual(4)

    // Verify SVG has viewBox and fill attributes
    svgs.forEach((svg) => {
      expect(svg).toHaveAttribute('viewBox', '0 0 24 24')
      expect(svg).toHaveAttribute('fill')
      expect(svg).toHaveAttribute('title')
    })

    // Verify third row (id='3') has no tech icons (null primaryTechnologies)
    const thirdRow = canvasElement.querySelector('tbody tr:nth-child(3)')
    const thirdRowSvgs = thirdRow?.querySelectorAll('svg[role="img"]')
    expect(thirdRowSvgs?.length).toBe(0)

    // Verify fourth row shows at most 6 icons (sliced from 8)
    const fourthRow = canvasElement.querySelector('tbody tr:nth-child(4)')
    const fourthRowSvgs = fourthRow?.querySelectorAll('svg[role="img"]')
    expect(fourthRowSvgs?.length).toBeLessThanOrEqual(6)
    expect(fourthRowSvgs?.length).toBe(6)
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
