import { useMutation, useQuery } from '@apollo/client/react'
import { Editor } from '@/features/profile/components/editor'
import { useScoringProfileForm } from '@/features/profile/hooks/use-form'
import {
  SCORING_PROFILE_QUERY,
  UPDATE_SCORING_PROFILE_MUTATION,
} from '@/features/profile/queries/documents'
import type {
  ScoringProfileQuery,
  UpdateScoringProfileMutation,
  UpdateScoringProfileMutationVariables,
} from '@/graphql/generated'

export default function ProfilePage() {
  const { data, loading, error } = useQuery<ScoringProfileQuery>(SCORING_PROFILE_QUERY)
  const [save, { loading: saving, error: saveError }] = useMutation<
    UpdateScoringProfileMutation,
    UpdateScoringProfileMutationVariables
  >(UPDATE_SCORING_PROFILE_MUTATION, {
    refetchQueries: [SCORING_PROFILE_QUERY],
    awaitRefetchQueries: true,
  })

  const { text, setText, parseError, savedMessage, handleSave } = useScoringProfileForm({
    initialProfile: data?.scoringProfile,
    onSave: async (profile) => {
      await save({ variables: { profile } })
    },
  })

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

      <Editor
        text={text}
        saving={saving}
        parseError={parseError}
        saveError={Boolean(saveError)}
        savedMessage={savedMessage}
        onTextChange={setText}
        onSave={handleSave}
      />
    </div>
  )
}
