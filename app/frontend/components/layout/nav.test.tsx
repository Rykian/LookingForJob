import { render, screen } from '@testing-library/react'
import { MemoryRouter } from 'react-router'
import { describe, expect, it } from 'vitest'
import Nav from './nav'

describe('Nav', () => {
  it('renders navigation links and external link', () => {
    render(
      <MemoryRouter initialEntries={['/']}>
        <Nav />
      </MemoryRouter>,
    )

    expect(screen.getByRole('link', { name: 'Dashboard' })).toBeInTheDocument()
    expect(screen.getByRole('link', { name: 'Offers' })).toBeInTheDocument()
    expect(screen.getByRole('link', { name: 'Sourcing' })).toBeInTheDocument()
    expect(screen.getByRole('link', { name: 'Profile' })).toBeInTheDocument()

    const sidekiqLink = screen.getByRole('link', { name: 'Sidekiq UI' })
    expect(sidekiqLink).toHaveAttribute('target', '_blank')
    expect(sidekiqLink).toHaveAttribute('rel', 'noreferrer')
  })

  it('marks current route as active', () => {
    render(
      <MemoryRouter initialEntries={['/offers']}>
        <Nav />
      </MemoryRouter>,
    )

    expect(screen.getByRole('link', { name: 'Offers' })).toHaveAttribute('aria-current', 'page')
    expect(screen.getByRole('link', { name: 'Dashboard' })).not.toHaveAttribute('aria-current')
  })
})
