defmodule RetroHexChatWeb.Components.UI.ShareBar do
  @moduledoc false
  use RetroHexChatWeb.Component

  import RetroHexChatWeb.Components.UI.Button

  alias RetroHexChatWeb.Icons

  attr :url, :string, default: nil, doc: "the minted share URL, once there is one"
  attr :available, :boolean, default: true, doc: "false when the viewer may not mint one"
  attr :on_share, :string, required: true
  attr :target, :any, default: nil
  attr :class, :any, default: nil

  @spec share_bar(map()) :: Phoenix.LiveView.Rendered.t()
  def share_bar(assigns) do
    ~H"""
    <div class={classes(["flex items-center gap-2", @class])} data-testid="share-bar">
      <.button
        :if={is_nil(@url)}
        type="button"
        phx-click={@on_share}
        phx-target={@target}
        disabled={!@available}
        data-testid="share-create"
      >
        <:icon><Icons.icon_btn_link class="h-4 w-4" /></:icon>
        {dgettext("share", "Share")}
      </.button>

      <span :if={is_nil(@url) and !@available} class="text-muted-foreground text-sm">
        {dgettext("share", "Register your nickname to share a link.")}
      </span>

      <%!-- A readonly field rather than a copy button: the copy event is
            handled by a chat-only hook, and this bar has to work the same in a
            tab that has no chat in it. --%>
      <input
        :if={@url}
        type="text"
        readonly
        value={@url}
        class="shadow-retro-field min-w-0 flex-1 px-1 py-[2px] text-sm"
        data-testid="share-url"
        aria-label={dgettext("share", "Share link")}
      />
    </div>
    """
  end
end
