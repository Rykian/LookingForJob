import { gql } from '@apollo/client'
import { useQuery } from '@apollo/client/react'
import { ExternalLink } from 'lucide-react'
import { useParams } from 'react-router'
import { Badge } from '@/components/ui/badge'
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card'
import type { JobOfferQuery, JobOfferQueryVariables } from '@/graphql/generated'

const JOB_OFFER_QUERY = gql`
  query JobOffer($id: ID!) {
    jobOffer(id: $id) {
      id
      title
      company
      source
      url
      city
      remote
      employmentType
      normalizedSeniority
      offerLanguage
      englishLevelRequired
      score
      scoreBreakdown
      primaryTechnologies
      secondaryTechnologies
      descriptionHtml
      firstSeenAt
      lastSeenAt
    }
  }
`

export default function OfferDetailPage() {
  const { id } = useParams()
  const { data, loading, error } = useQuery<JobOfferQuery, JobOfferQueryVariables>(
    JOB_OFFER_QUERY,
    {
      variables: { id: id ?? '' },
      skip: !id,
    },
  )

  if (!id) {
    return <div className="p-8 text-destructive">Missing offer id.</div>
  }

  if (loading) {
    return <div className="p-8 text-muted-foreground">Loading offer...</div>
  }

  if (error || !data?.jobOffer) {
    return <div className="p-8 text-destructive">Failed to load offer details.</div>
  }

  const offer = data.jobOffer

  return (
    <div className="space-y-6 p-8">
      <div>
        <h1 className="text-2xl font-semibold flex items-center gap-2">
          {offer.title || `Offer #${offer.id}`}
          <a
            className="text-primary underline-offset-4 hover:underline"
            href={offer.url}
            target="_blank"
            rel="noreferrer"
          >
            <ExternalLink className="h-4 w-4 inline-block" />
          </a>
        </h1>
        <p className="mt-1 text-sm text-muted-foreground">
          {offer.company || 'Unknown company'} · {offer.source}
        </p>
      </div>

      <Card>
        <CardHeader>
          <CardTitle className="text-lg">Summary</CardTitle>
        </CardHeader>
        <CardContent className="space-y-3 text-sm">
          <div className="flex flex-wrap gap-2">
            <Badge variant="outline">{offer.remote || 'unknown mode'}</Badge>
            <Badge variant="outline">{offer.employmentType || 'unknown type'}</Badge>
            <Badge variant="outline">{offer.normalizedSeniority || 'unknown seniority'}</Badge>
            <Badge variant="outline">score: {offer.score ?? '-'}</Badge>
          </div>
          <p>
            <span className="font-medium">City:</span> {offer.city || '-'}
          </p>
          <p>
            <span className="font-medium">Language:</span> {offer.offerLanguage || '-'}
          </p>
          <p>
            <span className="font-medium">English level:</span> {offer.englishLevelRequired || '-'}
          </p>
          <p>
            <span className="font-medium">Seen:</span>{' '}
            {new Date(offer.firstSeenAt).toLocaleString()} →{' '}
            {new Date(offer.lastSeenAt).toLocaleString()}
          </p>
        </CardContent>
      </Card>

      <div className="grid grid-cols-1 gap-6 lg:grid-cols-2">
        <Card>
          <CardHeader>
            <CardTitle className="text-lg">Technologies</CardTitle>
          </CardHeader>
          <CardContent className="space-y-4 text-sm">
            <div>
              <p className="mb-2 font-medium">Primary</p>
              <div className="flex flex-wrap gap-2">
                {(offer.primaryTechnologies || []).map((tech) => (
                  <Badge key={`p-${tech}`} variant="secondary">
                    {tech}
                  </Badge>
                ))}
                {(offer.primaryTechnologies || []).length === 0 ? (
                  <span className="text-muted-foreground">-</span>
                ) : null}
              </div>
            </div>

            <div>
              <p className="mb-2 font-medium">Secondary</p>
              <div className="flex flex-wrap gap-2">
                {(offer.secondaryTechnologies || []).map((tech) => (
                  <Badge key={`s-${tech}`} variant="outline">
                    {tech}
                  </Badge>
                ))}
                {(offer.secondaryTechnologies || []).length === 0 ? (
                  <span className="text-muted-foreground">-</span>
                ) : null}
              </div>
            </div>
          </CardContent>
        </Card>

        <Card>
          <CardHeader>
            <CardTitle className="text-lg">Score Breakdown</CardTitle>
          </CardHeader>
          <CardContent>
            <pre className="max-h-[420px] overflow-auto rounded-md bg-muted p-3 text-xs leading-5">
              {JSON.stringify(offer.scoreBreakdown || {}, null, 2)}
            </pre>
          </CardContent>
        </Card>
      </div>

      <Card>
        <CardHeader>
          <CardTitle className="text-lg">Description</CardTitle>
        </CardHeader>
        <CardContent>
          <div
            className="prose prose-sm max-w-none"
            // biome-ignore lint/security/noDangerouslySetInnerHtml: As it was in the job board
            dangerouslySetInnerHTML={{
              __html: offer.descriptionHtml || '<p>No description available.</p>',
            }}
          />
        </CardContent>
      </Card>
    </div>
  )
}
