import { act, renderHook } from '@testing-library/react'
import { describe, expect, it, vi } from 'vitest'
import { useMutationWithFeedback } from './use-mutation'

const mutateMock = vi.fn(async () => ({}))

vi.mock('@apollo/client/react', () => ({
  useMutation: vi.fn(() => [mutateMock, { loading: false, error: undefined, data: { ok: true } }]),
}))

describe('useMutationWithFeedback', () => {
  it('exposes loading/data and wraps mutation trigger', async () => {
    const { result } = renderHook(() => useMutationWithFeedback<{ ok: boolean }>({} as never))

    expect(result.current.loading).toBe(false)
    expect(result.current.error).toBe(false)
    expect(result.current.data).toEqual({ ok: true })

    await act(async () => {
      await result.current.trigger()
    })

    expect(mutateMock).toHaveBeenCalledTimes(1)
  })
})
