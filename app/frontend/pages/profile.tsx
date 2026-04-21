import { useEffect, useState } from 'react'
import { gql } from '@apollo/client'
import { useMutation, useQuery } from '@apollo/client/react'
import { Button } from '@/components/ui/button'
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card'
import {
  ScoringProfileQuery,
  UpdateScoringProfileMutation,
  UpdateScoringProfileMutationVariables,
} from '@/graphql/generated'

const SCORING_PROFILE_QUERY = gql`
  query ScoringProfile {
    scoringProfile
  }
`

const UPDATE_SCORING_PROFILE_MUTATION = gql`
  mutation UpdateScoringProfile($profile: JSON!) {
    updateScoringProfile(input: { profile: $profile }) {
      profile
    }
  }
`

export default function ProfilePage() {
  const { data, loading, error } = useQuery<ScoringProfileQuery>(SCORING_PROFILE_QUERY)
  const [save, { loading: saving, error: saveError }] = useMutation<
    UpdateScoringProfileMutation,
    UpdateScoringProfileMutationVariables
  >(UPDATE_SCORING_PROFILE_MUTATION, {
    refetchQueries: [SCORING_PROFILE_QUERY],
    awaitRefetchQueries: true,
  })
  const [text, setText] = useState('')
  const [parseError, setParseError] = useState<string | null>(null)
  const [savedMessage, setSavedMessage] = useState('')

  useEffect(() => {
    if (data?.scoringProfile) {
      setText(JSON.stringify(data.scoringProfile, null, 2))
    }
  }, [data])

  const handleSave = async () => {
    setParseError(null)
    setSavedMessage('')
    try {
      const parsed = JSON.parse(text) as Record<string, unknown>
      await save({ variables: { profile: parsed } })
      setSavedMessage('Scoring profile updated.')
    } catch {
      setParseError('Invalid JSON. Please fix parsing errors before saving.')
    }
  }

  if (loading) {
    return <div className="p-8 text-muted-foreground">Loading profile...</div>
  }

  if (error) {
    return <div className="p-8 text-destructive">Failed to load scoring profile.</div>
  }

  return (
    <div className="space-y-6 p-8">
      <div>
        <h1 className="text-2xl font-semibold">Scoring Profile</h1>
        <p className="mt-1 text-sm text-muted-foreground">
          Edit the file-backed JSON scoring profile (v1).
        </p>
      </div>

      <Card>
        <CardHeader>
          <CardTitle>Profile JSON</CardTitle>
        </CardHeader>
        <CardContent className="space-y-3">
          <textarea
            className="min-h-[520px] w-full rounded-md border bg-background p-3 font-mono text-xs leading-5"
            value={text}
            onChange={(event) => setText(event.target.value)}
          />

          <div className="flex items-center gap-3">
            <Button disabled={saving} onClick={handleSave}>
              {saving ? 'Saving...' : 'Save Profile'}
            </Button>
            {savedMessage ? <span className="text-sm text-green-700">{savedMessage}</span> : null}
          </div>

          {parseError ? <p className="text-sm text-destructive">{parseError}</p> : null}
          {saveError ? (
            <p className="text-sm text-destructive">Failed to save scoring profile.</p>
          ) : null}
        </CardContent>
      </Card>
    </div>
  )
}
