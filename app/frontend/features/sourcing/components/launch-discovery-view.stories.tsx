import type { Meta, StoryObj } from '@storybook/react'
import { LaunchDiscoveryView } from './launch-discovery-view'

const meta = {
  title: 'Features/Sourcing/LaunchDiscoveryView',
  component: LaunchDiscoveryView,
  parameters: { layout: 'centered' },
  decorators: [
    (Story) => (
      <div className="w-full max-w-4xl p-4">
        <Story />
      </div>
    ),
  ],
  tags: ['autodocs'],
} satisfies Meta<typeof LaunchDiscoveryView>

export default meta
type Story = StoryObj<typeof meta>

const defaultProviders = ['linkedin', 'indeed', 'apec', 'france_travail', 'cadremploi', 'hellowork']
const defaultKeywords = ['ruby', 'nodejs', 'java', 'scala', 'elixir']

export const Default: Story = {
  args: {
    providers: defaultProviders,
    providersLoading: false,
    selectedProviders: defaultProviders,
    onProvidersChange: () => {},
    keywords: defaultKeywords,
    keywordsLoading: false,
    selectedKeywords: defaultKeywords,
    onKeywordsChange: () => {},
    isLaunching: false,
    error: undefined,
    successMessage: undefined,
    onLaunch: () => console.log('Launch clicked'),
  },
}

export const PartialSelection: Story = {
  args: {
    ...Default.args,
    selectedProviders: ['linkedin', 'indeed'],
    selectedKeywords: ['ruby', 'nodejs'],
  },
}

export const LoadingProviders: Story = {
  args: {
    ...Default.args,
    providersLoading: true,
    selectedProviders: [],
  },
}

export const LoadingKeywords: Story = {
  args: {
    ...Default.args,
    keywordsLoading: true,
    selectedKeywords: [],
  },
}

export const Launching: Story = {
  args: {
    ...Default.args,
    isLaunching: true,
  },
}

export const Success: Story = {
  args: {
    ...Default.args,
    successMessage: 'Discovery job enqueued.',
    isLaunching: false,
  },
}

export const WithError: Story = {
  args: {
    ...Default.args,
    error: { message: 'Network error', name: 'Error' } as unknown as Error,
    isLaunching: false,
  },
}

export const AllLoadingStates: Story = {
  args: {
    ...Default.args,
    providersLoading: true,
    keywordsLoading: true,
    selectedProviders: [],
    selectedKeywords: [],
  },
}

export const SingleProviderSelection: Story = {
  args: {
    ...Default.args,
    selectedProviders: ['linkedin'],
  },
}

export const SingleKeywordSelection: Story = {
  args: {
    ...Default.args,
    selectedKeywords: ['ruby'],
  },
}

export const ManyOptions: Story = {
  args: {
    ...Default.args,
    providers: [
      'linkedin',
      'indeed',
      'apec',
      'france_travail',
      'cadremploi',
      'hellowork',
      'welcome_to_the_jungle',
      'github_jobs',
    ],
    selectedProviders: [
      'linkedin',
      'indeed',
      'apec',
      'france_travail',
      'cadremploi',
      'hellowork',
      'welcome_to_the_jungle',
      'github_jobs',
    ],
    keywords: [
      'ruby',
      'nodejs',
      'java',
      'scala',
      'elixir',
      'python',
      'go',
      'rust',
      'typescript',
      'javascript',
      'kotlin',
      'swift',
    ],
    selectedKeywords: [
      'ruby',
      'nodejs',
      'java',
      'scala',
      'elixir',
      'python',
      'go',
      'rust',
      'typescript',
      'javascript',
      'kotlin',
      'swift',
    ],
  },
}

export const EmptyProviders: Story = {
  args: {
    ...Default.args,
    providers: [],
    selectedProviders: [],
  },
}

export const EmptyKeywords: Story = {
  args: {
    ...Default.args,
    keywords: [],
    selectedKeywords: [],
  },
}

export const BothLoading: Story = {
  args: {
    ...Default.args,
    providersLoading: true,
    keywordsLoading: true,
    selectedProviders: [],
    selectedKeywords: [],
    isLaunching: false,
  },
}

export const LaunchingWithSelection: Story = {
  args: {
    ...Default.args,
    isLaunching: true,
    selectedProviders: ['linkedin', 'indeed'],
    selectedKeywords: ['ruby', 'nodejs'],
  },
}
