import { Button } from '@/components/ui/button'

interface PaginationProps {
  page: number
  totalPages: number
  onPrevious: () => void
  onNext: () => void
}

export function Pagination({ page, totalPages, onPrevious, onNext }: PaginationProps) {
  return (
    <div className="mt-4 flex items-center justify-between">
      <span className="text-sm text-muted-foreground">
        Page {page} of {Math.max(totalPages, 1)}
      </span>
      <div className="flex gap-2">
        <Button variant="outline" size="sm" disabled={page <= 1} onClick={onPrevious}>
          Previous
        </Button>
        <Button variant="outline" size="sm" disabled={page >= totalPages} onClick={onNext}>
          Next
        </Button>
      </div>
    </div>
  )
}
