import { render, screen } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { describe, expect, it } from 'vitest'
import { Textarea } from './textarea'

describe('Textarea', () => {
  it('accepts typed value', async () => {
    const user = userEvent.setup()
    render(<Textarea placeholder="Notes" />)

    const textarea = screen.getByPlaceholderText('Notes')
    await user.type(textarea, 'hello world')

    expect(textarea).toHaveValue('hello world')
  })

  it('supports disabled state', () => {
    render(<Textarea placeholder="Disabled notes" disabled />)

    expect(screen.getByPlaceholderText('Disabled notes')).toBeDisabled()
  })
})
