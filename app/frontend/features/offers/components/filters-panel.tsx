import { useEffect, useState } from 'react'
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
import type { DatePreset, EnglishLevel, SeenField } from '@/features/offers/hooks/use-filters'
import { englishLevelValues, locationModeValues } from '@/features/offers/hooks/use-filters'
import { formatLocationMode } from '@/features/offers/utils/location-mode'

interface FiltersPanelProps {
  providerKeys: string[]
  providerLoading: boolean
  technologyKeys: string[]
  technologiesLoading: boolean
  selectedTechnologies: string[]
  selectedSources: string[]
  selectedLocationModes: string[]
  selectedEnglishLevels: EnglishLevel[]
  seenField: SeenField
  datePreset: DatePreset
  onlyWithinCommute: boolean
  minCommuteMinutes: number | null
  maxCommuteMinutes: number | null
  commuteMaxMinutes: number | null
  onChangeTechnologies: (items: string[]) => void
  onChangeSources: (items: string[]) => void
  onChangeLocationModes: (items: string[]) => void
  onChangeEnglishLevels: (items: EnglishLevel[]) => void
  onChangeSeenField: (value: string) => void
  onChangeDatePreset: (value: string) => void
  onChangeOnlyWithinCommute: (checked: boolean) => void
  onChangeMinCommuteMinutes: (value: number | null) => void
  onChangeMaxCommuteMinutes: (value: number | null) => void
  search: string
  onChangeSearch: (value: string) => void
  onReset: () => void
}

function parseMinutes(raw: string): number | null {
  const n = Number.parseInt(raw, 10)
  return Number.isFinite(n) && n >= 0 ? n : null
}

export function FiltersPanel({
  providerKeys,
  providerLoading,
  technologyKeys,
  technologiesLoading,
  selectedTechnologies,
  selectedSources,
  selectedLocationModes,
  selectedEnglishLevels,
  seenField,
  datePreset,
  onlyWithinCommute,
  minCommuteMinutes,
  maxCommuteMinutes,
  commuteMaxMinutes,
  onChangeTechnologies,
  onChangeSources,
  onChangeLocationModes,
  onChangeEnglishLevels,
  onChangeSeenField,
  onChangeDatePreset,
  onChangeOnlyWithinCommute,
  onChangeMinCommuteMinutes,
  onChangeMaxCommuteMinutes,
  search,
  onChangeSearch,
  onReset,
}: FiltersPanelProps) {
  const [localSearch, setLocalSearch] = useState(search)

  useEffect(() => {
    setLocalSearch(search)
  }, [search])

  useEffect(() => {
    const id = setTimeout(() => onChangeSearch(localSearch), 300)
    return () => clearTimeout(id)
  }, [localSearch, onChangeSearch])

  return (
    <Card>
      <CardHeader>
        <CardTitle className="text-base">Filters</CardTitle>
      </CardHeader>
      <CardContent>
        <div className="grid grid-cols-1 gap-3 md:grid-cols-6">
          <Input
            type="search"
            placeholder="Search title, company, tech..."
            value={localSearch}
            onChange={(e) => setLocalSearch(e.target.value)}
            className="md:col-span-2"
          />

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

          <Combobox multiple items={englishLevelValues} onValueChange={onChangeEnglishLevels}>
            <ComboboxChips>
              <ComboboxValue>
                {selectedEnglishLevels.map((item) => (
                  <ComboboxChip key={item}>{item}</ComboboxChip>
                ))}
              </ComboboxValue>
              <ComboboxChipsInput placeholder="Filter by English level..." />
            </ComboboxChips>

            <ComboboxContent>
              <ComboboxEmpty>All English levels</ComboboxEmpty>
              <ComboboxList>
                {(item) => (
                  <ComboboxItem key={item} value={item}>
                    {item}
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
            <option value="all">Date: all</option>
            <option value="today">Date: today</option>
            <option value="yesterday">Date: yesterday</option>
            <option value="last_7_days">Date: last 7 days</option>
            <option value="last_30_days">Date: last 30 days</option>
          </select>

          <div className="flex gap-2">
            <Input
              type="number"
              min={0}
              placeholder="Min commute"
              value={minCommuteMinutes ?? ''}
              onChange={(e) => {
                onChangeOnlyWithinCommute(false)
                onChangeMinCommuteMinutes(parseMinutes(e.target.value))
              }}
            />
            <Input
              type="number"
              min={0}
              placeholder={
                commuteMaxMinutes != null ? `Max (profile: ${commuteMaxMinutes})` : 'Max commute'
              }
              value={maxCommuteMinutes ?? ''}
              onChange={(e) => {
                onChangeOnlyWithinCommute(false)
                onChangeMaxCommuteMinutes(parseMinutes(e.target.value))
              }}
            />
          </div>

          <label className="flex h-10 cursor-pointer items-center gap-2 rounded-md border bg-background px-3 text-sm">
            <input
              type="checkbox"
              checked={onlyWithinCommute}
              onChange={(e) => onChangeOnlyWithinCommute(e.target.checked)}
            />
            Within commute
          </label>

          <Button variant="outline" onClick={onReset}>
            Reset
          </Button>
        </div>
      </CardContent>
    </Card>
  )
}
