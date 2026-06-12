import { createBrowserRouter, RouterProvider } from 'react-router'
import AppShell from '@/components/layout/app-shell'
import CompanyDetailPage from '@/pages/companies/detail'
import CompaniesPage from '@/pages/companies/index'
import DashboardPage from '@/pages/dashboard'
import ErrorsPage from '@/pages/errors/index'
import OfferDetailPage from '@/pages/offers/detail'
import OffersPage from '@/pages/offers/index'
import ProfilePage from '@/pages/profile'
import RunsPage from '@/pages/runs/index'
import SourcingPage from '@/pages/sourcing'

const router = createBrowserRouter([
  {
    path: '/',
    element: <AppShell />,
    children: [
      { index: true, element: <DashboardPage /> },
      { path: 'offers', element: <OffersPage /> },
      { path: 'offers/:id', element: <OfferDetailPage /> },
      { path: 'companies', element: <CompaniesPage /> },
      { path: 'companies/:id', element: <CompanyDetailPage /> },
      { path: 'runs', element: <RunsPage /> },
      { path: 'errors', element: <ErrorsPage /> },
      { path: 'sourcing', element: <SourcingPage /> },
      { path: 'profile', element: <ProfilePage /> },
    ],
  },
])

export default function App() {
  return <RouterProvider router={router} />
}
