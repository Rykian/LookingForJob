import { useMutation } from '@apollo/client/react'
import type { DocumentNode } from 'graphql'

interface UseMutationWithFeedbackResult<TData> {
  trigger: () => Promise<void>
  loading: boolean
  error: boolean
  data: TData | null | undefined
}

export function useMutationWithFeedback<TData>(
  mutation: DocumentNode,
): UseMutationWithFeedbackResult<TData> {
  const [mutate, { loading, error, data }] = useMutation<TData>(mutation)

  const trigger = async () => {
    await mutate()
  }

  return {
    trigger,
    loading,
    error: Boolean(error),
    data,
  }
}
