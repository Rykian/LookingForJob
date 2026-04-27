import { render, screen } from '@testing-library/react'
import { createMemoryRouter, RouterProvider } from 'react-router'
import { describe, expect, it } from 'vitest'
import AppShell from './app-shell'

describe('AppShell', () => {
  it('renders sidebar, nav, and outlet content', () => {
    const router = createMemoryRouter(
      [
        {
          path: '/',
          element: <AppShell />,
          children: [
            {
              index: true,
              element: <div>Dashboard content</div>,
            },
          ],
        },
      ],
      { initialEntries: ['/'] },
    )

    render(<RouterProvider router={router} />)

    expect(screen.getByText('LookingForJob')).toBeInTheDocument()
    expect(screen.getByRole('link', { name: 'Offers' })).toBeInTheDocument()
    expect(screen.getByText('Dashboard content')).toBeInTheDocument()
  })
})
