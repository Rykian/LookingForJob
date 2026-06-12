import { Link } from 'react-router'
import { Badge } from '@/components/ui/badge'
import { Button } from '@/components/ui/button'
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card'
import { Input } from '@/components/ui/input'
import { type CompanySuggestion, useFinalClient } from '@/features/offers/hooks/use-final-client'
import type { JobOfferQuery } from '@/graphql/generated'

type Offer = NonNullable<JobOfferQuery['jobOffer']>

interface FinalClientGuess {
  name: string
  confidence: number
  reasons: string
}

interface FinalClientPickerViewProps {
  finalCompany: { id: string; name: string } | null
  guesses: FinalClientGuess[]
  loading: boolean
  input: string
  onInputChange: (value: string) => void
  suggestions: CompanySuggestion[]
  onPick: (companyName: string | null) => void
}

export function FinalClientPickerView({
  finalCompany,
  guesses,
  loading,
  input,
  onInputChange,
  suggestions,
  onPick,
}: FinalClientPickerViewProps) {
  return (
    <Card>
      <CardHeader>
        <CardTitle className="text-lg">Final client</CardTitle>
      </CardHeader>
      <CardContent className="space-y-4 text-sm">
        <div className="flex flex-wrap items-center gap-2">
          {finalCompany ? (
            <>
              <Link
                className="font-medium text-primary hover:underline"
                to={`/companies/${finalCompany.id}`}
              >
                {finalCompany.name}
              </Link>
              <Button variant="outline" size="sm" disabled={loading} onClick={() => onPick(null)}>
                Clear
              </Button>
            </>
          ) : (
            <span className="text-muted-foreground">No final client linked.</span>
          )}
        </div>

        {guesses.length > 0 ? (
          <div className="space-y-2">
            <p className="font-medium">Guesses</p>
            {guesses.map((guess) => (
              <div key={guess.name} className="flex items-start gap-2">
                <Button
                  variant={finalCompany?.name === guess.name ? 'default' : 'outline'}
                  size="sm"
                  disabled={loading}
                  onClick={() => onPick(guess.name)}
                >
                  {guess.name}
                </Button>
                <div className="min-w-0 pt-1">
                  <Badge variant="secondary">{Math.round(guess.confidence * 100)}%</Badge>
                  {guess.reasons ? (
                    <p className="mt-1 text-xs text-muted-foreground">{guess.reasons}</p>
                  ) : null}
                </div>
              </div>
            ))}
          </div>
        ) : null}

        <div className="space-y-2">
          <div className="flex items-center gap-2">
            <Input
              className="max-w-xs"
              placeholder="Set another company..."
              value={input}
              onChange={(e) => onInputChange(e.target.value)}
            />
            <Button
              variant="outline"
              size="sm"
              disabled={!input.trim() || loading}
              onClick={() => onPick(input.trim())}
            >
              Set
            </Button>
          </div>

          {suggestions.length > 0 ? (
            <div className="flex flex-wrap gap-1.5">
              {suggestions.map(({ id, name }) => (
                <button key={id} type="button" onClick={() => onPick(name)}>
                  <Badge variant="outline" className="hover:bg-muted">
                    {name}
                  </Badge>
                </button>
              ))}
            </div>
          ) : null}
        </div>
      </CardContent>
    </Card>
  )
}

interface FinalClientPickerProps {
  offer: Offer
}

export function FinalClientPicker({ offer }: FinalClientPickerProps) {
  const { input, setInput, suggestions, pick, loading } = useFinalClient(offer.id)

  return (
    <FinalClientPickerView
      finalCompany={offer.finalCompany ?? null}
      guesses={offer.finalClientGuesses}
      loading={loading}
      input={input}
      onInputChange={setInput}
      suggestions={suggestions}
      onPick={pick}
    />
  )
}
