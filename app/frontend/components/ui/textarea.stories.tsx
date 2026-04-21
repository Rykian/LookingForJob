import type { Meta, StoryObj } from '@storybook/react'
import { expect, userEvent, within } from 'storybook/test'
import { Textarea } from './textarea'

const meta = {
  title: 'UI/Textarea',
  component: Textarea,
  parameters: { layout: 'centered' },
  tags: ['autodocs'],
  decorators: [
    (Story) => (
      <div className="w-72">
        <Story />
      </div>
    ),
  ],
  argTypes: {
    disabled: { control: 'boolean' },
    placeholder: { control: 'text' },
  },
} satisfies Meta<typeof Textarea>

export default meta
type Story = StoryObj<typeof meta>

export const Default: Story = {
  args: { placeholder: 'Enter your message…' },
}

export const WithValue: Story = {
  args: { defaultValue: 'Pre-filled content', placeholder: 'Enter your message…' },
}

export const Disabled: Story = {
  args: { disabled: true, placeholder: 'Disabled', value: 'Cannot edit' },
}

export const Invalid: Story = {
  args: { 'aria-invalid': true, placeholder: 'Error state' },
}

export const TypeInteraction: Story = {
  args: { placeholder: 'Type here…' },
  play: async ({ canvasElement }) => {
    const canvas = within(canvasElement)
    const textarea = canvas.getByPlaceholderText(/type here/i)
    await userEvent.click(textarea)
    await userEvent.type(textarea, 'Hello from Storybook tests')
    await expect(textarea).toHaveValue('Hello from Storybook tests')
  },
}
