# Fase 4 — `p2p_session_live` e `game_session_live`

Os ofensores nº 2 e nº 3 são **arquivos monolíticos** (não decompostos como o
`ChatLive`). Esta fase aplica duas técnicas: **`streams`** para as coleções de
mensagens e **decomposição em hooks/components** para o tamanho.

## 4.1 `streams` para mensagens em `p2p_session_live`

### Problema atual

`live/app/p2p_session_live.ex` acumula mensagens com **append em lista**, que
reenvia a coleção inteira a cada render:

```elixir
# live/app/p2p_session_live.ex:782
{:noreply, assign(socket, messages: socket.assigns.messages ++ [msg])}

# também em :125, :152, :238, :283, :815, :1201 — mesmo anti-padrão
```

A comunidade recomenda `streams` para coleções dinâmicas: *"DOM patching
eficiente para coleções grandes sem reenviar a lista inteira a cada vez"*. O
`ChatLive` já faz isso — aqui replicamos o padrão dele.

### Mudanças

1. **mount/3:** trocar `assign(socket, messages: [])` por
   `stream(socket, :messages, [])` (com `stream_configure` se precisar de
   `dom_id` custom, como em `live/chat_live/helpers/messages.ex`).
2. **Cada ponto de append** (`:125, :152, :238, :283, :782, :815, :1201`) passa
   de `assign(messages: ... ++ [msg])` para `stream_insert(socket, :messages, msg)`.
3. **Template** `live/app/p2_p_session_live.html.heex`: trocar o laço sobre
   `@messages` por `phx-update="stream"` + `:for={{dom_id, msg} <- @streams.messages}`,
   espelhando `live/app/chat_live.html.heex:219`.
4. **Garantir `id` estável** por mensagem (cada `msg` precisa de `:id` único,
   como já fazem as factories em `live/chat_live/helpers/messages.ex`).

> Ganho: memória por sessão P2P e latência de diff caem; deixa de reenviar todo
> o histórico a cada nova mensagem.

## 4.2 Decompor `p2p_session_live` (1.377 linhas)

Aplicar a **mesma estratégia de hooks** que já existe no `ChatLive`
(`attach_hook` + módulos `*_events`). Sugestão de fatiamento por responsabilidade:

| Módulo proposto | Responsabilidade | Eventos/Info alvo |
|---|---|---|
| `P2PSessionLive.SignalingEvents` | Sinalização WebRTC (offer/answer/ICE) | `webrtc_*`, estado de conexão |
| `P2PSessionLive.CallEvents` | Estado de chamada (áudio/vídeo, mute) | `call`, `capabilities`, `media_*` |
| `P2PSessionLive.MessageEvents` | Mensagens (já em `streams` após 4.1) | enviar/receber mensagem |
| `P2PSessionLive.PresenceHandlers` | `peer_online`, `peer_info`, inatividade | `handle_info` de presença/timeout |

E diálogos da sessão P2P (se houver, ex.: file transfer, media controls) seguem
o mesmo padrão `LiveComponent` da Fase 1.

## 4.3 Decompor `game_session_live` (822 linhas)

Mesma abordagem: extrair `*_events` por responsabilidade (estado de jogo,
turnos, sincronização P2P) e mover lógica de regra de jogo para o contexto
`RetroHexChat.P2P`/contexto de jogos. Avaliar `streams` para logs/eventos de
jogo se houver coleção crescente.

## Sequenciamento da Fase 4

1. `streams` em `p2p_session_live` (4.1) — isolado, alto ganho, baixo risco.
2. Decomposição de `p2p_session_live` (4.2) — mecânica, guiada por compilador.
3. Decomposição de `game_session_live` (4.3).

> Esta fase é **independente** das Fases 1–3 (mexe em outros arquivos) e pode
> ser feita em paralelo por outra pessoa, ou adiada sem bloquear o trabalho no
> `ChatLive`.

## Critérios de pronto (Fase 4)

- [ ] `p2p_session_live` usa `streams` para mensagens (nenhum `messages ++ [..]`
      remanescente).
- [ ] `p2p_session_live` decomposto em módulos `*_events` via `attach_hook`.
- [ ] `game_session_live` decomposto de forma análoga.
- [ ] `make ci` verde (incluindo E2E de P2P/jogos).
