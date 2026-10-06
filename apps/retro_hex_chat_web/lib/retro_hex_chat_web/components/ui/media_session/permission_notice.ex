defmodule RetroHexChatWeb.Components.UI.MediaSession.PermissionNotice do
  @moduledoc """
  The camera/microphone permission warning under a media preview — the group
  call's pre-join and the P2P waiting room share it.

  Everything inside is written by the browser preview controller
  (`lib/group_call/prejoin.js`) — the message text and whether the block is
  shown at all — found through `data-<prefix>-warning`, `-warning-text` and
  `-retry`. The server renders the shell once and then stays out of it:
  without `phx-update="ignore"` the next LiveView patch of the preview would
  restore this template and erase the warning that had just been raised.
  """
  use RetroHexChatWeb.Component

  import RetroHexChatWeb.Components.UI.ToolButton

  alias RetroHexChatWeb.Icons

  attr :prefix, :string,
    default: "group-call-prejoin",
    doc: "the controller's data-attribute prefix"

  attr :id, :string, default: "group-call-prejoin-warning-notice"
  attr :testid, :string, default: "group-call-prejoin-warning"
  attr :retry_testid, :string, default: "group-call-prejoin-retry"
  attr :retry_label, :string, default: nil

  @spec permission_notice(map()) :: Phoenix.LiveView.Rendered.t()
  def permission_notice(assigns) do
    assigns =
      assigns
      |> assign(:notice_attrs, [{"data-#{assigns.prefix}-warning", true}])
      |> assign(:text_attrs, [{"data-#{assigns.prefix}-warning-text", true}])
      |> assign(:retry_attrs, [{"data-#{assigns.prefix}-retry", true}])
      |> assign_new(:retry_text, fn -> assigns.retry_label || dgettext("group_call", "Retry") end)

    ~H"""
    <div
      id={@id}
      phx-update="ignore"
      class="mt-1 hidden items-start gap-1 border border-warning bg-surface px-1 py-1 text-[10px] text-warning"
      data-testid={@testid}
      {@notice_attrs}
    >
      <Icons.icon_warning class="mt-[1px] h-3 w-3 shrink-0" />
      <span {@text_attrs}></span>
      <.tool_button
        label={@retry_text}
        caption={@retry_text}
        size="xs"
        class="ml-auto text-[10px] text-foreground"
        data-testid={@retry_testid}
        {@retry_attrs}
      >
        <Icons.icon_btn_refresh class="h-3 w-3" />
      </.tool_button>
    </div>
    """
  end
end
