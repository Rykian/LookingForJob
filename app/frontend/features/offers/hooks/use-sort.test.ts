import { renderHook } from '@testing-library/react'
import { describe, expect, it, vi } from 'vitest'
import { useJobOffersSort } from './use-sort'

describe('useJobOffersSort', () => {
  it('toggles direction when sorting the same column', () => {
    const updateSearchParams = vi.fn()

    const { result } = renderHook(() =>
      useJobOffersSort({
        sortBy: 'company',
        sortDirection: 'asc',
        updateSearchParams,
      }),
    )

    result.current.toggleSort('company')

    expect(updateSearchParams).toHaveBeenCalledWith({
      page: null,
      sortDirection: 'desc',
    })
  })

  it('resets direction when selecting a different column', () => {
    const updateSearchParams = vi.fn()

    const { result } = renderHook(() =>
      useJobOffersSort({
        sortBy: 'score',
        sortDirection: 'desc',
        updateSearchParams,
      }),
    )

    result.current.toggleSort('title')

    expect(updateSearchParams).toHaveBeenCalledWith({
      page: null,
      sortBy: 'title',
      sortDirection: null,
    })
  })

  it('returns sort indicator arrows for active and inactive columns', () => {
    const { result } = renderHook(() =>
      useJobOffersSort({
        sortBy: 'title',
        sortDirection: 'desc',
        updateSearchParams: vi.fn(),
      }),
    )

    expect(result.current.sortIndicator('title')).toBe('↓')
    expect(result.current.sortIndicator('company')).toBe('↕')
  })
})
