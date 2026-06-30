# Lobby — Chat Island

> Pré-requisito de leitura: [`00-OVERVIEW.md`](00-OVERVIEW.md) (arquitetura + contratos
> C1/C2/C3) e `../STATEFUL-COMPONENT-PLAYBOOK.md`.

## Objetivo

Extrair a feature de chat do lobby para `RetroHexChatWeb.App.LobbyLive.Components.ChatIsland`,
dona de `messages` e do envio. Por ser dona do **sink de mensagens de sistema**, este
plano **estabelece o contrato C1** que game/file/media vão usar.

## Classificação para execução (agentes)

- **Tier:** 🟢 Mecânico (mais simples; vai primeiro de propósito p/ travar C1).
- **Dependências:** nenhuma entrada. Habilita C1 para 02/03/04.
- **Componente de referência:** `ChatLive.Components.*` simples + "PubSub notification
  queue (kick, plano 48)" para o ownership da lista alimentada por vários produtores.
- **Abordagem:** ilha dona de `messages`; `send_message` via adapter; produtores
  externos enfileiram via `send_update(..., system_message:)`.
- **Gotchas:** `send_update` é assíncrono sob LiveViewTest (flush com `render(view)`,
  playbook §2); `messages` é lista pequena e churny → passthrough/append, **sem
  stream** (igual conversations).
- **Validação:** `make ci` 9/9 + `chat-lobby.spec.ts` (fluxos de chat).

## Código atual

- Render: `components/ui/lobby/universal_lobby.ex:207-219` (janela `chat` →
  `<.chat_panel messages={@messages} />`).
- Panel (stateless): `components/ui/lobby/chat_panel.ex`.
- Assign: `messages` (`lobby_live.ex:659`).
- Evento UI: `send_message` (`lobby_live.ex:292`) → `Lobby.send_message`, on ok
  `push_event("p2p_lobby_message_sent", %{form_id: "lobby-chat-form"})` (`:295`).
- Info PubSub: `lobby_message` (`lobby_live.ex:134`) → append em `messages`.
- **Produtores de mensagem de sistema (o sink):** media `lobby_media_device_fallback`
  (`:432`) e `lobby_media_error` (`:437`); file `ft_completed` (`:504`); game
  `lobby_game_response` recusado (`:163`); conexão `lobby_failed` (`:283`).

## Técnica

LiveComponent statefull, montado dentro da janela `chat` em `universal_lobby.ex`.
Dono de `messages`. Append local em `lobby_message` (via adapter do pai →
`send_update`) e em `{:system_message, txt}` (contrato C1). Lista pequena/churny →
**passthrough + append, sem stream** (regra do playbook §1d: stream só para listas
grandes/append-pesadas; chat do lobby é curto e a UI re-renderiza barato).

`send_message` continua um adapter de string no pai (precisa do contexto `Lobby` +
session), que após o envio faz `send_update` (ou já está ok porque o append vem pelo
PubSub `lobby_message` ecoado). Manter o `push_event("p2p_lobby_message_sent", ...)`
de reset de form.

### Contrato C1 (estabelecido aqui)

```elixir
# Em QUALQUER ilha/pai que hoje faz update(:messages, &[sys | &1]):
send_update(LobbyLive.Components.ChatIsland, id: "lobby-chat", system_message: txt)

# Na ilha:
def update(%{system_message: txt}, socket), do
  {:ok, update(socket, :messages, &(&1 ++ [system_msg(txt)]))}
end
```

## Tasks

- [ ] Criar `Components.ChatIsland` (raiz `<div id={@id}>` estável; `@id` no mount).
- [ ] Mover render de `chat_panel` para dentro da ilha; janela `chat` passa a montar
      o `live_component` (sempre montado, não em `:if`).
- [ ] Ilha dona de `messages`; `update/2` trata `{:system_message, txt}` (C1) e o
      append de `lobby_message`.
- [ ] Pai: `lobby_message` (info) vira adapter → `send_update` na ilha; remover o
      assign `messages` do pai.
- [ ] Converter os 5 produtores de mensagem de sistema (media/file/game/conexão) para
      `send_update(ChatIsland, system_message:)`. (Enquanto media/file/game ainda
      estão no pai, o `send_update` parte do pai; quando virarem ilhas, partem delas.)
- [ ] `send_message` permanece adapter de string no pai; manter reset de form.
- [ ] Teste de unidade: render aberto, append via `update({:system_message})`,
      id/data-testid. Interação real fica no E2E.

## Armadilhas cruzadas (verificadas contra o código)

- ✅ **Form de chat é o padrão seguro:** `phx-submit="send_message"` (string) +
  `name="content"` (`chat_panel.ex:32,39`) → `render_submit` funciona; NÃO há trap de
  `JS.push(value:)`. Pode testar o submit por `render_submit` no teste de unidade.
- ✅ Zero `fixed inset-0` → sem bloqueio modal-in-modal.
- ⚠️ **C1 via `send_update` é assíncrono sob LiveViewTest** (playbook §2): ao testar
  que uma mensagem de sistema chega, faça flush com `render(view)` antes do assert.
- Esta ilha NÃO usa C2 (não tem badge na taskbar) → não há risco do swallow da
  linha 228. Mas é a DONA do `update({:system_message})` que os outros chamam.

## Validação

- [ ] Enviar mensagem aparece na janela chat; form reseta (`p2p_lobby_message_sent`).
- [ ] Mensagem do peer (PubSub `lobby_message`) aparece sem re-render do resto do
      desktop (change-tracking isola a ilha).
- [ ] Uma mensagem de sistema de cada produtor (ex.: device fallback, ft_completed,
      game recusado, lobby_failed) cai na janela chat via C1.
- [ ] `make ci` 9/9; `chat-lobby.spec.ts` verde (ou baseline comprovado via `git stash`).

## Prompt de execução

Leia OVERVIEW + playbook. Mantenha a UI; mova ownership de `messages` para a ilha.
Estabeleça o helper C1 (`send_update(... system_message:)`) e converta os 5
produtores. Sem stream. Valide com `make ci` + E2E de chat.

## Progress Log

- 2026-06-30: Planejado. Não iniciado.
