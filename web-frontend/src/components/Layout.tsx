import { NavLink, Outlet, useLocation } from 'react-router-dom';
import { useAuth } from '../context/AuthContext';
import { useEffect, useRef } from 'react';
import gsap from 'gsap';

const navItems = [
  { to: '/dashboard', icon: '⬡', label: 'Dashboard', emoji: '⬡' },
  { to: '/quiz', icon: '◈', label: 'Quiz' },
  { to: '/sem-check', icon: '◎', label: 'Sem Check' },
  { to: '/history', icon: '◷', label: 'History' },
];

const S = {
  sidebar: {
    width: 220,
    background:
      'linear-gradient(180deg, rgba(88,63,196,0.96) 0%, rgba(109,94,252,0.94) 34%, rgba(129,104,255,0.9) 100%)',
    borderRight: '1px solid rgba(255,255,255,0.14)',
    display: 'flex' as const,
    flexDirection: 'column' as const,
    padding: '20px 12px',
    position: 'fixed' as const,
    top: 0, left: 0, bottom: 0,
    zIndex: 50,
    boxShadow: '18px 0 40px rgba(82, 63, 199, 0.22)',
    backdropFilter: 'blur(16px)',
  },
  main: {
    marginLeft: 220,
    minHeight: '100vh',
    background: 'transparent',
    flex: 1,
  },
};

export default function Layout() {
  const { user, logout } = useAuth();
  const location = useLocation();
  const sidebarRef = useRef<HTMLElement>(null);
  const mainRef = useRef<HTMLElement>(null);

  // Sidebar entrance
  useEffect(() => {
    if (!sidebarRef.current) return;
    gsap.fromTo(sidebarRef.current, 
      { x: -30, opacity: 0 },
      { x: 0, opacity: 1, duration: 0.6, ease: 'power3.out' }
    );
  }, []);

  // Page transition on route change
  useEffect(() => {
    if (!mainRef.current) return;
    gsap.fromTo(mainRef.current, 
      { opacity: 0, y: 12 },
      { opacity: 1, y: 0, duration: 0.4, ease: 'power2.out' }
    );
  }, [location.pathname]);

  const isDashboard = location.pathname === '/dashboard';

  return (
    <div style={{ display: 'flex', minHeight: '100vh', background: 'var(--bg-base)' }}>
      {/* ── Sidebar ──────────────────────────────────────────────────────── */}
      <aside ref={sidebarRef} style={S.sidebar}>
        {/* Logo */}
        <div style={{ display: 'flex', alignItems: 'center', gap: 10, padding: '4px 8px', marginBottom: 28 }}>
          <div style={{
            width: 36, height: 36, borderRadius: 10,
            background: 'linear-gradient(135deg, #ffffff, #e9e4ff)',
            display: 'flex', alignItems: 'center', justifyContent: 'center',
            color: 'var(--purple-dark)', fontWeight: 900, fontSize: 16, flexShrink: 0,
            boxShadow: '0 16px 30px rgba(44, 24, 125, 0.24)',
          }}>CC</div>
          <div>
            <div style={{ fontWeight: 800, fontSize: '0.95rem', color: '#ffffff', letterSpacing: '-0.3px' }}>
              Code<span style={{ color: '#ddd6fe' }}>Crafters</span>
            </div>
            <div style={{ fontSize: '0.64rem', color: 'rgba(255,255,255,0.72)', marginTop: 1 }}>Learning Gap Analyzer</div>
          </div>
        </div>

        {/* Nav */}
        <nav style={{ display: 'flex', flexDirection: 'column', gap: 2, flex: 1 }}>
          {navItems.map(item => (
            <NavLink key={item.to} to={item.to}
              style={({ isActive }) => ({
                display: 'flex', alignItems: 'center', gap: 10,
                padding: '10px 12px', borderRadius: 10, textDecoration: 'none',
                fontWeight: 600, fontSize: '0.88rem', transition: 'all 0.2s',
                background: isActive
                  ? 'linear-gradient(135deg, rgba(255,255,255,0.24), rgba(255,255,255,0.12))'
                  : 'transparent',
                color: isActive ? '#ffffff' : 'rgba(255,255,255,0.82)',
                borderLeft: isActive ? '2px solid #ffffff' : '2px solid transparent',
                boxShadow: isActive ? '0 14px 28px rgba(44,24,125,0.18)' : 'none',
              })}>
              <span style={{ fontSize: '0.82rem', letterSpacing: '0.05em', opacity: 0.88 }}>{item.icon}</span>
              {item.label}
            </NavLink>
          ))}
        </nav>

        {/* Divider */}
        <div style={{ height: 1, background: 'rgba(255,255,255,0.16)', margin: '12px 0' }} />

        {/* User section */}
        <div>
          <div style={{ display: 'flex', alignItems: 'center', gap: 10, padding: '8px 12px', borderRadius: 10, background: 'rgba(255,255,255,0.16)', border: '1px solid rgba(255,255,255,0.18)', boxShadow: '0 10px 24px rgba(44, 24, 125, 0.16)' }}>
            <div style={{
              width: 32, height: 32, borderRadius: '50%',
              background: 'linear-gradient(135deg, #ffffff, #ddd6fe)',
              display: 'flex', alignItems: 'center', justifyContent: 'center',
              color: 'var(--purple-dark)', fontWeight: 700, fontSize: '0.8rem', flexShrink: 0,
              boxShadow: '0 0 12px rgba(255,255,255,0.16)',
            }}>{user?.name?.charAt(0)?.toUpperCase() || 'U'}</div>
            <div style={{ flex: 1, minWidth: 0 }}>
              <div style={{ fontWeight: 600, fontSize: '0.8rem', color: '#ffffff', overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>{user?.name || 'Student'}</div>
              <div style={{ fontSize: '0.66rem', color: 'rgba(255,255,255,0.72)', overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>{user?.email}</div>
            </div>
          </div>
          <button onClick={logout}
            style={{ display: 'flex', alignItems: 'center', gap: 8, padding: '8px 12px', border: 'none', background: 'transparent', color: 'rgba(255,255,255,0.78)', cursor: 'pointer', fontWeight: 500, fontSize: '0.8rem', borderRadius: 8, width: '100%', marginTop: 4, transition: 'all 0.2s' }}
            onMouseEnter={e => { (e.currentTarget as HTMLElement).style.color = '#ffffff'; (e.currentTarget as HTMLElement).style.background = 'rgba(255,255,255,0.12)'; }}
            onMouseLeave={e => { (e.currentTarget as HTMLElement).style.color = 'rgba(255,255,255,0.78)'; (e.currentTarget as HTMLElement).style.background = 'transparent'; }}>
            ↩ Sign Out
          </button>
        </div>
      </aside>

      {/* ── Main ─────────────────────────────────────────────────────────── */}
      <main ref={mainRef} style={{ ...S.main, padding: isDashboard ? 0 : '32px 40px' }}>
        <Outlet />
      </main>
    </div>
  );
}
