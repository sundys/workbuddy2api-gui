// theme.tsx 明暗主题：localStorage 持久化，<html data-theme> 驱动 CSS 变量。
import { createContext, useCallback, useContext, useEffect, useMemo, useState } from 'react'

export type Theme = 'dark' | 'light'

const STORAGE_KEY = 'wbgui-theme'

function readStored(): Theme {
  try {
    const v = localStorage.getItem(STORAGE_KEY)
    // 只有显式存过才认；没存过走默认（夜间）。
    return v === 'light' || v === 'dark' ? v : 'dark'
  } catch {
    return 'dark'
  }
}

function apply(theme: Theme) {
  document.documentElement.setAttribute('data-theme', theme)
  // 让浏览器原生控件（滚动条、输入框聚焦框）也跟随主题。
  document.documentElement.style.colorScheme = theme
}

type ThemeContextValue = {
  theme: Theme
  toggle: () => void
  setTheme: (theme: Theme) => void
}

const ThemeContext = createContext<ThemeContextValue | null>(null)

export function ThemeProvider({ children }: { children: React.ReactNode }) {
  const [theme, setThemeState] = useState<Theme>(readStored)

  useEffect(() => {
    apply(theme)
  }, [theme])

  // 其他标签页改了主题时同步过来。
  useEffect(() => {
    const onStorage = (e: StorageEvent) => {
      if (e.key === STORAGE_KEY) setThemeState(readStored())
    }
    window.addEventListener('storage', onStorage)
    return () => window.removeEventListener('storage', onStorage)
  }, [])

  const setTheme = useCallback((next: Theme) => {
    setThemeState(next)
    try {
      localStorage.setItem(STORAGE_KEY, next)
    } catch {
      // 隐私模式 / 存储被禁用时静默降级：本次会话内仍然生效。
    }
  }, [])

  const toggle = useCallback(() => {
    setTheme(theme === 'dark' ? 'light' : 'dark')
  }, [theme, setTheme])

  const value = useMemo(() => ({ theme, toggle, setTheme }), [theme, toggle, setTheme])

  return <ThemeContext.Provider value={value}>{children}</ThemeContext.Provider>
}

export function useTheme(): ThemeContextValue {
  const ctx = useContext(ThemeContext)
  if (!ctx) throw new Error('useTheme 必须在 ThemeProvider 内使用')
  return ctx
}
