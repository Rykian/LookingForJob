import { render } from '@testing-library/react'
import { describe, expect, it } from 'vitest'
import { TechIcon } from './tech-icons'

describe('TechIcon', () => {
  it('renders SVG for known technology', () => {
    const { container } = render(<TechIcon name="React" />)
    const svg = container.querySelector('svg')

    expect(svg).toBeTruthy()
    expect(svg).toHaveAttribute('viewBox', '0 0 24 24')
    expect(svg).toHaveAttribute('title', 'React')
    expect(svg).toHaveAttribute('role', 'img')
  })

  it('renders SVG with correct path for React', () => {
    const { container } = render(<TechIcon name="react" />)
    const path = container.querySelector('svg > path')

    expect(path).toBeTruthy()
    expect(path).toHaveAttribute('d')
  })

  it('sets aria-label to technology name', () => {
    const { container } = render(<TechIcon name="TypeScript" />)
    const svg = container.querySelector('svg')

    expect(svg).toHaveAttribute('aria-label', 'TypeScript')
  })

  it('handles case-insensitive technology names', () => {
    const testCases = ['react', 'REACT', 'React', 'ReAcT']

    testCases.forEach((techName) => {
      const { container } = render(<TechIcon name={techName} />)
      const svg = container.querySelector('svg')

      expect(svg).toBeTruthy()
    })
  })

  it('handles technology names with spaces and dots', () => {
    const { container: container1 } = render(<TechIcon name="Node.js" />)
    const svg1 = container1.querySelector('svg')

    const { container: container2 } = render(<TechIcon name="Ruby on Rails" />)
    const svg2 = container2.querySelector('svg')

    expect(svg1).toBeTruthy()
    expect(svg2).toBeTruthy()
  })

  it('returns null for unknown technology', () => {
    const { container } = render(<TechIcon name="UnknownTech123" />)
    const svg = container.querySelector('svg')

    expect(svg).toBeNull()
  })

  it('renders SVG with fill color attribute', () => {
    const { container } = render(<TechIcon name="docker" />)
    const svg = container.querySelector('svg')

    expect(svg).toHaveAttribute('fill')
    const fill = svg?.getAttribute('fill')
    expect(fill).toMatch(/^#[0-9A-Fa-f]{6}$/)
  })

  it('sets correct dimensions', () => {
    const { container } = render(<TechIcon name="python" />)
    const svg = container.querySelector('svg')

    expect(svg).toHaveAttribute('width', '14')
    expect(svg).toHaveAttribute('height', '14')
  })

  describe('supported technologies', () => {
    const supportedTechs = [
      'react',
      'typescript',
      'javascript',
      'python',
      'ruby',
      'rails',
      'nodejs',
      'postgresql',
      'docker',
      'kubernetes',
      'vue',
      'angular',
      'nextjs',
      'graphql',
      'go',
      'rust',
      'php',
      'django',
      'tailwindcss',
    ]

    supportedTechs.forEach((tech) => {
      it(`renders icon for ${tech}`, () => {
        const { container } = render(<TechIcon name={tech} />)
        const svg = container.querySelector('svg')

        expect(svg).toBeTruthy()
      })
    })
  })
})
