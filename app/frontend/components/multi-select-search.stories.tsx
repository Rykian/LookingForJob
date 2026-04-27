import type { Meta, StoryObj } from '@storybook/react'
import { expect, userEvent, within } from 'storybook/test'
import { MultiSelectSearch } from './multi-select-search'

const OPTIONS = [
  'TypeScript',
  'React',
  'Ruby on Rails',
  'PostgreSQL',
  'Docker',
  'GraphQL',
  'Tailwind CSS',
  'Node.js',
  'Python',
  'Go',
]

const meta = {
  title: 'Components/MultiSelectSearch',
  component: MultiSelectSearch,
  parameters: { layout: 'centered' },
  tags: ['autodocs'],
  decorators: [
    (Story) => (
      <div className="w-80 pb-44">
        <Story />
      </div>
    ),
  ],
  argTypes: {
    placeholder: { control: 'text' },
  },
} satisfies Meta<typeof MultiSelectSearch>

export default meta
type Story = StoryObj<typeof meta>

export const Default: Story = {
  args: {
    options: OPTIONS,
    value: [],
    onChange: () => {},
    placeholder: 'Search technologies…',
  },
}

export const WithPreselected: Story = {
  args: {
    options: OPTIONS,
    value: ['TypeScript', 'React'],
    onChange: () => {},
    placeholder: 'Search technologies…',
  },
}

export const SearchInteraction: Story = {
  args: {
    options: OPTIONS,
    value: [],
    onChange: () => {},
    placeholder: 'Search technologies…',
  },
  play: async ({ canvasElement }) => {
    const canvas = within(canvasElement)
    const input = canvas.getByPlaceholderText(/search technologies/i)

    await userEvent.type(input, 'type')
    const option = await canvas.findByText('TypeScript')
    await expect(option).toBeVisible()

    await userEvent.clear(input)
    await userEvent.type(input, 'zzzz')
    const noResult = await canvas.findByText('No results')
    await expect(noResult).toBeVisible()
  },
}
