defmodule RetroHexChatWeb.Components.UI.AccountStatus do
  @moduledoc """
  Account identity and away quick-action widget for app shell status surfaces.
  """
  use RetroHexChatWeb.Component

  alias RetroHexChatWeb.Icons

  @doc "Renders the account status widget with an optional away toggle."
  attr :nickname, :string, required: true
  attr :account_state, :atom, default: :guest, values: [:guest, :identified, :away]
  attr :away, :boolean, default: false
  attr :on_click, :any, default: nil
  attr :on_away_toggle, :any, default: nil
  attr :class, :string, default: nil

  @spec account_status(map()) :: Phoenix.LiveView.Rendered.t()
  def account_status(assigns) do
    ~H"""
    <span class={classes(["inline-flex items-center gap-retro-2 min-w-0", @class])}>
      <button
        :if={@on_click}
        type="button"
        class="inline-flex items-center gap-retro-2 min-w-0 bg-transparent"
        phx-click={@on_click}
        title={dgettext("ui", "Open Account")}
        aria-label={dgettext("ui", "Open Account")}
        data-testid="status-bar-account-widget"
      >
        <Icons.icon_status_user class="w-3 h-3 shrink-0" />
        <span class="truncate text-xs">{account_label(@nickname, @account_state)}</span>
      </button>
      <span :if={!@on_click} class="inline-flex items-center gap-retro-2 min-w-0">
        <Icons.icon_status_user class="w-3 h-3 shrink-0" />
        <span class="truncate text-xs">{account_label(@nickname, @account_state)}</span>
      </span>
      <button
        :if={@on_away_toggle}
        type="button"
        class="inline-flex items-center justify-center w-[18px] h-[18px] shrink-0 bg-transparent"
        phx-click={@on_away_toggle}
        title={away_toggle_label(@away)}
        aria-label={away_toggle_label(@away)}
        data-testid="status-bar-away-toggle"
      >
        <Icons.icon_btn_dnd_active :if={@away} class="w-3 h-3" />
        <Icons.icon_btn_dnd :if={!@away} class="w-3 h-3" />
      </button>
    </span>
    """
  end

  @spec account_label(String.t(), atom()) :: String.t()
  defp account_label(nickname, state), do: "#{nickname} · #{account_state_label(state)}"

  @spec account_state_label(atom()) :: String.t()
  defp account_state_label(:away), do: dgettext("ui", "Away")
  defp account_state_label(:identified), do: dgettext("ui", "Identified")
  defp account_state_label(_), do: dgettext("ui", "Guest")

  @spec away_toggle_label(boolean()) :: String.t()
  defp away_toggle_label(true), do: dgettext("ui", "Back")
  defp away_toggle_label(false), do: dgettext("ui", "Set Away")
end
