defmodule RetroHexChatWeb.Components.UI.ArcadeSessionLink do
  @moduledoc """
  Arcade session link component for the showcase design system.

  Displays an "Open Arcade" link for arcade game sessions within chat messages.

  ## Usage

      <.arcade_session_link href="/arcade/abc123/tetris" />
  """
  use RetroHexChatWeb.Component

  @doc "Renders an arcade session link."
  attr :href, :string, required: true, doc: "URL to the arcade session"
  attr :class, :any, default: nil
  attr :rest, :global

  @spec arcade_session_link(map()) :: Phoenix.LiveView.Rendered.t()
  def arcade_session_link(assigns) do
    ~H"""
    <span {@rest}>
      {gettext("* Arcade session ready!")}
      <a href={@href} class={classes(["underline", @class])} target="_blank" rel="noopener noreferrer">
        {gettext("Open Arcade")}
      </a>
    </span>
    """
  end
end
