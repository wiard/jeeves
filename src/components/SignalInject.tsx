import { useState, type FormEventHandler } from 'react'

type SignalInjectPayload = {
  title: string
  summary?: string
  source?: string
}

type SignalInjectProps = {
  onSubmit: (payload: SignalInjectPayload) => Promise<void>
}

const SOURCES = ['manual', 'clawhub', 'github', 'arxiv'] as const

export function SignalInject({ onSubmit }: SignalInjectProps) {
  const [open, setOpen] = useState(false)
  const [title, setTitle] = useState('')
  const [source, setSource] = useState<(typeof SOURCES)[number]>('manual')
  const [summary, setSummary] = useState('')
  const [error, setError] = useState<string | null>(null)
  const [ok, setOk] = useState<string | null>(null)
  const [sending, setSending] = useState(false)

  const submit: FormEventHandler<HTMLFormElement> = async (event) => {
    event.preventDefault()
    const normalized = title.trim()
    if (!normalized) {
      setError('Titel is verplicht')
      setOk(null)
      return
    }

    setSending(true)
    setError(null)
    setOk(null)

    try {
      await onSubmit({
        title: normalized,
        summary: summary.trim() || undefined,
        source
      })
      setTitle('')
      setSummary('')
      setSource('manual')
      setOk('Signaal verstuurd')
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Versturen mislukt')
    } finally {
      setSending(false)
    }
  }

  return (
    <section>
      <button className="inject-toggle" onClick={() => setOpen((v) => !v)} type="button">
        {open ? 'Signal Inject sluiten' : 'Signal Inject openen'}
      </button>

      {open ? (
        <form className="inject-panel" onSubmit={submit}>
          <label htmlFor="inject-title">Titel</label>
          <input id="inject-title" value={title} onChange={(e) => setTitle(e.target.value)} />

          <label htmlFor="inject-source">Bron</label>
          <select id="inject-source" value={source} onChange={(e) => setSource(e.target.value as (typeof SOURCES)[number])}>
            {SOURCES.map((item) => (
              <option key={item} value={item}>
                {item}
              </option>
            ))}
          </select>

          <label htmlFor="inject-summary">Tekst</label>
          <textarea id="inject-summary" value={summary} onChange={(e) => setSummary(e.target.value)} />

          <button type="submit" disabled={sending}>
            {sending ? 'Versturen...' : 'Verstuur'}
          </button>

          {error ? <div className="error">{error}</div> : null}
          {ok ? <div className="ok">{ok}</div> : null}
        </form>
      ) : null}
    </section>
  )
}
