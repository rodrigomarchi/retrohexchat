defmodule RetroHexChatWeb.Components.UI.GroupCall.PermissionNotice do
  @moduledoc """
  Permission warning block for the channel conference pre-join media preview.
  """
  use RetroHexChatWeb.Component

  alias RetroHexChatWeb.Icons

  attr :testid, :string, default: "group-call-prejoin-warning"
  attr :retry_testid, :string, default: "group-call-prejoin-retry"

  @spec permission_notice(map()) :: Phoenix.LiveView.Rendered.t()
  def permission_notice(assigns) do
    ~H"""
    <div
      class="mt-1 hidden items-start gap-1 border border-warning bg-surface px-1 py-1 text-[10px] text-warning"
      data-group-call-prejoin-warning
      data-testid={@testid}
    >
      <Icons.icon_warning class="mt-[1px] h-3 w-3 shrink-0" />
      <span data-group-call-prejoin-warning-text></span>
      <button
        type="button"
        class="ml-auto inline-flex h-5 shrink-0 items-center gap-1 border border-border bg-surface px-1 text-[10px] font-bold shadow-retro-raised"
        data-group-call-prejoin-retry
        data-testid={@retry_testid}
      >
        <Icons.icon_btn_refresh class="h-3 w-3" />
        {dgettext("group_call", "Retry")}
      </button>
    </div>
    """
  end
end
