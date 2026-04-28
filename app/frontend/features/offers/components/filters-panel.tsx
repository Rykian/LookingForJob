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
import type { DatePreset, SeenField } from '@/features/offers/hooks/use-filters'
import { locationModeValues } from '@/features/offers/hooks/use-filters'
import { formatLocationMode } from '@/features/offers/utils/location-mode'

interface FiltersPanelProps {
  providerKeys: string[]
  providerLoading: boolean
  technologyKeys: string[]
  technologiesLoading: boolean
  selectedTechnologies: string[]
  selectedSources: string[]
  selectedLocationModes: string[]
  seenField: SeenField
  datePreset: DatePreset
  onChangeTechnologies: (items: string[]) => void
  onChangeSources: (items: string[]) => void
  onChangeLocationModes: (items: string[]) => void
  onChangeSeenField: (value: string) => void
  onChangeDatePreset: (value: string) => void
  onReset: () => void
}

export function FiltersPanel({
  providerKeys,
  providerLoading,
  technologyKeys,
  technologiesLoading,
  selectedTechnologies,
  selectedSources,
  selectedLocationModes,
  seenField,
  datePreset,
  onChangeTechnologies,
  onChangeSources,
  onChangeLocationModes,
  onChangeSeenField,
  onChangeDatePreset,
  onReset,
}: FiltersPanelProps) {
  return (
    <Card>
      <CardHeader>
        <CardTitle className="text-base">Filters</CardTitle>
      </CardHeader>
      <CardContent>
        <div className="grid grid-cols-1 gap-3 md:grid-cols-6">
          <Combobox
            multiple
            items={technologyKeys}
            disabled={technologiesLoading}
            onValueChange={onChangeTechnologies}
          >
            <ComboboxChips>
              <ComboboxValue>
                {selectedTechnologies.map((item) => (
                  <ComboboxChip key={item}>{item}</ComboboxChip>
                ))}
              </ComboboxValue>
              <ComboboxChipsInput placeholder="Filter by technology..." />
            </ComboboxChips>

            <ComboboxContent>
              <ComboboxEmpty>All technologies</ComboboxEmpty>
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
            items={providerKeys}
            onValueChange={onChangeSources}
            disabled={providerLoading}
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

          <Combobox multiple items={locationModeValues} onValueChange={onChangeLocationModes}>
            <ComboboxChips>
              <ComboboxValue>
                {selectedLocationModes.map((item) => (
                  <ComboboxChip key={item}>{formatLocationMode(item)}</ComboboxChip>
                ))}
              </ComboboxValue>
              <ComboboxChipsInput placeholder="Filter by location mode..." />
            </ComboboxChips>

            <ComboboxContent>
              <ComboboxEmpty>All location modes</ComboboxEmpty>
              <ComboboxList>
                {(item) => (
                  <ComboboxItem key={item} value={item}>
                    {formatLocationMode(item)}
                  </ComboboxItem>
                )}
              </ComboboxList>
            </ComboboxContent>
          </Combobox>

          <select
            className="h-10 rounded-md border bg-background px-3 text-sm"
            value={seenField}
            onChange={(event) => onChangeSeenField(event.target.value)}
          >
            <option value="first_seen_at">Seen field: first seen</option>
            <option value="last_seen_at">Seen field: last seen</option>
          </select>

          <select
            className="h-10 rounded-md border bg-background px-3 text-sm"
            value={datePreset}
            onChange={(event) => onChangeDatePreset(event.target.value)}
          >
            <option value="today">Date: today</option>
            <option value="yesterday">Date: yesterday</option>
            <option value="last_7_days">Date: last 7 days</option>
            <option value="last_30_days">Date: last 30 days</option>
          </select>

          <Button variant="outline" onClick={onReset}>
            Reset
          </Button>
        </div>
      </CardContent>
    </Card>
  )
}
