import { useEffect, useState } from 'react'

interface UseScoringProfileFormParams {
  initialProfile: unknown
  onSave: (profile: Record<string, unknown>) => Promise<void>
}

export function useScoringProfileForm({ initialProfile, onSave }: UseScoringProfileFormParams) {
  const [text, setText] = useState('')
  const [parseError, setParseError] = useState<string | null>(null)
  const [savedMessage, setSavedMessage] = useState('')

  useEffect(() => {
    if (initialProfile) {
      setText(JSON.stringify(initialProfile, null, 2))
    }
  }, [initialProfile])

  const handleSave = async () => {
    setParseError(null)
    setSavedMessage('')

    try {
      const parsed = JSON.parse(text) as Record<string, unknown>
      await onSave(parsed)
      setSavedMessage('Scoring profile updated.')
    } catch {
      setParseError('Invalid JSON. Please fix parsing errors before saving.')
    }
  }

  return {
    text,
    setText,
    parseError,
    savedMessage,
    handleSave,
  }
}
