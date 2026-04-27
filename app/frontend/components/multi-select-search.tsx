// Simple multi-select with search for technologies
import { useState } from 'react'

interface MultiSelectSearchProps {
  options: string[]
  value: string[]
  onChange: (value: string[]) => void
  placeholder?: string
}

export function MultiSelectSearch({
  options,
  value,
  onChange,
  placeholder,
}: MultiSelectSearchProps) {
  const [search, setSearch] = useState('')
  const filtered = options.filter((opt) => opt.toLowerCase().includes(search.toLowerCase()))

  return (
    <div className="relative">
      <input
        className="h-10 rounded-md border bg-background px-3 text-sm w-full mb-1"
        placeholder={placeholder || 'Search...'}
        value={search}
        onChange={(e) => setSearch(e.target.value)}
      />
      <div className="max-h-40 overflow-y-auto border rounded bg-background absolute w-full z-10">
        {filtered.map((opt) => (
          <label key={opt} className="flex items-center px-2 py-1 cursor-pointer hover:bg-accent">
            <input
              type="checkbox"
              checked={value.includes(opt)}
              onChange={() => {
                if (value.includes(opt)) {
                  onChange(value.filter((v) => v !== opt))
                } else {
                  onChange([...value, opt])
                }
              }}
              className="mr-2"
            />
            {opt}
          </label>
        ))}
        {filtered.length === 0 && <div className="px-2 py-1 text-muted-foreground">No results</div>}
      </div>
      <div className="flex flex-wrap gap-1 mt-1">
        {value.map((v) => (
          <span key={v} className="bg-accent px-2 py-0.5 rounded text-xs flex items-center">
            {v}
            <button
              type="button"
              className="ml-1 text-destructive"
              onClick={() => onChange(value.filter((val) => val !== v))}
            >
              ×
            </button>
          </span>
        ))}
      </div>
    </div>
  )
}
