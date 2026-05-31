defmodule RetroHexChatWeb.Components.UI.P2PSessionEnded do
  @moduledoc """
  P2P session ended component — shows session summary after a session closes.

  Displays the connection diagram with peer info, session duration,
  and the reason the session ended. No chat, no action buttons.

  ## Usage

      <.p2p_session_ended
        nickname="you"
        peer="alice"
        reason="Call ended."
        duration={185}
        local_info=%{browser: "Chrome 145.0", os: "macOS"}
        peer_info=%{browser: "Firefox 148.0", os: "Linux"}
      />
  """
  use RetroHexChatWeb.Component

  import RetroHexChatWeb.Components.UI.Window
  import RetroHexChatWeb.Components.UI.P2PConnectionDiagram
  import RetroHexChatWeb.Components.UI.Badge

  alias RetroHexChatWeb.Icons

  attr :nickname, :string, required: true
  attr :peer, :string, required: true
  attr :reason, :string, required: true
  attr :duration, :integer, default: nil, doc: "Session duration in seconds"
  attr :local_info, :map, default: %{}
  attr :peer_info, :map, default: %{}
  attr :class, :string, default: nil
  attr :rest, :global

  @spec p2p_session_ended(map()) :: Phoenix.LiveView.Rendered.t()
  def p2p_session_ended(assigns) do
    assigns = assign(assigns, :formatted_duration, format_duration(assigns.duration))

    ~H"""
    <.window
      class={classes(["w-full max-w-[600px]", @class])}
      data-testid="p2p-session-ended"
      {@rest}
    >
      <.window_title_bar title={gettext("P2P Connection")} controls={[:close]}>
        <:icon><Icons.icon_p2p class="w-4 h-4" /></:icon>
      </.window_title_bar>

      <.window_body class="p-retro-8 space-y-retro-8">
        <%!-- Connection diagram with peer info (closed state) --%>
        <.p2p_connection_diagram
          nickname={@nickname}
          peer_nick={@peer}
          peer_online={false}
          session_status="closed"
          local_info={@local_info}
          peer_info={@peer_info}
        />

        <%!-- Session ended notice --%>
        <div class="shadow-retro-field bg-white p-4 text-center space-y-2">
          <div class="flex items-center justify-center gap-2">
            <Icons.icon_close class="w-4 h-4 text-muted-foreground" />
            <span class="text-sm font-bold">{gettext("Session Ended")}</span>
          </div>
          <p class="text-xs text-muted-foreground">{@reason}</p>
          <div :if={@formatted_duration} class="pt-1">
            <.badge variant="outline">
              <Icons.icon_clock class="w-3 h-3 mr-1" /> {gettext("Duration: %{duration}",
                duration: @formatted_duration
              )}
            </.badge>
          </div>
        </div>
      </.window_body>
    </.window>
    """
  end

  @spec format_duration(integer() | nil) :: String.t() | nil
  defp format_duration(nil), do: nil
  defp format_duration(0), do: nil

  defp format_duration(seconds) when is_integer(seconds) do
    hours = div(seconds, 3600)
    minutes = div(rem(seconds, 3600), 60)
    secs = rem(seconds, 60)

    cond do
      hours > 0 ->
        gettext("%{hours}h %{minutes}m %{seconds}s",
          hours: hours,
          minutes: String.pad_leading(to_string(minutes), 2, "0"),
          seconds: String.pad_leading(to_string(secs), 2, "0")
        )

      minutes > 0 ->
        gettext("%{minutes}m %{seconds}s",
          minutes: minutes,
          seconds: String.pad_leading(to_string(secs), 2, "0")
        )

      true ->
        gettext("%{seconds}s", seconds: secs)
    end
  end
end
