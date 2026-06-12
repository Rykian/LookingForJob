import { useApolloClient, useMutation } from '@apollo/client/react'
import { useEffect, useState } from 'react'
import {
  COMPANIES_QUERY,
  SET_OFFER_FINAL_CLIENT_MUTATION,
} from '@/features/companies/queries/documents'
import type {
  CompaniesQuery,
  CompaniesQueryVariables,
  SetOfferFinalClientMutation,
  SetOfferFinalClientMutationVariables,
} from '@/graphql/generated'

export interface CompanySuggestion {
  id: string
  name: string
}

export function useFinalClient(offerId: string) {
  const client = useApolloClient()
  const [input, setInput] = useState('')
  const [suggestions, setSuggestions] = useState<CompanySuggestion[]>([])
  const [setFinalClient, { loading }] = useMutation<
    SetOfferFinalClientMutation,
    SetOfferFinalClientMutationVariables
  >(SET_OFFER_FINAL_CLIENT_MUTATION)

  useEffect(() => {
    if (input.trim().length < 2) {
      setSuggestions([])
      return
    }

    const handle = setTimeout(async () => {
      const { data } = await client.query<CompaniesQuery, CompaniesQueryVariables>({
        query: COMPANIES_QUERY,
        variables: { page: 1, perPage: 8, search: input.trim() },
      })
      setSuggestions(data?.companies.nodes.map(({ id, name }) => ({ id, name })) ?? [])
    }, 300)
    return () => clearTimeout(handle)
  }, [input, client])

  const pick = async (companyName: string | null) => {
    await setFinalClient({ variables: { offerId, companyName } })
    setInput('')
    setSuggestions([])
  }

  return { input, setInput, suggestions, pick, loading }
}
