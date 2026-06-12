import { describe, expect, it, vi } from 'vitest'
import { isOneOf, parsePage, useUrlParams } from './url-params'

describe('isOneOf', () => {
  const VALUES = ['foo', 'bar', 'baz'] as const

  it('returns true for a value in the list', () => {
    expect(isOneOf('foo', VALUES)).toBe(true)
  })

  it('returns false for a value not in the list', () => {
    expect(isOneOf('qux', VALUES)).toBe(false)
  })

  it('returns false for empty string', () => {
    expect(isOneOf('', VALUES)).toBe(false)
  })
})

describe('parsePage', () => {
  it('parses a valid page number', () => {
    expect(parsePage(new URLSearchParams('page=3'))).toBe(3)
  })

  it('defaults to 1 when param is missing', () => {
    expect(parsePage(new URLSearchParams())).toBe(1)
  })

  it('defaults to 1 for zero', () => {
    expect(parsePage(new URLSearchParams('page=0'))).toBe(1)
  })

  it('defaults to 1 for negative value', () => {
    expect(parsePage(new URLSearchParams('page=-5'))).toBe(1)
  })

  it('defaults to 1 for non-numeric value', () => {
    expect(parsePage(new URLSearchParams('page=abc'))).toBe(1)
  })
})

describe('useUrlParams', () => {
  it('sets a param', () => {
    const setSearchParams = vi.fn()
    const { update } = useUrlParams(new URLSearchParams(), setSearchParams)

    update({ foo: 'bar' })

    const next = setSearchParams.mock.calls[0][0] as URLSearchParams
    expect(next.get('foo')).toBe('bar')
  })

  it('deletes a param when value is null', () => {
    const setSearchParams = vi.fn()
    const { update } = useUrlParams(new URLSearchParams('foo=bar'), setSearchParams)

    update({ foo: null })

    const next = setSearchParams.mock.calls[0][0] as URLSearchParams
    expect(next.has('foo')).toBe(false)
  })

  it('preserves existing params not in the update', () => {
    const setSearchParams = vi.fn()
    const { update } = useUrlParams(new URLSearchParams('existing=keep'), setSearchParams)

    update({ foo: 'bar' })

    const next = setSearchParams.mock.calls[0][0] as URLSearchParams
    expect(next.get('existing')).toBe('keep')
    expect(next.get('foo')).toBe('bar')
  })

  it('calls setSearchParams with preventScrollReset', () => {
    const setSearchParams = vi.fn()
    const { update } = useUrlParams(new URLSearchParams(), setSearchParams)

    update({ foo: 'bar' })

    expect(setSearchParams).toHaveBeenCalledWith(expect.any(URLSearchParams), {
      preventScrollReset: true,
    })
  })

  it('reset clears all params', () => {
    const setSearchParams = vi.fn()
    const { reset } = useUrlParams(new URLSearchParams('foo=bar&page=2'), setSearchParams)

    reset()

    expect(setSearchParams).toHaveBeenCalledWith(new URLSearchParams())
  })
})
