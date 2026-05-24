import { useMutation, useQuery } from '@apollo/client/react'
import { useState } from 'react'
import { Editor } from '@/features/profile/components/editor'
import { useScoringProfileForm } from '@/features/profile/hooks/use-form'
import {
  RELOAD_SCORING_PROFILE_MUTATION,
  SCORING_PROFILE_QUERY,
  UPDATE_SCORING_PROFILE_MUTATION,
} from '@/features/profile/queries/documents'
import type {
  ReloadScoringProfileMutation,
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
  const [reload, { loading: reloading, error: reloadError }] =
    useMutation<ReloadScoringProfileMutation>(RELOAD_SCORING_PROFILE_MUTATION, {
      refetchQueries: [SCORING_PROFILE_QUERY],
      awaitRefetchQueries: true,
    })
  const [reloadedMessage, setReloadedMessage] = useState('')

  const { text, setText, parseError, savedMessage, handleSave } = useScoringProfileForm({
    initialProfile: data?.scoringProfile,
    onSave: async (profile) => {
      await save({ variables: { profile } })
    },
  })

  const handleReload = async () => {
    setReloadedMessage('')
    await reload()
    setReloadedMessage('Profile reloaded from file.')
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

      <Editor
        text={text}
        saving={saving}
        reloading={reloading}
        parseError={parseError}
        saveError={Boolean(saveError)}
        reloadError={Boolean(reloadError)}
        savedMessage={savedMessage}
        reloadedMessage={reloadedMessage}
        onTextChange={setText}
        onSave={handleSave}
        onReload={handleReload}
      />
    </div>
  )
}
