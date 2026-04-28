import { renderHook } from '@testing-library/react'
import { describe, expect, it, vi } from 'vitest'
import { useJobOffersFilters } from './use-filters'

describe('useJobOffersFilters', () => {
  it('parses search params and builds query variables', () => {
    const searchParams = new URLSearchParams(
      'page=2&source=linkedin,wttj&technologies=ruby,react&sortBy=title&sortDirection=asc',
    )

    const { result } = renderHook(() =>
      useJobOffersFilters({
        searchParams,
        setSearchParams: vi.fn(),
      }),
    )

    expect(result.current.page).toBe(2)
    expect(result.current.selectedSources).toEqual(['linkedin', 'wttj'])
    expect(result.current.selectedTechnologies).toEqual(['ruby', 'react'])
    expect(result.current.variables.source).toBe('linkedin,wttj')
    expect(result.current.variables.technologies).toEqual(['ruby', 'react'])
    expect(result.current.variables.sortBy).toBe('title')
    expect(result.current.variables.sortDirection).toBe('asc')
  })

  it('resets all search params', () => {
    const setSearchParams = vi.fn()

    const { result } = renderHook(() =>
      useJobOffersFilters({
        searchParams: new URLSearchParams('page=4&source=linkedin'),
        setSearchParams,
      }),
    )

    result.current.resetSearchParams()

    expect(setSearchParams).toHaveBeenCalledWith(new URLSearchParams())
  })
})
