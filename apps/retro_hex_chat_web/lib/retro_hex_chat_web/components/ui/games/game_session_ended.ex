defmodule RetroHexChatWeb.Components.UI.GameSessionEnded do
  @moduledoc """
  Game session ended component — shows session summary after a game session closes.

  Displays the connection diagram with peer info, game result (score + winner),
  session duration, and the reason the session ended.

  ## Usage

      <.game_session_ended
        nickname="you"
        peer="alice"
        reason="Game over."
        duration={185}
        game_name="Hex Pong"
        game_result={%{"score" => %{"p1" => 11, "p2" => 7}, "winner" => 1}}
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
  attr :game_name, :string, default: nil, doc: "Human-readable game name"
  attr :game_result, :map, default: nil, doc: "Result map with score and winner keys"
  attr :local_info, :map, default: %{}
  attr :peer_info, :map, default: %{}
  attr :class, :string, default: nil
  attr :rest, :global

  @spec game_session_ended(map()) :: Phoenix.LiveView.Rendered.t()
  def game_session_ended(assigns) do
    assigns =
      assigns
      |> assign(:formatted_duration, format_duration(assigns.duration))
      |> assign(:score, extract_score(assigns.game_result))

    ~H"""
    <.window
      class={classes(["w-full max-w-[600px]", @class])}
      data-testid="game-session-ended"
      {@rest}
    >
      <.window_title_bar title="Game Session" controls={[:close]}>
        <:icon><Icons.icon_joystick class="w-4 h-4" /></:icon>
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

        <%!-- Game result card --%>
        <div :if={@score} class="shadow-retro-field bg-white p-4 text-center space-y-2">
          <p class="text-xs font-bold uppercase tracking-wider text-muted-foreground">
            Final Score
          </p>
          <div :if={@game_name} class="text-xs text-muted-foreground">{@game_name}</div>
          <div class="flex items-center justify-center gap-4 text-sm">
            <span class={[
              "font-bold",
              @score.winner == 1 && "text-foreground",
              @score.winner != 1 && "text-muted-foreground"
            ]}>
              P1 {@score.p1}
            </span>
            <span class="text-muted-foreground">&times;</span>
            <span class={[
              "font-bold",
              @score.winner == 2 && "text-foreground",
              @score.winner != 2 && "text-muted-foreground"
            ]}>
              {@score.p2} P2
            </span>
          </div>
          <div :if={@score.winner}>
            <.badge variant="default">
              Player {@score.winner} wins!
            </.badge>
          </div>
        </div>

        <%!-- Session ended notice --%>
        <div class="shadow-retro-field bg-white p-4 text-center space-y-2">
          <div class="flex items-center justify-center gap-2">
            <Icons.icon_close class="w-4 h-4 text-muted-foreground" />
            <span class="text-sm font-bold">Session Ended</span>
          </div>
          <p class="text-xs text-muted-foreground">{@reason}</p>
          <div :if={@formatted_duration} class="pt-1">
            <.badge variant="outline">
              <Icons.icon_clock class="w-3 h-3 mr-1" /> Duration: {@formatted_duration}
            </.badge>
          </div>
        </div>
      </.window_body>
    </.window>
    """
  end

  @spec extract_score(map() | nil) ::
          %{p1: integer(), p2: integer(), winner: integer() | nil} | nil
  defp extract_score(nil), do: nil

  defp extract_score(result) when is_map(result) do
    score = result["score"] || %{}
    p1 = score["p1"] || 0
    p2 = score["p2"] || 0
    winner = result["winner"]

    %{p1: p1, p2: p2, winner: winner}
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
        "#{hours}h #{String.pad_leading(to_string(minutes), 2, "0")}m #{String.pad_leading(to_string(secs), 2, "0")}s"

      minutes > 0 ->
        "#{minutes}m #{String.pad_leading(to_string(secs), 2, "0")}s"

      true ->
        "#{secs}s"
    end
  end
end
