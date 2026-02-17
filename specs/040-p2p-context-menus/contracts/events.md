# LiveView Event Contracts: P2P Context Menu Actions

**Feature**: 040-p2p-context-menus
**Date**: 2026-02-17

## Nicklist Context Menu Events

### `context_p2p`

**Trigger**: Click "Sessão P2P" in nicklist context menu
**Params**: `%{"nick" => target_nick}`
**Preconditions**: Viewer is identified, target is registered, target is not self
**Action**: Create P2P session (type: `generic`), send PM invite, navigate to `/p2p/:token`
**Success**: Close menu, stream system message, `push_navigate` to lobby
**Error**: Close menu, flash error message

### `context_call`

**Trigger**: Click "Chamada de Áudio" in nicklist context menu
**Params**: `%{"nick" => target_nick}`
**Preconditions**: Same as `context_p2p`
**Action**: Create P2P session (type: `audio_call`), send PM invite, navigate to `/p2p/:token`
**Success/Error**: Same as `context_p2p`

### `context_video_call`

**Trigger**: Click "Chamada de Vídeo" in nicklist context menu
**Params**: `%{"nick" => target_nick}`
**Preconditions**: Same as `context_p2p`
**Action**: Create P2P session (type: `video_call`), send PM invite, navigate to `/p2p/:token`
**Success/Error**: Same as `context_p2p`

### `context_sendfile`

**Trigger**: Click "Enviar Arquivo" in nicklist context menu
**Params**: `%{"nick" => target_nick}`
**Preconditions**: Same as `context_p2p`
**Action**: Create P2P session (type: `file_transfer`), send PM invite, navigate to `/p2p/:token`
**Success/Error**: Same as `context_p2p`

## Chat Area Context Menu Events

### `ctx_chat_p2p`

**Trigger**: Click "Sessão P2P" in chat nick context menu
**Params**: `%{"nick" => target_nick}`
**Preconditions**: Same as nicklist variant
**Action**: Same as `context_p2p`
**Success/Error**: Uses `close_chat_context_menu/1` instead of `close_context_menu/1`

### `ctx_chat_call`

**Trigger**: Click "Chamada de Áudio" in chat nick context menu
**Params**: `%{"nick" => target_nick}`
**Action**: Same as `context_call`

### `ctx_chat_video_call`

**Trigger**: Click "Chamada de Vídeo" in chat nick context menu
**Params**: `%{"nick" => target_nick}`
**Action**: Same as `context_video_call`

### `ctx_chat_sendfile`

**Trigger**: Click "Enviar Arquivo" in chat nick context menu
**Params**: `%{"nick" => target_nick}`
**Action**: Same as `context_sendfile`

## Shared Event Handler Flow

All 8 event handlers follow the same internal flow:

```
1. Extract nick from params
2. Close context menu (nicklist or chat variant)
3. Build P2P context from socket.assigns.session
4. Call P2p.do_execute(nick, session_type, context)
5. On {:ok, :ui_action, :p2p_invite, payload}:
   a. Send PM invitation to target (via Service.send_private_message)
   b. Stream system message to initiator
   c. push_navigate to /p2p/#{token}
6. On {:error, message}:
   a. Show flash error with message
```

## Error Messages (from P2p.do_execute/3)

| Error Condition | Message |
|----------------|---------|
| Viewer not identified | "Voce precisa estar identificado para usar /p2p." |
| Target is self | (prevented at UI level — items disabled) |
| Target not registered | "Usuario '#{nick}' nao esta registrado." |
| Session creation failure | Generic error from P2P.create_session |
| Rate limited | Error with wait time from RateLimit |
