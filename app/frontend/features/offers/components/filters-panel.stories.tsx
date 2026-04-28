import type { Meta, StoryObj } from '@storybook/react'
import { FiltersPanel } from './filters-panel'

const meta = {
  title: 'Offers/FiltersPanel',
  component: FiltersPanel,
  parameters: { layout: 'padded' },
  tags: ['autodocs'],
  decorators: [
    (Story) => (
      <div className="max-w-6xl">
        <Story />
      </div>
    ),
  ],
} satisfies Meta<typeof FiltersPanel>

export default meta
type Story = StoryObj<typeof meta>

export const Default: Story = {
  args: {
    providerKeys: ['linkedin', 'wttj', 'hellowork'],
    providerLoading: false,
    technologyKeys: ['ruby', 'react', 'typescript', 'python'],
    technologiesLoading: false,
    selectedTechnologies: ['ruby', 'react'],
    selectedSources: ['linkedin'],
    selectedLocationModes: ['REMOTE'],
    seenField: 'first_seen_at',
    datePreset: 'today',
    onChangeTechnologies: () => {},
    onChangeSources: () => {},
    onChangeLocationModes: () => {},
    onChangeSeenField: () => {},
    onChangeDatePreset: () => {},
    onReset: () => {},
  },
}

export const LoadingProviders: Story = {
  args: {
    ...Default.args,
    providerLoading: true,
  },
}
