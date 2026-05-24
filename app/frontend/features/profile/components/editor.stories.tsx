import type { Meta, StoryObj } from '@storybook/react'
import { Editor } from './editor'

const meta = {
  title: 'Profile/Editor',
  component: Editor,
  parameters: { layout: 'padded' },
  tags: ['autodocs'],
  decorators: [
    (Story) => (
      <div className="max-w-4xl">
        <Story />
      </div>
    ),
  ],
} satisfies Meta<typeof Editor>

export default meta
type Story = StoryObj<typeof meta>

const sampleJson = `{
  "version": "v1",
  "weights": {
    "stack": 0.4,
    "salary": 0.3,
    "location": 0.3
  }
}`

export const Default: Story = {
  args: {
    text: sampleJson,
    saving: false,
    reloading: false,
    parseError: null,
    saveError: false,
    reloadError: false,
    savedMessage: '',
    reloadedMessage: '',
    onTextChange: () => {},
    onSave: () => {},
    onReload: () => {},
  },
}

export const SaveSuccess: Story = {
  args: {
    ...Default.args,
    savedMessage: 'Scoring profile updated.',
  },
}

export const ReloadSuccess: Story = {
  args: {
    ...Default.args,
    reloadedMessage: 'Profile reloaded from file.',
  },
}

export const ParseError: Story = {
  args: {
    ...Default.args,
    parseError: 'Invalid JSON. Please fix parsing errors before saving.',
  },
}
