import { Button } from '@/components/ui/button'
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card'
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
import { Input } from '@/components/ui/input'
import type { ResolvedFilter, Step } from '@/features/errors/hooks/use-filters'
import { stepValues } from '@/features/errors/hooks/use-filters'

interface FiltersPanelProps {
  resolved: ResolvedFilter
  selectedSteps: Step[]
  selectedSources: string[]
  errorClass: string
  sources: string[]
  errorClasses: string[]
  facetsLoading: boolean
  onChangeResolved: (value: string) => void
  onChangeSteps: (items: string[]) => void
  onChangeSources: (items: string[]) => void
  onChangeErrorClass: (value: string) => void
  onReset: () => void
}

export function FiltersPanel({
  resolved,
  selectedSteps,
  selectedSources,
  errorClass,
  sources,
  errorClasses,
  facetsLoading,
  onChangeResolved,
  onChangeSteps,
  onChangeSources,
  onChangeErrorClass,
  onReset,
}: FiltersPanelProps) {
  return (
    <Card>
      <CardHeader>
        <CardTitle className="text-base">Filters</CardTitle>
      </CardHeader>
      <CardContent>
        <div className="grid grid-cols-1 gap-3 md:grid-cols-5">
          <select
            className="h-10 rounded-md border bg-background px-3 text-sm"
            value={resolved}
            onChange={(event) => onChangeResolved(event.target.value)}
          >
            <option value="unresolved">Status: unresolved</option>
            <option value="resolved">Status: resolved</option>
            <option value="all">Status: all</option>
          </select>

          <Combobox multiple items={[...stepValues]} onValueChange={onChangeSteps}>
            <ComboboxChips>
              <ComboboxValue>
                {selectedSteps.map((item) => (
                  <ComboboxChip key={item}>{item}</ComboboxChip>
                ))}
              </ComboboxValue>
              <ComboboxChipsInput placeholder="Filter by step..." />
            </ComboboxChips>

            <ComboboxContent>
              <ComboboxEmpty>All steps</ComboboxEmpty>
              <ComboboxList>
                {(item) => (
                  <ComboboxItem key={item} value={item}>
                    {item}
                  </ComboboxItem>
                )}
              </ComboboxList>
            </ComboboxContent>
          </Combobox>

          <Combobox
            multiple
            items={sources}
            disabled={facetsLoading}
            onValueChange={onChangeSources}
          >
            <ComboboxChips>
              <ComboboxValue>
                {selectedSources.map((item) => (
                  <ComboboxChip key={item}>{item}</ComboboxChip>
                ))}
              </ComboboxValue>
              <ComboboxChipsInput placeholder="Filter by source..." />
            </ComboboxChips>

            <ComboboxContent>
              <ComboboxEmpty>All sources</ComboboxEmpty>
              <ComboboxList>
                {(item) => (
                  <ComboboxItem key={item} value={item}>
                    {item}
                  </ComboboxItem>
                )}
              </ComboboxList>
            </ComboboxContent>
          </Combobox>

          <Input
            list="error-class-options"
            placeholder="Error class..."
            value={errorClass}
            onChange={(event) => onChangeErrorClass(event.target.value)}
          />
          <datalist id="error-class-options">
            {errorClasses.map((item) => (
              <option key={item} value={item} />
            ))}
          </datalist>

          <Button variant="outline" onClick={onReset}>
            Reset
          </Button>
        </div>
      </CardContent>
    </Card>
  )
}
