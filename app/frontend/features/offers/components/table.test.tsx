import { render, screen } from '@testing-library/react'
import { MemoryRouter } from 'react-router'
import { describe, expect, it } from 'vitest'
import { LocationModeEnum } from '@/graphql/generated'
import { Table } from './table'

describe('Table', () => {
  const mockOffers = [
    {
      id: '1',
      title: 'React Developer',
      url: 'https://example.com/1',
      company: 'TechCorp',
      source: 'linkedin',
      city: 'Paris',
      locationMode: LocationModeEnum.Hybrid,
      score: 85,
      firstSeenAt: new Date().toISOString(),
      primaryTechnologies: ['React', 'TypeScript', 'Node.js'],
    },
    {
      id: '2',
      title: 'Backend Engineer',
      url: 'https://example.com/2',
      company: 'StartupXYZ',
      source: 'wttj',
      city: 'Lyon',
      locationMode: LocationModeEnum.Remote,
      score: 72,
      firstSeenAt: new Date().toISOString(),
      primaryTechnologies: null,
    },
    {
      id: '3',
      title: 'Full Stack',
      url: 'https://example.com/3',
      company: 'BigCorp',
      source: 'linkedin',
      city: 'Berlin',
      locationMode: LocationModeEnum.OnSite,
      score: 65,
      firstSeenAt: new Date().toISOString(),
      primaryTechnologies: ['Python', 'Django', 'PostgreSQL', 'Docker'],
    },
  ]

  const defaultProps = {
    loading: false,
    error: false,
    totalCount: 3,
    isSourcingActive: false,
    sourcingStatusText: null,
    offers: mockOffers,
    onToggleSort: () => {},
    getSortIndicator: () => '↕',
  }

  it('renders table with offers', () => {
    render(
      <MemoryRouter>
        <Table {...defaultProps} />
      </MemoryRouter>,
    )

    expect(screen.getByText('React Developer')).toBeInTheDocument()
    expect(screen.getByText('Backend Engineer')).toBeInTheDocument()
    expect(screen.getByText('Full Stack')).toBeInTheDocument()
  })

  it('renders tech icons for offers with primaryTechnologies', () => {
    const { container } = render(
      <MemoryRouter>
        <Table {...defaultProps} />
      </MemoryRouter>,
    )

    const svgs = container.querySelectorAll('svg[role="img"]')
    expect(svgs.length).toBeGreaterThan(0)
  })

  it('renders correct number of icons for each offer', () => {
    const { container } = render(
      <MemoryRouter>
        <Table {...defaultProps} />
      </MemoryRouter>,
    )

    const rows = container.querySelectorAll('tbody tr')
    expect(rows.length).toBe(3)

    // First row: 3 technologies (React, TypeScript, Node.js)
    const firstRowIcons = rows[0]?.querySelectorAll('svg[role="img"]')
    expect(firstRowIcons?.length).toBe(3)

    // Second row: no technologies
    const secondRowIcons = rows[1]?.querySelectorAll('svg[role="img"]')
    expect(secondRowIcons?.length).toBe(0)

    // Third row: 4 technologies (Python, Django, PostgreSQL, Docker)
    const thirdRowIcons = rows[2]?.querySelectorAll('svg[role="img"]')
    expect(thirdRowIcons?.length).toBe(4)
  })

  it('renders SVG icons with correct attributes', () => {
    const { container } = render(
      <MemoryRouter>
        <Table {...defaultProps} />
      </MemoryRouter>,
    )

    const svgs = container.querySelectorAll('svg[role="img"]')
    svgs.forEach((svg) => {
      expect(svg).toHaveAttribute('viewBox', '0 0 24 24')
      expect(svg).toHaveAttribute('fill')
      expect(svg).toHaveAttribute('title')
      expect(svg).toHaveAttribute('aria-label')
    })
  })

  it('shows tech icons as tooltips on hover', () => {
    const { container } = render(
      <MemoryRouter>
        <Table {...defaultProps} />
      </MemoryRouter>,
    )

    const svgs = container.querySelectorAll('svg[role="img"]')
    const firstIcon = svgs[0]
    expect(firstIcon).toHaveAttribute('title')
    const title = firstIcon?.getAttribute('title')
    expect(['React', 'TypeScript', 'Node.js']).toContain(title)
  })

  it('respects max 6 icons limit', () => {
    const offersWithManyTechs = [
      {
        ...mockOffers[0],
        primaryTechnologies: [
          'React',
          'Vue',
          'Angular',
          'TypeScript',
          'Python',
          'Go',
          'Docker',
          'Kubernetes',
        ],
      },
    ]

    const { container } = render(
      <MemoryRouter>
        <Table {...defaultProps} offers={offersWithManyTechs} />
      </MemoryRouter>,
    )

    const svgs = container.querySelectorAll('svg[role="img"]')
    expect(svgs.length).toBeLessThanOrEqual(6)
  })

  it('renders loading state', () => {
    render(
      <MemoryRouter>
        <Table {...defaultProps} loading={true} offers={[]} />
      </MemoryRouter>,
    )

    expect(screen.getByText('Loading offers...')).toBeInTheDocument()
  })

  it('renders empty state', () => {
    render(
      <MemoryRouter>
        <Table {...defaultProps} offers={[]} totalCount={0} />
      </MemoryRouter>,
    )

    expect(screen.getByText('No offers found with current filters.')).toBeInTheDocument()
  })

  it('renders error state', () => {
    render(
      <MemoryRouter>
        <Table {...defaultProps} error={true} />
      </MemoryRouter>,
    )

    expect(screen.getByText('Failed to load offers.')).toBeInTheDocument()
  })
})
