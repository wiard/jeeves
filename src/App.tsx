import { useState } from 'react'
import { Observatory } from './screens/Observatory'
import { TokenScreen } from './screens/TokenScreen'

export default function App() {
  const [token, setToken] = useState<string | null>(localStorage.getItem('radar-token'))
  const [baseUrl, setBaseUrl] = useState(localStorage.getItem('radar-url') || 'http://localhost:19001')

  if (!token) {
    return (
      <TokenScreen
        defaultBaseUrl={baseUrl}
        onConnect={(nextToken, nextUrl) => {
          localStorage.setItem('radar-token', nextToken)
          localStorage.setItem('radar-url', nextUrl)
          setToken(nextToken)
          setBaseUrl(nextUrl)
        }}
      />
    )
  }

  return (
    <Observatory
      token={token}
      baseUrl={baseUrl}
      onDisconnect={() => {
        localStorage.removeItem('radar-token')
        setToken(null)
      }}
    />
  )
}
