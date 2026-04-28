import { act, renderHook } from '@testing-library/react'
import { describe, expect, it, vi } from 'vitest'
import { useScoringProfileForm } from './use-form'

describe('useScoringProfileForm', () => {
  it('hydrates text from initial profile', () => {
    const { result } = renderHook(() =>
      useScoringProfileForm({
        initialProfile: { version: 'v1' },
        onSave: vi.fn(async () => {}),
      }),
    )

    expect(result.current.text).toContain('"version": "v1"')
  })

  it('sets parse error when JSON is invalid', async () => {
    const { result } = renderHook(() =>
      useScoringProfileForm({
        initialProfile: null,
        onSave: vi.fn(async () => {}),
      }),
    )

    act(() => {
      result.current.setText('{invalid-json')
    })

    await act(async () => {
      await result.current.handleSave()
    })

    expect(result.current.parseError).toBe('Invalid JSON. Please fix parsing errors before saving.')
  })

  it('calls onSave with parsed JSON and shows success message', async () => {
    const onSave = vi.fn(async () => {})

    const { result } = renderHook(() =>
      useScoringProfileForm({
        initialProfile: null,
        onSave,
      }),
    )

    act(() => {
      result.current.setText('{"weights":{"stack":0.5}}')
    })

    await act(async () => {
      await result.current.handleSave()
    })

    expect(onSave).toHaveBeenCalledWith({ weights: { stack: 0.5 } })
    expect(result.current.savedMessage).toBe('Scoring profile updated.')
    expect(result.current.parseError).toBeNull()
  })
})
