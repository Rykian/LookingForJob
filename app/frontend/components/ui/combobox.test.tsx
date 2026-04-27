import { render, screen } from '@testing-library/react'
import { describe, expect, it } from 'vitest'
import { Combobox, ComboboxChips, ComboboxChipsInput, ComboboxValue } from './combobox'

describe('Combobox', () => {
  it('renders chips input inside combobox root', () => {
    render(
      <Combobox multiple items={['ruby', 'rails']}>
        <ComboboxChips>
          <ComboboxValue>{[]}</ComboboxValue>
          <ComboboxChipsInput placeholder="Filter tech" />
        </ComboboxChips>
      </Combobox>,
    )

    expect(screen.getByPlaceholderText('Filter tech')).toBeInTheDocument()
  })
})
