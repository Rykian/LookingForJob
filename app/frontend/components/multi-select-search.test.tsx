import { render, screen } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { describe, expect, it, vi } from 'vitest'
import { MultiSelectSearch } from './multi-select-search'

describe('MultiSelectSearch', () => {
  it('filters options from search input', async () => {
    const user = userEvent.setup()
    render(
      <MultiSelectSearch
        options={['Ruby', 'Rails', 'TypeScript']}
        value={[]}
        onChange={vi.fn()}
        placeholder="Search stack"
      />,
    )

    await user.type(screen.getByPlaceholderText('Search stack'), 'ra')

    expect(screen.getByText('Rails')).toBeInTheDocument()
    expect(screen.queryByText('TypeScript')).not.toBeInTheDocument()
  })

  it('calls onChange when selecting checkbox', async () => {
    const user = userEvent.setup()
    const onChange = vi.fn()

    render(<MultiSelectSearch options={['Ruby', 'Rails']} value={[]} onChange={onChange} />)

    await user.click(screen.getByRole('checkbox', { name: 'Ruby' }))

    expect(onChange).toHaveBeenCalledWith(['Ruby'])
  })

  it('calls onChange when removing selected chip', async () => {
    const user = userEvent.setup()
    const onChange = vi.fn()

    render(<MultiSelectSearch options={['Ruby', 'Rails']} value={['Ruby']} onChange={onChange} />)

    await user.click(screen.getByRole('button', { name: '×' }))

    expect(onChange).toHaveBeenCalledWith([])
  })
})
