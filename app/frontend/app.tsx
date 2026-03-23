import { createBrowserRouter, RouterProvider } from 'react-router'
import AppShell from '@/components/layout/app-shell'
import DashboardPage from '@/pages/dashboard'
import OffersPage from '@/pages/offers/index'
import OfferDetailPage from '@/pages/offers/detail'
import SourcingPage from '@/pages/sourcing'
import ProfilePage from '@/pages/profile'

const router = createBrowserRouter([
  {
    path: '/',
    element: <AppShell />,
    children: [
      { index: true, element: <DashboardPage /> },
      { path: 'offers', element: <OffersPage /> },
      { path: 'offers/:id', element: <OfferDetailPage /> },
      { path: 'sourcing', element: <SourcingPage /> },
      { path: 'profile', element: <ProfilePage /> },
    ],
  },
])

export default function App() {
  return <RouterProvider router={router} />
}
