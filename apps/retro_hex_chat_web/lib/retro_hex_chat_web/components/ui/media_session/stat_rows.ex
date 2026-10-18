defmodule RetroHexChatWeb.Components.UI.MediaSession.StatRows do
  @moduledoc """
  One measured reading in a diagnostics list: its label on the left, its value
  on the right, two readings to a line inside the `grid grid-cols-2` `<dl>` of a
  `media_session_diagnostics_group`.

  The P2P session and the group call read the same kinds of figures — bitrate,
  loss, codecs, whether a channel is carrying anything — so they read them in
  the same row. The words for a channel's state come from the caller, in the
  caller's own gettext domain.
  """
  use RetroHexChatWeb.Component

  alias RetroHexChatWeb.Icons

  attr :label, :string, required: true
  attr :value, :any, required: true
  attr :icon, :atom, default: nil
  attr :tip, :string, default: nil, doc: "what the figure means; a tooltip, or a line under it"
  attr :info_open, :boolean, default: false, doc: "draw the tip as a line under the reading"

  @doc "A labelled reading."
  @spec stat_row(map()) :: Phoenix.LiveView.Rendered.t()
  def stat_row(assigns) do
    ~H"""
    <div class="flex min-w-0 flex-col">
      <div class="flex items-center justify-between gap-2" title={@tip}>
        <.stat_label label={@label} icon={@icon} />
        <dd class="min-w-0 truncate font-bold tabular-nums">{@value}</dd>
      </div>
      <p :if={@info_open && @tip} class="text-muted-foreground text-[10px] leading-tight">{@tip}</p>
    </div>
    """
  end

  attr :label, :string, required: true
  attr :active, :boolean, required: true
  attr :icon, :atom, default: nil
  attr :active_label, :string, required: true
  attr :idle_label, :string, required: true

  @doc "Whether a channel is carrying anything: the word in success colour, or muted."
  @spec stat_status(map()) :: Phoenix.LiveView.Rendered.t()
  def stat_status(assigns) do
    ~H"""
    <div class="flex min-w-0 items-center justify-between gap-2">
      <.stat_label label={@label} icon={@icon} />
      <dd class={[
        "shrink-0 font-bold",
        if(@active, do: "text-success", else: "text-muted-foreground")
      ]}>
        {if @active, do: @active_label, else: @idle_label}
      </dd>
    </div>
    """
  end

  attr :label, :string, required: true
  attr :icon, :atom, default: nil

  defp stat_label(assigns) do
    ~H"""
    <dt class="text-muted-foreground flex min-w-0 items-center gap-1">
      <span :if={@icon} class="inline-flex shrink-0">
        {apply(Icons, @icon, [%{class: "w-3.5 h-3.5"}])}
      </span>
      <span class="truncate">{@label}</span>
    </dt>
    """
  end
end
