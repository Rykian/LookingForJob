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
    page: 5,
    totalPages: 10,
    onPageChange: () => {},
  },
}

export const FirstPage: Story = {
  args: {
    page: 1,
    totalPages: 10,
    onPageChange: () => {},
  },
}

export const LastPage: Story = {
  args: {
    page: 10,
    totalPages: 10,
    onPageChange: () => {},
  },
}

export const FewPages: Story = {
  args: {
    page: 2,
    totalPages: 4,
    onPageChange: () => {},
  },
}
