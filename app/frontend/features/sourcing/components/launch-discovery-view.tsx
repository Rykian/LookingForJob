import { Button } from '@/components/ui/button'
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from '@/components/ui/card'
import {
  Combobox,
  ComboboxChip,
  ComboboxChips,
  ComboboxChipsInput,
  ComboboxContent,
  ComboboxEmpty,
  ComboboxItem,
  ComboboxList,
  ComboboxValue,
} from '@/components/ui/combobox'

interface LaunchDiscoveryViewProps {
  providers: string[]
  providersLoading: boolean
  selectedProviders: string[]
  onProvidersChange: (providers: string[]) => void
  keywords: string[]
  keywordsLoading: boolean
  selectedKeywords: string[]
  onKeywordsChange: (keywords: string[]) => void
  isLaunching: boolean
  error: Error | undefined
  successMessage?: string | null
  onLaunch: () => void
}

export function LaunchDiscoveryView({
  providers,
  providersLoading,
  selectedProviders,
  onProvidersChange,
  keywords,
  keywordsLoading,
  selectedKeywords,
  onKeywordsChange,
  isLaunching,
  error,
  successMessage,
  onLaunch,
}: LaunchDiscoveryViewProps) {
  return (
    <Card className="max-w-4xl">
      <CardHeader>
        <CardTitle>Launch Discovery</CardTitle>
        <CardDescription>
          This enqueues one discovery job per source x keyword x work mode combination.
        </CardDescription>
      </CardHeader>
      <CardContent className="space-y-4">
        <div className="grid grid-cols-1 gap-4 md:grid-cols-2">
          <div>
            <Combobox
              aria-label="Select providers"
              multiple
              items={providers}
              onValueChange={onProvidersChange}
              disabled={providersLoading}
            >
              <ComboboxChips>
                <ComboboxValue>
                  {selectedProviders.map((item) => (
                    <ComboboxChip key={item}>{item}</ComboboxChip>
                  ))}
                </ComboboxValue>
                <ComboboxChipsInput placeholder="Select providers..." />
              </ComboboxChips>

              <ComboboxContent>
                <ComboboxEmpty>All providers</ComboboxEmpty>
                <ComboboxList>
                  {(item) => (
                    <ComboboxItem key={item} value={item}>
                      {item}
                    </ComboboxItem>
                  )}
                </ComboboxList>
              </ComboboxContent>
            </Combobox>
          </div>

          <div>
            <Combobox
              aria-label="Select keywords"
              multiple
              items={keywords}
              onValueChange={onKeywordsChange}
              disabled={keywordsLoading}
            >
              <ComboboxChips>
                <ComboboxValue>
                  {selectedKeywords.map((item) => (
                    <ComboboxChip key={item}>{item}</ComboboxChip>
                  ))}
                </ComboboxValue>
                <ComboboxChipsInput placeholder="Select keywords..." />
              </ComboboxChips>

              <ComboboxContent>
                <ComboboxEmpty>All keywords</ComboboxEmpty>
                <ComboboxList>
                  {(item) => (
                    <ComboboxItem key={item} value={item}>
                      {item}
                    </ComboboxItem>
                  )}
                </ComboboxList>
              </ComboboxContent>
            </Combobox>
          </div>
        </div>

        <div className="space-y-2">
          <Button disabled={isLaunching || providersLoading || keywordsLoading} onClick={onLaunch}>
            {isLaunching ? 'Launching...' : 'Launch Discovery'}
          </Button>

          {successMessage ? <p className="text-sm text-green-700">{successMessage}</p> : null}
          {error ? (
            <p className="text-sm text-destructive">Failed to enqueue discovery job.</p>
          ) : null}
        </div>
      </CardContent>
    </Card>
  )
}
