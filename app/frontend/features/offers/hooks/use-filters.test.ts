import { renderHook } from '@testing-library/react'
import { describe, expect, it, vi } from 'vitest'
import { LanguageLevelEnum } from '@/graphql/generated'
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

  it('parses language filter from search params', () => {
    const searchParams = new URLSearchParams('lang=en&langLevel=PROFESSIONAL')

    const { result } = renderHook(() =>
      useJobOffersFilters({
        searchParams,
        setSearchParams: vi.fn(),
      }),
    )

    expect(result.current.filterLanguage).toBe('en')
    expect(result.current.maxLanguageLevel).toBe(LanguageLevelEnum.Professional)
    expect(result.current.variables.language).toBe('en')
    expect(result.current.variables.maxLanguageLevel).toBe(LanguageLevelEnum.Professional)
  })

  it('ignores a language filter without a level', () => {
    const searchParams = new URLSearchParams('lang=en')

    const { result } = renderHook(() =>
      useJobOffersFilters({
        searchParams,
        setSearchParams: vi.fn(),
      }),
    )

    expect(result.current.variables.language).toBeUndefined()
    expect(result.current.variables.maxLanguageLevel).toBeUndefined()
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
