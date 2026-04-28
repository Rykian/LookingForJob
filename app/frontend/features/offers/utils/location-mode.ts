export function formatLocationMode(mode: string | null | undefined): string {
  switch (mode) {
    case 'REMOTE':
      return 'Remote'
    case 'HYBRID':
      return 'Hybrid'
    case 'ON_SITE':
      return 'On-site'
    default:
      return 'Unknown'
  }
}
