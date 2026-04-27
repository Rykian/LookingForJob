import { render, screen } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { describe, expect, it } from 'vitest'
import { Input } from './input'

describe('Input', () => {
  it('accepts typed value', async () => {
    const user = userEvent.setup()
    render(<Input placeholder="Search" />)

    const input = screen.getByPlaceholderText('Search')
    await user.type(input, 'rails')

    expect(input).toHaveValue('rails')
  })

  it('supports disabled state', () => {
    render(<Input placeholder="Disabled" disabled />)

    expect(screen.getByPlaceholderText('Disabled')).toBeDisabled()
  })
})
