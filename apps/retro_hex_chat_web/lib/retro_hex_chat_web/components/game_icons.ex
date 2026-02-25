defmodule RetroHexChatWeb.Components.GameIcons do
  @moduledoc """
  Deprecated: Use `RetroHexChatWeb.Icons.Games` directly.
  This module delegates to the Icons.Games submodule for backward compatibility.
  """

  defdelegate game_icon(assigns), to: RetroHexChatWeb.Icons.Games
end
