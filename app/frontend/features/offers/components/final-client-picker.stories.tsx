import type { Meta, StoryObj } from '@storybook/react'
import { MemoryRouter } from 'react-router'

import { FinalClientPickerView } from './final-client-picker'

const meta = {
  title: 'Offers/FinalClientPicker',
  component: FinalClientPickerView,
  parameters: { layout: 'padded' },
  tags: ['autodocs'],
  decorators: [
    (Story) => (
      <MemoryRouter>
        <Story />
      </MemoryRouter>
    ),
  ],
  args: {
    onInputChange: () => {},
    onPick: () => {},
  },
} satisfies Meta<typeof FinalClientPickerView>

export default meta
type Story = StoryObj<typeof meta>

const guesses = [
  {
    name: 'Société Générale',
    confidence: 0.85,
    reasons: 'Description mentions a banking client in La Défense with a Java/Kafka stack.',
  },
  {
    name: 'BNP Paribas',
    confidence: 0.4,
    reasons: 'Alternative large French bank matching the sector hint.',
  },
]

export const WithGuesses: Story = {
  args: {
    finalCompany: null,
    guesses,
    loading: false,
    input: '',
    suggestions: [],
  },
}

export const LinkedFinalClient: Story = {
  args: {
    finalCompany: { id: '42', name: 'Société Générale' },
    guesses,
    loading: false,
    input: '',
    suggestions: [],
  },
}

export const WithSuggestions: Story = {
  args: {
    finalCompany: null,
    guesses: [],
    loading: false,
    input: 'soc',
    suggestions: [
      { id: '42', name: 'Société Générale' },
      { id: '43', name: 'Socotec' },
    ],
  },
}

export const Empty: Story = {
  args: {
    finalCompany: null,
    guesses: [],
    loading: false,
    input: '',
    suggestions: [],
  },
}

export const Saving: Story = {
  args: {
    finalCompany: { id: '42', name: 'Société Générale' },
    guesses,
    loading: true,
    input: '',
    suggestions: [],
  },
}
