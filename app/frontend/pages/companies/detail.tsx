import { useMutation, useQuery } from '@apollo/client/react'
import { ExternalLink, Pencil } from 'lucide-react'
import { useState } from 'react'
import { Link, useParams } from 'react-router'
import { Badge } from '@/components/ui/badge'
import { Button } from '@/components/ui/button'
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card'
import { Input } from '@/components/ui/input'
import { AliasesEditor } from '@/features/companies/components/aliases-editor'
import { COMPANY_QUERY, RENAME_COMPANY_MUTATION } from '@/features/companies/queries/documents'
import { JOB_OFFERS_QUERY } from '@/features/offers/queries/documents'
import type {
  CompanyQuery,
  CompanyQueryVariables,
  JobOffersQuery,
  JobOffersQueryVariables,
  RenameCompanyMutation,
  RenameCompanyMutationVariables,
} from '@/graphql/generated'
import { locale } from '@/lib/utils'

export default function CompanyDetailPage() {
  const { id } = useParams()
  const [editingName, setEditingName] = useState(false)
  const [nameInput, setNameInput] = useState('')

  const { data, loading, error } = useQuery<CompanyQuery, CompanyQueryVariables>(COMPANY_QUERY, {
    variables: { id: id ?? '' },
    skip: !id,
  })

  const { data: offersData, loading: offersLoading } = useQuery<
    JobOffersQuery,
    JobOffersQueryVariables
  >(JOB_OFFERS_QUERY, {
    variables: { page: 1, perPage: 50, companyId: id ?? '', sortBy: 'first_seen_at' },
    skip: !id,
  })

  const [renameCompany, { loading: renaming }] = useMutation<
    RenameCompanyMutation,
    RenameCompanyMutationVariables
  >(RENAME_COMPANY_MUTATION)

  if (!id) {
    return <div className="p-8 text-destructive">Missing company id.</div>
  }

  if (loading) {
    return <div className="p-8 text-muted-foreground">Loading company...</div>
  }

  if (error || !data?.company) {
    return <div className="p-8 text-destructive">Failed to load company details.</div>
  }

  const company = data.company
  const offers = offersData?.jobOffers.nodes ?? []

  const submitRename = async () => {
    const name = nameInput.trim()
    if (name && name !== company.name) {
      await renameCompany({ variables: { companyId: company.id, name } })
    }
    setEditingName(false)
  }

  return (
    <div className="space-y-6 p-8">
      <div>
        {editingName ? (
          <div className="flex items-center gap-2">
            <Input
              className="max-w-xs"
              value={nameInput}
              onChange={(e) => setNameInput(e.target.value)}
            />
            <Button size="sm" disabled={renaming} onClick={submitRename}>
              Save
            </Button>
            <Button variant="outline" size="sm" onClick={() => setEditingName(false)}>
              Cancel
            </Button>
          </div>
        ) : (
          <h1 className="text-2xl font-semibold flex items-center gap-2">
            {company.name}
            <button
              type="button"
              aria-label="Rename company"
              className="text-muted-foreground hover:text-foreground"
              onClick={() => {
                setNameInput(company.name)
                setEditingName(true)
              }}
            >
              <Pencil className="h-4 w-4" />
            </button>
            {company.website ? (
              <a
                className="text-primary underline-offset-4 hover:underline"
                href={company.website}
                target="_blank"
                rel="noreferrer"
              >
                <ExternalLink className="h-4 w-4 inline-block" />
              </a>
            ) : null}
          </h1>
        )}
        <div className="mt-2 flex flex-wrap gap-2">
          {company.postsAsRecruiter ? <Badge variant="outline">Recruiter</Badge> : null}
          {company.postsAsFinalClient ? <Badge variant="secondary">Final client</Badge> : null}
          <Badge variant="outline">{company.offerCount} offers</Badge>
          {company.finalClientOfferCount > 0 ? (
            <Badge variant="outline">{company.finalClientOfferCount} as final client</Badge>
          ) : null}
        </div>
      </div>

      <div className="grid grid-cols-1 gap-6 lg:grid-cols-2">
        <Card>
          <CardHeader>
            <CardTitle className="text-lg">About</CardTitle>
          </CardHeader>
          <CardContent className="space-y-3 text-sm">
            <p>{company.description || 'No description yet.'}</p>
            {company.website ? (
              <p>
                <span className="font-medium">Website:</span>{' '}
                <a
                  className="text-primary hover:underline"
                  href={company.website}
                  target="_blank"
                  rel="noreferrer"
                >
                  {company.website}
                </a>
              </p>
            ) : null}
          </CardContent>
        </Card>

        <Card>
          <CardHeader>
            <CardTitle className="text-lg">Technologies</CardTitle>
          </CardHeader>
          <CardContent>
            <div className="flex flex-wrap gap-2">
              {company.topTechnologies.map((tech) => (
                <Badge key={tech} variant="secondary">
                  {tech}
                </Badge>
              ))}
              {company.topTechnologies.length === 0 ? (
                <span className="text-sm text-muted-foreground">
                  No technologies from final-client offers yet.
                </span>
              ) : null}
            </div>
          </CardContent>
        </Card>
      </div>

      <AliasesEditor company={company} />

      <Card>
        <CardHeader>
          <CardTitle className="text-lg">
            {offersLoading
              ? 'Loading offers...'
              : `${offersData?.jobOffers.totalCount ?? 0} offers`}
          </CardTitle>
        </CardHeader>
        <CardContent>
          {offers.length === 0 && !offersLoading ? (
            <p className="text-sm text-muted-foreground">No offers linked to this company.</p>
          ) : (
            <div className="overflow-x-auto">
              <table className="w-full min-w-160 text-left text-sm">
                <thead>
                  <tr className="border-b text-muted-foreground">
                    <th className="px-3 py-2 font-medium">Title</th>
                    <th className="px-3 py-2 font-medium">Source</th>
                    <th className="px-3 py-2 font-medium">Location</th>
                    <th className="px-3 py-2 font-medium">Score</th>
                    <th className="px-3 py-2 font-medium">Seen</th>
                  </tr>
                </thead>
                <tbody>
                  {offers.map((offer) => (
                    <tr key={offer.id} className="border-b last:border-0">
                      <td className="px-3 py-2 font-medium">
                        <Link
                          className="text-primary visited:text-muted-foreground hover:underline"
                          to={`/offers/${offer.id}`}
                        >
                          {offer.title || 'Untitled role'}
                        </Link>
                      </td>
                      <td className="px-3 py-2">{offer.source}</td>
                      <td className="px-3 py-2">{offer.city || '-'}</td>
                      <td className="px-3 py-2">{offer.score ?? '-'}</td>
                      <td className="px-3 py-2">
                        {new Date(offer.firstSeenAt).toLocaleDateString(locale)}
                      </td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          )}
        </CardContent>
      </Card>
    </div>
  )
}
