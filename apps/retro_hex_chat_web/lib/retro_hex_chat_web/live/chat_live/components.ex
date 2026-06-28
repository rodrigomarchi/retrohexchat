defmodule RetroHexChatWeb.ChatLive.Components do
  @moduledoc """
  Namespace for the stateful `Phoenix.LiveComponent` islands that the ChatLive
  migration extracts out of the monolithic `RetroHexChatWeb.App.ChatLive`.

  Each island owns its own state, events and (where relevant) streams. The
  parent orchestrator passes minimal identity/context — see
  `RetroHexChatWeb.ChatLive.ChatContext` — plus callbacks, and routes PubSub
  updates to the islands via `send_update/3` or standardized messages.

  This module is intentionally a documentation anchor. The components live in
  `RetroHexChatWeb.ChatLive.Components.*` submodules as they are migrated.

  See `docs/plans/01-chat-live-orchestrator.md`.
  """
end
