import type { Meta, StoryObj } from '@storybook/react'
import { Pagination } from './pagination'

const meta = {
  title: 'Offers/Pagination',
  component: Pagination,
  parameters: { layout: 'centered' },
  tags: ['autodocs'],
} satisfies Meta<typeof Pagination>

export default meta
type Story = StoryObj<typeof meta>

export const MiddlePage: Story = {
  args: {
    page: 2,
    totalPages: 6,
    onPrevious: () => {},
    onNext: () => {},
  },
}

export const FirstPage: Story = {
  args: {
    page: 1,
    totalPages: 6,
    onPrevious: () => {},
    onNext: () => {},
  },
}

export const LastPage: Story = {
  args: {
    page: 6,
    totalPages: 6,
    onPrevious: () => {},
    onNext: () => {},
  },
}
