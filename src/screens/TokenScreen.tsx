import { useState, type FormEventHandler } from 'react'
import { createRadarClient } from '../api/radar'

type TokenScreenProps = {
  defaultBaseUrl: string
  onConnect: (token: string, baseUrl: string) => void
}

export function TokenScreen({ defaultBaseUrl, onConnect }: TokenScreenProps) {
  const [token, setToken] = useState('')
  const [baseUrl, setBaseUrl] = useState(defaultBaseUrl)
  const [isLoading, setIsLoading] = useState(false)
  const [error, setError] = useState<string | null>(null)

  const submit: FormEventHandler<HTMLFormElement> = async (event) => {
    event.preventDefault()

    const normalizedToken = token.trim()
    const normalizedUrl = baseUrl.trim() || 'http://localhost:19001'

    if (!normalizedToken) {
      setError('Token is verplicht')
      return
    }

    setIsLoading(true)
    setError(null)

    try {
      const client = createRadarClient({ baseUrl: normalizedUrl, token: normalizedToken })
      await client.status()
      onConnect(normalizedToken, normalizedUrl)
    } catch {
      setError('Verbinding mislukt')
    } finally {
      setIsLoading(false)
    }
  }

  return (
    <main className="token-screen">
      <h1>Observatory</h1>
      <form onSubmit={submit}>
        <label htmlFor="token">Token</label>
        <input
          id="token"
          value={token}
          onChange={(event) => setToken(event.target.value)}
          placeholder="token..."
          autoCapitalize="off"
          autoCorrect="off"
          spellCheck={false}
        />

        <label htmlFor="base-url">Base URL</label>
        <input
          id="base-url"
          value={baseUrl}
          onChange={(event) => setBaseUrl(event.target.value)}
          placeholder="http://localhost:19001"
          autoCapitalize="off"
          autoCorrect="off"
          spellCheck={false}
        />

        <button type="submit" disabled={isLoading}>
          {isLoading ? 'Verbinden...' : 'Verbinden'}
        </button>

        {error ? <div className="error">{error}</div> : null}
      </form>

      <p className="jeeves-greeting">De butler wacht op uw aanwijzingen, meneer.</p>
    </main>
  )
}
