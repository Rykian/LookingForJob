import { useApolloClient, useMutation } from '@apollo/client/react'
import { Plus, X } from 'lucide-react'
import { useEffect, useState } from 'react'
import { Badge } from '@/components/ui/badge'
import { Button } from '@/components/ui/button'
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card'
import { Input } from '@/components/ui/input'
import type {
  AddCompanyAliasMutation,
  AddCompanyAliasMutationVariables,
  CompanyAliasPreviewQuery,
  CompanyAliasPreviewQueryVariables,
  CompanyNameSuggestionsQuery,
  CompanyNameSuggestionsQueryVariables,
  CompanyQuery,
  RemoveCompanyAliasMutation,
  RemoveCompanyAliasMutationVariables,
} from '@/graphql/generated'
import {
  ADD_COMPANY_ALIAS_MUTATION,
  COMPANY_ALIAS_PREVIEW_QUERY,
  COMPANY_NAME_SUGGESTIONS_QUERY,
  COMPANY_QUERY,
  REMOVE_COMPANY_ALIAS_MUTATION,
} from '../queries/documents'

type Company = NonNullable<CompanyQuery['company']>
type Preview = CompanyAliasPreviewQuery['companyAliasPreview']

interface PendingAction {
  kind: 'add' | 'remove'
  name: string
  aliasId?: string
  preview: Preview
}

interface AliasesEditorProps {
  company: Company
}

export function AliasesEditor({ company }: AliasesEditorProps) {
  const client = useApolloClient()
  const [input, setInput] = useState('')
  const [suggestions, setSuggestions] = useState<string[]>([])
  const [pending, setPending] = useState<PendingAction | null>(null)
  const [errorMessage, setErrorMessage] = useState<string | null>(null)

  const refetchCompany = {
    refetchQueries: [{ query: COMPANY_QUERY, variables: { id: company.id } }],
  }
  const [addAlias, { loading: adding }] = useMutation<
    AddCompanyAliasMutation,
    AddCompanyAliasMutationVariables
  >(ADD_COMPANY_ALIAS_MUTATION, refetchCompany)
  const [removeAlias, { loading: removing }] = useMutation<
    RemoveCompanyAliasMutation,
    RemoveCompanyAliasMutationVariables
  >(REMOVE_COMPANY_ALIAS_MUTATION, refetchCompany)

  useEffect(() => {
    if (input.trim().length < 2) {
      setSuggestions([])
      return
    }

    const handle = setTimeout(async () => {
      const { data } = await client.query<
        CompanyNameSuggestionsQuery,
        CompanyNameSuggestionsQueryVariables
      >({
        query: COMPANY_NAME_SUGGESTIONS_QUERY,
        variables: { search: input.trim(), excludeCompanyId: company.id },
      })
      setSuggestions(data?.companyNameSuggestions ?? [])
    }, 300)
    return () => clearTimeout(handle)
  }, [input, company.id, client])

  const requestPreview = async (name: string): Promise<Preview | null> => {
    const { data } = await client.query<
      CompanyAliasPreviewQuery,
      CompanyAliasPreviewQueryVariables
    >({
      query: COMPANY_ALIAS_PREVIEW_QUERY,
      variables: { name },
      fetchPolicy: 'network-only',
    })
    return data?.companyAliasPreview ?? null
  }

  const startAdd = async (name: string) => {
    setErrorMessage(null)
    const preview = await requestPreview(name)
    if (!preview) return
    setPending({ kind: 'add', name, preview })
  }

  const startRemove = async (aliasId: string, name: string) => {
    setErrorMessage(null)
    const preview = await requestPreview(name)
    if (!preview) return
    setPending({ kind: 'remove', name, aliasId, preview })
  }

  const confirmPending = async () => {
    if (!pending) return

    try {
      if (pending.kind === 'add') {
        await addAlias({ variables: { companyId: company.id, name: pending.name } })
        setInput('')
        setSuggestions([])
      } else if (pending.aliasId) {
        await removeAlias({ variables: { aliasId: pending.aliasId } })
      }
      setPending(null)
    } catch (e) {
      setPending(null)
      setErrorMessage(e instanceof Error ? e.message : 'Operation failed.')
    }
  }

  const isOfficialAlias = (aliasName: string) =>
    aliasName.trim().toLowerCase() === company.name.trim().toLowerCase()

  return (
    <Card>
      <CardHeader>
        <CardTitle className="text-lg">Accepted names</CardTitle>
      </CardHeader>
      <CardContent className="space-y-4 text-sm">
        <div className="flex flex-wrap gap-2">
          {company.aliases.map((alias) => (
            <Badge key={alias.id} variant="secondary" className="gap-1">
              {alias.name}
              {!isOfficialAlias(alias.name) ? (
                <button
                  type="button"
                  aria-label={`Remove ${alias.name}`}
                  className="rounded hover:text-destructive"
                  onClick={() => startRemove(alias.id, alias.name)}
                >
                  <X className="h-3 w-3" />
                </button>
              ) : null}
            </Badge>
          ))}
        </div>

        <div className="space-y-2">
          <div className="flex items-center gap-2">
            <Input
              className="max-w-xs"
              placeholder="Add an accepted name..."
              value={input}
              onChange={(e) => setInput(e.target.value)}
            />
            <Button
              variant="outline"
              size="sm"
              disabled={!input.trim() || adding}
              onClick={() => startAdd(input.trim())}
            >
              <Plus className="h-4 w-4" /> Add
            </Button>
          </div>

          {suggestions.length > 0 ? (
            <div className="flex flex-wrap gap-1.5">
              {suggestions.map((name) => (
                <button key={name} type="button" onClick={() => startAdd(name)}>
                  <Badge variant="outline" className="hover:bg-muted">
                    {name}
                  </Badge>
                </button>
              ))}
            </div>
          ) : null}
        </div>

        {pending ? (
          <div className="space-y-2 rounded-md border border-border bg-muted/40 p-3">
            {pending.kind === 'add' ? (
              <p>
                {pending.preview.owningCompany && pending.preview.owningCompany.id !== company.id
                  ? `"${pending.name}" currently belongs to ${pending.preview.owningCompany.name}. Merging will move it here along with ${pending.preview.matchedOffersCount} matching offers.`
                  : `${pending.preview.matchedOffersCount} offers matching "${pending.name}" will be linked to ${company.name}.`}
              </p>
            ) : (
              <p>
                Removing "{pending.name}" will split it into a new company and move{' '}
                {pending.preview.matchedOffersCount} matching offers to it.
              </p>
            )}
            <div className="flex gap-2">
              <Button size="sm" disabled={adding || removing} onClick={confirmPending}>
                Confirm
              </Button>
              <Button variant="outline" size="sm" onClick={() => setPending(null)}>
                Cancel
              </Button>
            </div>
          </div>
        ) : null}

        {errorMessage ? <p className="text-destructive">{errorMessage}</p> : null}
      </CardContent>
    </Card>
  )
}
