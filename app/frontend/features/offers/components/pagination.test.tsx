import { render, screen } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { describe, expect, it, vi } from 'vitest'
import { Pagination } from './pagination'

describe('Pagination', () => {
  it('renders all page numbers when totalPages <= 7', () => {
    render(<Pagination page={2} totalPages={5} onPageChange={vi.fn()} />)

    for (let i = 1; i <= 5; i++) {
      expect(screen.getByRole('button', { name: String(i) })).toBeInTheDocument()
    }
  })

  it('marks current page with aria-current', () => {
    render(<Pagination page={3} totalPages={5} onPageChange={vi.fn()} />)

    expect(screen.getByRole('button', { name: '3' })).toHaveAttribute('aria-current', 'page')
    expect(screen.getByRole('button', { name: '2' })).not.toHaveAttribute('aria-current')
  })

  it('renders ellipsis and boundary pages for large page counts', () => {
    render(<Pagination page={5} totalPages={10} onPageChange={vi.fn()} />)

    expect(screen.getByRole('button', { name: '1' })).toBeInTheDocument()
    expect(screen.getByRole('button', { name: '10' })).toBeInTheDocument()
    expect(screen.getAllByText('…')).toHaveLength(2)
  })

  it('disables previous button on first page', () => {
    render(<Pagination page={1} totalPages={5} onPageChange={vi.fn()} />)

    expect(screen.getByRole('button', { name: 'Previous' })).toBeDisabled()
    expect(screen.getByRole('button', { name: 'Next' })).not.toBeDisabled()
  })

  it('disables next button on last page', () => {
    render(<Pagination page={5} totalPages={5} onPageChange={vi.fn()} />)

    expect(screen.getByRole('button', { name: 'Next' })).toBeDisabled()
    expect(screen.getByRole('button', { name: 'Previous' })).not.toBeDisabled()
  })

  it('calls onPageChange with previous page when clicking Previous', async () => {
    const user = userEvent.setup()
    const onPageChange = vi.fn()

    render(<Pagination page={3} totalPages={5} onPageChange={onPageChange} />)

    await user.click(screen.getByRole('button', { name: 'Previous' }))

    expect(onPageChange).toHaveBeenCalledWith(2)
  })

  it('calls onPageChange with next page when clicking Next', async () => {
    const user = userEvent.setup()
    const onPageChange = vi.fn()

    render(<Pagination page={3} totalPages={5} onPageChange={onPageChange} />)

    await user.click(screen.getByRole('button', { name: 'Next' }))

    expect(onPageChange).toHaveBeenCalledWith(4)
  })

  it('calls onPageChange with the clicked page number', async () => {
    const user = userEvent.setup()
    const onPageChange = vi.fn()

    render(<Pagination page={1} totalPages={5} onPageChange={onPageChange} />)

    await user.click(screen.getByRole('button', { name: '4' }))

    expect(onPageChange).toHaveBeenCalledWith(4)
  })
})
