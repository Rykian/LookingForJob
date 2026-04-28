import { render, screen } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { describe, expect, it, vi } from 'vitest'
import { Pagination } from './pagination'

describe('Pagination', () => {
  it('renders current page label', () => {
    render(<Pagination page={2} totalPages={5} onPrevious={vi.fn()} onNext={vi.fn()} />)

    expect(screen.getByText('Page 2 of 5')).toBeInTheDocument()
  })

  it('disables previous button on first page', () => {
    render(<Pagination page={1} totalPages={5} onPrevious={vi.fn()} onNext={vi.fn()} />)

    expect(screen.getByRole('button', { name: 'Previous' })).toBeDisabled()
    expect(screen.getByRole('button', { name: 'Next' })).not.toBeDisabled()
  })

  it('calls handlers when clicking next and previous', async () => {
    const user = userEvent.setup()
    const onPrevious = vi.fn()
    const onNext = vi.fn()

    render(<Pagination page={3} totalPages={5} onPrevious={onPrevious} onNext={onNext} />)

    await user.click(screen.getByRole('button', { name: 'Previous' }))
    await user.click(screen.getByRole('button', { name: 'Next' }))

    expect(onPrevious).toHaveBeenCalledTimes(1)
    expect(onNext).toHaveBeenCalledTimes(1)
  })
})
