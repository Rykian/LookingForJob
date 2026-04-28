import { Button } from '@/components/ui/button'
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from '@/components/ui/card'

interface ActionCardProps {
  title: string
  description: string
  actionLabel: string
  pendingLabel: string
  loading: boolean
  error: boolean
  successMessage?: string | null
  errorMessage: string
  onTrigger: () => void
}

export function ActionCard({
  title,
  description,
  actionLabel,
  pendingLabel,
  loading,
  error,
  successMessage,
  errorMessage,
  onTrigger,
}: ActionCardProps) {
  return (
    <Card className="max-w-2xl">
      <CardHeader>
        <CardTitle>{title}</CardTitle>
        <CardDescription>{description}</CardDescription>
      </CardHeader>
      <CardContent className="space-y-3">
        <Button disabled={loading} onClick={onTrigger}>
          {loading ? pendingLabel : actionLabel}
        </Button>

        {successMessage ? <p className="text-sm text-green-700">{successMessage}</p> : null}
        {error ? <p className="text-sm text-destructive">{errorMessage}</p> : null}
      </CardContent>
    </Card>
  )
}
