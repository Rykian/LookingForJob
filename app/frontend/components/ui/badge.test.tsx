import { render, screen } from '@testing-library/react'
import { describe, expect, it } from 'vitest'
import { Badge } from './badge'

describe('Badge', () => {
  it('renders children', () => {
    render(<Badge>New</Badge>)

    expect(screen.getByText('New')).toBeInTheDocument()
  })

  it('applies custom className', () => {
    render(<Badge className="qa-badge">Stable</Badge>)

    expect(screen.getByText('Stable')).toHaveClass('qa-badge')
  })
})
