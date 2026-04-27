import { render, screen } from '@testing-library/react'
import { describe, expect, it } from 'vitest'
import {
  InputGroup,
  InputGroupAddon,
  InputGroupButton,
  InputGroupInput,
  InputGroupText,
} from './input-group'

describe('InputGroup', () => {
  it('renders addon, input and action button', () => {
    const { container } = render(
      <InputGroup>
        <InputGroupAddon>
          <InputGroupText>@</InputGroupText>
        </InputGroupAddon>
        <InputGroupInput placeholder="username" />
        <InputGroupAddon align="inline-end">
          <InputGroupButton aria-label="clear">x</InputGroupButton>
        </InputGroupAddon>
      </InputGroup>,
    )

    expect(container.querySelector('[data-slot="input-group"]')).toBeInTheDocument()
    expect(screen.getByPlaceholderText('username')).toBeInTheDocument()
    expect(screen.getByRole('button', { name: 'clear' })).toBeInTheDocument()
  })
})
