import { useParams } from 'react-router'

export default function OfferDetailPage() {
  const { id } = useParams()
  return (
    <div className="p-8">
      <h1 className="text-2xl font-semibold">Offer #{id}</h1>
      <p className="mt-2 text-muted-foreground">Score breakdown and detail — coming in Phase 3.</p>
    </div>
  )
}
