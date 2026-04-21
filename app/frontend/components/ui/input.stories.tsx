import type { Meta, StoryObj } from '@storybook/react'
import { expect, userEvent, within } from 'storybook/test'
import { Input } from './input'

const meta = {
  title: 'UI/Input',
  component: Input,
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
    type: {
      control: 'select',
      options: ['text', 'email', 'password', 'number', 'search'],
    },
  },
} satisfies Meta<typeof Input>

export default meta
type Story = StoryObj<typeof meta>

export const Default: Story = {
  args: { placeholder: 'Enter text…' },
}

export const WithValue: Story = {
  args: { defaultValue: 'Hello world', placeholder: 'Enter text…' },
}

export const Disabled: Story = {
  args: { disabled: true, placeholder: 'Disabled input', value: 'Cannot edit' },
}

export const Email: Story = {
  args: { type: 'email', placeholder: 'you@example.com' },
}

export const Password: Story = {
  args: { type: 'password', placeholder: 'Password' },
}

export const Invalid: Story = {
  args: { 'aria-invalid': true, placeholder: 'Invalid input' },
}

export const TypeInteraction: Story = {
  args: { placeholder: 'Type here…' },
  play: async ({ canvasElement }) => {
    const canvas = within(canvasElement)
    const input = canvas.getByPlaceholderText(/type here/i)
    await userEvent.click(input)
    await userEvent.type(input, 'Hello Storybook')
    await expect(input).toHaveValue('Hello Storybook')
  },
}
