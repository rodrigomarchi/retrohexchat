defmodule RetroHexChatWeb.ChatLive.Components.UserModesDialog do
  @moduledoc """
  The User Modes window body: the IRC user modes on your own connection.

  Purely a view over the session — `wallops_enabled` is supplied by the parent
  as a template attr, and the form is handled on the parent's `UserModesEvents`,
  which runs `/umode`.
  """
  use RetroHexChatWeb, :live_component

  import RetroHexChatWeb.Components.UI.UserModesDialog

  use RetroHexChatWeb.ChatLive.Components.DialogIsland,
    id: "user-modes-dialog",
    initial: %{wallops_enabled: false},
    known: [:wallops_enabled]

  @impl true
  @spec render(map()) :: Phoenix.LiveView.Rendered.t()
  def render(assigns) do
    ~H"""
    <div id={"#{@id}-mount"} class="contents">
      <.user_modes_panel id={@id} wallops_enabled={@wallops_enabled} />
    </div>
    """
  end
end
