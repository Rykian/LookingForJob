import { Briefcase, ExternalLink, LayoutDashboard, Search, Settings } from 'lucide-react'
import { NavLink } from 'react-router'
import { cn } from '@/lib/utils'

const links = [
  { to: '/', label: 'Dashboard', icon: LayoutDashboard, end: true },
  { to: '/offers', label: 'Offers', icon: Briefcase, end: false },
  { to: '/sourcing', label: 'Sourcing', icon: Search, end: false },
  { to: '/profile', label: 'Profile', icon: Settings, end: false },
]

const externalLinks = [{ href: '/sidekiq', label: 'Sidekiq UI', icon: ExternalLink }]

export default function Nav() {
  return (
    <nav className="flex flex-col gap-1 px-2">
      {links.map(({ to, label, icon: Icon, end }) => (
        <NavLink
          key={to}
          to={to}
          end={end}
          className={({ isActive }) =>
            cn(
              'flex items-center gap-3 rounded-md px-3 py-2 text-sm font-medium transition-colors',
              isActive
                ? 'bg-sidebar-accent text-sidebar-accent-foreground'
                : 'text-sidebar-foreground hover:bg-sidebar-accent hover:text-sidebar-accent-foreground',
            )
          }
        >
          <Icon className="h-4 w-4 shrink-0" />
          {label}
        </NavLink>
      ))}

      <div className="my-2 border-t border-sidebar-border" />

      {externalLinks.map(({ href, label, icon: Icon }) => (
        <a
          key={href}
          href={href}
          target="_blank"
          rel="noreferrer"
          className={cn(
            'flex items-center gap-3 rounded-md px-3 py-2 text-sm font-medium transition-colors',
            'text-sidebar-foreground hover:bg-sidebar-accent hover:text-sidebar-accent-foreground',
          )}
        >
          <Icon className="h-4 w-4 shrink-0" />
          {label}
        </a>
      ))}
    </nav>
  )
}
