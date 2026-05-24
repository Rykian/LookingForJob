import { Button } from '@/components/ui/button'
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card'

interface EditorProps {
  text: string
  saving: boolean
  reloading: boolean
  parseError: string | null
  saveError: boolean
  reloadError: boolean
  savedMessage: string
  reloadedMessage: string
  onTextChange: (value: string) => void
  onSave: () => void
  onReload: () => void
}

export function Editor({
  text,
  saving,
  reloading,
  parseError,
  saveError,
  reloadError,
  savedMessage,
  reloadedMessage,
  onTextChange,
  onSave,
  onReload,
}: EditorProps) {
  return (
    <Card>
      <CardHeader>
        <CardTitle>Profile JSON</CardTitle>
      </CardHeader>
      <CardContent className="space-y-3">
        <textarea
          className="min-h-[520px] w-full rounded-md border bg-background p-3 font-mono text-xs leading-5"
          value={text}
          onChange={(event) => onTextChange(event.target.value)}
        />

        <div className="flex items-center gap-3">
          <Button disabled={saving} onClick={onSave}>
            {saving ? 'Saving...' : 'Save Profile'}
          </Button>
          <Button disabled={reloading} onClick={onReload} variant="outline">
            {reloading ? 'Reloading...' : 'Reload from file'}
          </Button>
          {savedMessage ? <span className="text-sm text-green-700">{savedMessage}</span> : null}
          {reloadedMessage ? (
            <span className="text-sm text-green-700">{reloadedMessage}</span>
          ) : null}
        </div>

        {parseError ? <p className="text-sm text-destructive">{parseError}</p> : null}
        {saveError ? (
          <p className="text-sm text-destructive">Failed to save scoring profile.</p>
        ) : null}
        {reloadError ? (
          <p className="text-sm text-destructive">Failed to reload scoring profile.</p>
        ) : null}
      </CardContent>
    </Card>
  )
}
