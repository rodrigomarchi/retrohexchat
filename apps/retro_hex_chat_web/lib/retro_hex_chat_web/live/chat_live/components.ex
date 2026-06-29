defmodule RetroHexChatWeb.ChatLive.Components do
  @moduledoc """
  Namespace for the stateful `Phoenix.LiveComponent` islands of the chat screen.

  Each island owns its own state, events and (where relevant) streams. The
  parent `RetroHexChatWeb.App.ChatLive` passes minimal identity/context — see
  `RetroHexChatWeb.ChatLive.ChatContext` — plus callbacks, and routes PubSub
  updates to the islands via `send_update/3` or standardized messages.

  The components themselves live in `RetroHexChatWeb.ChatLive.Components.*`
  submodules; this module exists only to anchor the namespace.
  """
end
