import { useEffect, useState } from 'react'
import { Badge } from '@/components/ui/badge'
import { Card, CardContent } from '@/components/ui/card'
import { Input } from '@/components/ui/input'

interface FiltersProps {
  search: string
  postsAsRecruiter: boolean
  postsAsFinalClient: boolean
  onChangeSearch: (value: string) => void
  onToggleRecruiter: () => void
  onToggleFinalClient: () => void
}

export function Filters({
  search,
  postsAsRecruiter,
  postsAsFinalClient,
  onChangeSearch,
  onToggleRecruiter,
  onToggleFinalClient,
}: FiltersProps) {
  const [searchInput, setSearchInput] = useState(search)

  useEffect(() => {
    setSearchInput(search)
  }, [search])

  useEffect(() => {
    if (searchInput === search) return

    const handle = setTimeout(() => onChangeSearch(searchInput), 300)
    return () => clearTimeout(handle)
  }, [searchInput, search, onChangeSearch])

  return (
    <Card>
      <CardContent className="flex flex-wrap items-center gap-3">
        <Input
          className="max-w-xs"
          placeholder="Search companies..."
          value={searchInput}
          onChange={(e) => setSearchInput(e.target.value)}
        />
        <button type="button" onClick={onToggleRecruiter}>
          <Badge variant={postsAsRecruiter ? 'default' : 'outline'}>Recruiter</Badge>
        </button>
        <button type="button" onClick={onToggleFinalClient}>
          <Badge variant={postsAsFinalClient ? 'default' : 'outline'}>Final client</Badge>
        </button>
      </CardContent>
    </Card>
  )
}
