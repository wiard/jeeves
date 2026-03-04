type JeevesVoiceProps = {
  message: string
}

export function JeevesVoice({ message }: JeevesVoiceProps) {
  return <div className="jeeves-voice">"{message}"</div>
}
