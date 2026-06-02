import { Outlet, ScrollRestoration } from 'react-router'
import Nav from './nav'

export default function AppShell() {
  return (
    <div className="flex bg-background">
      <aside className="sticky top-0 flex h-screen w-56 shrink-0 flex-col border-r bg-sidebar-background">
        <div className="flex h-14 items-center border-b px-4">
          <span className="font-semibold text-sidebar-foreground">LookingForJob</span>
        </div>
        <div className="flex-1 overflow-y-auto py-4">
          <Nav />
        </div>
      </aside>

      {/* Main content */}
      <main className="flex flex-1 flex-col">
        <Outlet />
      </main>
      <ScrollRestoration />
    </div>
  )
}
