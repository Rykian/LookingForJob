type SetSearchParams = (
  next: URLSearchParams,
  options?: { replace?: boolean; preventScrollReset?: boolean },
) => void

export function isOneOf<T extends readonly string[]>(value: string, values: T): value is T[number] {
  return values.includes(value)
}

export function parsePage(searchParams: URLSearchParams): number {
  const param = Number.parseInt(searchParams.get('page') ?? '1', 10)
  return Number.isFinite(param) && param > 0 ? param : 1
}

export function useUrlParams(searchParams: URLSearchParams, setSearchParams: SetSearchParams) {
  const update = (updates: Record<string, string | null>) => {
    const next = new URLSearchParams(searchParams)
    for (const [key, value] of Object.entries(updates)) {
      if (!value) {
        next.delete(key)
      } else {
        next.set(key, value)
      }
    }
    setSearchParams(next, { preventScrollReset: true })
  }

  const reset = () => setSearchParams(new URLSearchParams())

  return { update, reset }
}
