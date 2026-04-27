import { render, screen } from '@testing-library/react'
import { describe, expect, it } from 'vitest'
import { Card, CardContent, CardFooter, CardHeader, CardTitle } from './card'

describe('Card', () => {
  it('renders composed slots', () => {
    render(
      <Card>
        <CardHeader>
          <CardTitle>Offer title</CardTitle>
        </CardHeader>
        <CardContent>Offer content</CardContent>
        <CardFooter>Offer footer</CardFooter>
      </Card>,
    )

    expect(screen.getByText('Offer title')).toBeInTheDocument()
    expect(screen.getByText('Offer content')).toBeInTheDocument()
    expect(screen.getByText('Offer footer')).toBeInTheDocument()
  })
})
