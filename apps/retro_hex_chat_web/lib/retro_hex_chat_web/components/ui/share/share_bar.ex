defmodule RetroHexChatWeb.Components.UI.ShareBar do
  @moduledoc false
  use RetroHexChatWeb.Component

  import RetroHexChatWeb.Components.UI.Button

  alias RetroHexChatWeb.Icons

  attr :url, :string, default: nil, doc: "the minted share URL, once there is one"
  attr :available, :boolean, default: true, doc: "false when the viewer may not mint one"
  attr :on_share, :string, required: true

  attr :on_revoke, :string,
    default: nil,
    doc: "event that closes the link; omitted where the viewer may not close it"

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

      <%!-- The field stays, because an address you can see and select is the
            thing that works when the clipboard is refused. The button beside it
            copies without a round trip: the text is already here, so a surface
            in a tab of its own needs nothing from the chat to do it. --%>
      <input
        :if={@url}
        id={@url && "share-url-#{Base.url_encode64(@url, padding: false)}"}
        type="text"
        readonly
        value={@url}
        class="shadow-retro-field min-w-0 flex-1 px-1 py-[2px] text-sm"
        data-testid="share-url"
        aria-label={dgettext("share", "Share link")}
      />
      <.button
        :if={@url}
        type="button"
        id={@url && "share-copy-#{Base.url_encode64(@url, padding: false)}"}
        phx-hook="CopyValueHook"
        data-copy-from={"share-url-#{Base.url_encode64(@url || "", padding: false)}"}
        data-copied-label={dgettext("share", "Copied!")}
        data-testid="share-copy"
      >
        <:icon><Icons.icon_copy class="h-4 w-4" /></:icon>
        {dgettext("share", "Copy")}
      </.button>

      <%!-- Undoing the share, which until now had no way in at all: the domain
            could close a link and nothing on any screen ever asked it to. It
            closes the address and leaves the room alone — the people already
            inside stay inside, and the next Share hands out a new one. --%>
      <.button
        :if={@url && @on_revoke}
        type="button"
        variant="outline"
        phx-click={@on_revoke}
        phx-target={@target}
        data-confirm={dgettext("share", "Stop this link from working? The room stays open.")}
        data-testid="share-revoke"
      >
        <:icon><Icons.icon_close class="h-4 w-4" /></:icon>
        {dgettext("share", "Revoke")}
      </.button>
    </div>
    """
  end
end
