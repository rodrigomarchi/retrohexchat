defmodule RetroHexChatWeb.ChatLive.Components.SessionCard do
  @moduledoc """
  Pure function component that renders a rich P2P-lobby or Arcade session card
  inside a chat message.

  Given a resolved summary (see `Lobby.session_summary/1` /
  `Arcade.session_summary/1`, wrapped by
  `RetroHexChatWeb.ChatLive.Helpers.SessionCard`), it draws a small retro panel:
  a title with the subject icon, a subtitle crediting the creator, a lifecycle
  timeline (created → started/connected → ended, with duration and reason) built
  from catalog SVG icons, and — while the session is still live — a call-to-action
  link. Terminal sessions render their final state and drop the CTA.

  Side-effect free: it reads only the summary map and the viewer `timezone`.
  """
  use RetroHexChatWeb, :html

  alias RetroHexChatWeb.App.ChatHelpers
  alias RetroHexChatWeb.Icons

  attr :card, :map, required: true, doc: "Resolved session summary (:lobby or :arcade)"
  attr :timezone, :string, default: "Etc/UTC"

  attr :viewer, :string,
    default: nil,
    doc: "Nickname of the viewing user — the invited peer gets accept/decline buttons"

  @doc "Renders the rich session card for a resolved lobby/arcade summary."
  @spec session_card(map()) :: Phoenix.LiveView.Rendered.t()
  def session_card(assigns) do
    assigns =
      assign(assigns,
        entries: timeline(assigns.card, assigns.timezone),
        cta: cta(assigns.card),
        invited?: invited_viewer?(assigns.card, assigns.viewer)
      )

    ~H"""
    <div
      class="chat-session-card mt-1 inline-block max-w-full bg-canvas shadow-retro-field p-2 text-xs"
      data-testid="session-card"
      data-session-kind={to_string(@card.kind)}
      data-session-status={@card.status}
      data-session-token={@card.kind == :lobby && @card.token}
    >
      <div class="flex items-start gap-2 mb-1.5">
        <.subject_icon card={@card} class="h-6 w-6 shrink-0" />
        <div class="min-w-0 flex-1">
          <div class="font-bold truncate">{title(@card)}</div>
          <div :if={subtitle(@card)} class="text-muted-foreground truncate">
            {subtitle(@card)}
          </div>
        </div>
        <span class="shrink-0 font-bold uppercase text-[10px] tracking-wide">
          {status_label(@card)}
        </span>
      </div>

      <ul :if={@entries != []} class="flex flex-col gap-0.5 mb-2">
        <li :for={entry <- @entries} class="flex items-center gap-1.5">
          <.timeline_icon name={entry.icon} class="h-3.5 w-3.5 shrink-0" />
          <span class="w-24 shrink-0 text-muted-foreground">{entry.label}</span>
          <span class="min-w-0 truncate">{entry.value}</span>
        </li>
      </ul>

      <div :if={@invited?} class="flex items-center gap-2">
        <button
          type="button"
          class="inline-flex items-center gap-1 px-2 py-0.5 bg-canvas shadow-retro-raised font-bold"
          phx-click="p2p_accept_invite"
          phx-value-token={@card.token}
          data-testid="session-card-accept"
        >
          <.timeline_icon name={:icon_btn_join} class="h-3.5 w-3.5" />
          {dgettext("chat", "Accept")}
        </button>
        <button
          type="button"
          class="inline-flex items-center gap-1 px-2 py-0.5 bg-canvas shadow-retro-raised"
          phx-click="p2p_decline_invite"
          phx-value-token={@card.token}
          data-testid="session-card-decline"
        >
          <.timeline_icon name={:icon_reject} class="h-3.5 w-3.5" />
          {dgettext("chat", "Decline")}
        </button>
      </div>

      <a
        :if={@cta}
        href={@card.href}
        class="inline-flex items-center gap-1 px-2 py-0.5 bg-canvas shadow-retro-raised font-bold no-underline"
        target="_blank"
        rel="noopener noreferrer"
      >
        <.timeline_icon name={@cta.icon} class="h-3.5 w-3.5" />
        {@cta.label}
      </a>
    </div>
    """
  end

  # The accept/decline buttons belong only to the invited peer of a still
  # pending lobby invite; everyone else (the creator, later viewers) keeps the
  # plain link CTA while the standalone page exists.
  defp invited_viewer?(%{kind: :lobby, status: "pending", peer: peer}, viewer)
       when is_binary(peer) and is_binary(viewer),
       do: String.downcase(peer) == String.downcase(viewer)

  defp invited_viewer?(_card, _viewer), do: false

  # ── Subject icon ────────────────────────────────────────────

  attr :card, :map, required: true
  attr :class, :string, default: nil

  defp subject_icon(%{card: %{kind: :arcade, game_id: game_id}} = assigns)
       when is_binary(game_id) do
    ~H"<Icons.game_icon game_id={@card.game_id} class={@class} />"
  end

  defp subject_icon(%{card: %{kind: :arcade}} = assigns) do
    ~H"<Icons.icon_game_arcade class={@class} />"
  end

  defp subject_icon(assigns) do
    ~H"<Icons.icon_p2p class={@class} />"
  end

  # ── Title / subtitle / status ───────────────────────────────

  defp title(%{kind: :lobby, terminal?: true}), do: dgettext("chat", "P2P lobby ended")
  defp title(%{kind: :lobby}), do: dgettext("chat", "P2P lobby")
  defp title(%{kind: :arcade, game_name: name}) when is_binary(name), do: name
  defp title(%{kind: :arcade}), do: dgettext("chat", "Arcade session")

  defp subtitle(%{kind: :lobby, created_by: by, peer: peer})
       when is_binary(by) and is_binary(peer) do
    dgettext("chat", "by %{creator} · with %{peer}", creator: by, peer: peer)
  end

  defp subtitle(%{created_by: by}) when is_binary(by),
    do: dgettext("chat", "by %{creator}", creator: by)

  defp subtitle(_), do: nil

  defp status_label(%{status: status}), do: humanize_status(status)

  defp humanize_status("pending"), do: dgettext("chat", "pending")
  defp humanize_status("lobby"), do: dgettext("chat", "lobby")
  defp humanize_status("connected"), do: dgettext("chat", "connected")
  defp humanize_status("playing"), do: dgettext("chat", "playing")
  defp humanize_status("finished"), do: dgettext("chat", "finished")
  defp humanize_status("closed"), do: dgettext("chat", "closed")
  defp humanize_status("expired"), do: dgettext("chat", "expired")
  defp humanize_status("failed"), do: dgettext("chat", "failed")
  defp humanize_status(other), do: other

  # ── Timeline ────────────────────────────────────────────────

  defp timeline(%{kind: :lobby} = card, tz) do
    [
      entry(:icon_checkmark, dgettext("chat", "created"), time(card.created_at, tz)),
      entry(:icon_status_signal, dgettext("chat", "connected"), time(card.connected_at, tz)),
      waiting_entry(card, dgettext("chat", "waiting to join")),
      terminal_entry(card, dgettext("chat", "ended"), tz),
      duration_entry(card),
      reason_entry(card)
    ]
    |> Enum.reject(&is_nil/1)
  end

  defp timeline(%{kind: :arcade} = card, tz) do
    [
      entry(:icon_checkmark, dgettext("chat", "created"), time(card.created_at, tz)),
      entry(:icon_btn_play, dgettext("chat", "started"), time(card.started_at, tz)),
      waiting_entry(card, dgettext("chat", "waiting for game")),
      terminal_entry(card, dgettext("chat", "finished"), tz),
      duration_entry(card),
      reason_entry(card)
    ]
    |> Enum.reject(&is_nil/1)
  end

  # The "current step" line only appears while the session is live and hasn't
  # reached its active phase yet (connected / playing), so it never duplicates a
  # concrete timeline row.
  defp waiting_entry(%{terminal?: true}, _label), do: nil
  defp waiting_entry(%{kind: :lobby, connected_at: %DateTime{}}, _label), do: nil
  defp waiting_entry(%{kind: :arcade, started_at: %DateTime{}}, _label), do: nil
  defp waiting_entry(_card, label), do: entry(:icon_radio_dot, label, "…")

  defp terminal_entry(%{terminal?: true} = card, label, tz),
    do: entry(terminal_icon(card), label, time(card.closed_at, tz))

  defp terminal_entry(_card, _label, _tz), do: nil

  defp duration_entry(%{duration_seconds: secs}) do
    case ChatHelpers.format_duration(secs) do
      nil -> nil
      value -> entry(:icon_btn_timers, dgettext("chat", "duration"), value)
    end
  end

  defp reason_entry(%{terminal?: true, closed_reason: reason})
       when is_binary(reason) and reason != "",
       do: entry(:icon_warning, dgettext("chat", "reason"), humanize_reason(reason))

  defp reason_entry(_card), do: nil

  # Maps internal close-reason keys (see Lobby/P2P/Arcade session servers) to
  # friendly, translated text. Unknown keys fall back to a prettified form so a
  # raw snake_case token is never shown to the user.
  defp humanize_reason("peer_left"), do: dgettext("chat", "The other user left")
  defp humanize_reason("host_left"), do: dgettext("chat", "The host left")
  defp humanize_reason("user"), do: dgettext("chat", "Closed by a user")
  defp humanize_reason("closed"), do: dgettext("chat", "Closed by a user")
  defp humanize_reason("user_blocked"), do: dgettext("chat", "Blocked by a user")
  defp humanize_reason("pending_timeout"), do: dgettext("chat", "No one joined in time")
  defp humanize_reason("connecting_timeout"), do: dgettext("chat", "Connection timed out")
  defp humanize_reason("expired"), do: dgettext("chat", "Expired due to inactivity")
  defp humanize_reason("failed"), do: dgettext("chat", "Connection failed")
  defp humanize_reason("stale_cleanup"), do: dgettext("chat", "Closed automatically")
  defp humanize_reason("game_over"), do: dgettext("chat", "Game over")
  defp humanize_reason("finished"), do: dgettext("chat", "Finished")

  defp humanize_reason(reason) do
    reason
    |> String.replace("_", " ")
    |> String.capitalize()
  end

  defp terminal_icon(%{status: "failed"}), do: :icon_reject
  defp terminal_icon(%{status: "expired"}), do: :icon_warning
  defp terminal_icon(%{kind: :lobby}), do: :icon_btn_disconnect
  defp terminal_icon(_card), do: :icon_checkmark

  defp entry(_icon, _label, nil), do: nil
  defp entry(_icon, _label, ""), do: nil
  defp entry(icon, label, value), do: %{icon: icon, label: label, value: value}

  defp time(nil, _tz), do: nil
  defp time(dt, tz), do: ChatHelpers.format_time(dt, :dd_mm_hh_mm, tz)

  # ── Call to action ──────────────────────────────────────────

  defp cta(%{terminal?: true}), do: nil

  # P2P sessions live entirely in the chat: the invited peer gets the
  # accept/decline buttons and everyone else just watches the timeline —
  # there is no link out to a separate page.
  defp cta(%{kind: :lobby}), do: nil

  defp cta(%{kind: :arcade}),
    do: %{label: dgettext("chat", "Open Arcade"), icon: :icon_btn_open}

  # ── Icon dispatch ───────────────────────────────────────────

  attr :name, :atom, required: true
  attr :class, :string, default: nil

  defp timeline_icon(%{name: :icon_checkmark} = assigns),
    do: ~H"<Icons.icon_checkmark class={@class} />"

  defp timeline_icon(%{name: :icon_status_signal} = assigns),
    do: ~H"<Icons.icon_status_signal class={@class} />"

  defp timeline_icon(%{name: :icon_radio_dot} = assigns),
    do: ~H"<Icons.icon_radio_dot class={@class} />"

  defp timeline_icon(%{name: :icon_btn_play} = assigns),
    do: ~H"<Icons.icon_btn_play class={@class} />"

  defp timeline_icon(%{name: :icon_btn_timers} = assigns),
    do: ~H"<Icons.icon_btn_timers class={@class} />"

  defp timeline_icon(%{name: :icon_btn_disconnect} = assigns),
    do: ~H"<Icons.icon_btn_disconnect class={@class} />"

  defp timeline_icon(%{name: :icon_warning} = assigns),
    do: ~H"<Icons.icon_warning class={@class} />"

  defp timeline_icon(%{name: :icon_reject} = assigns),
    do: ~H"<Icons.icon_reject class={@class} />"

  defp timeline_icon(%{name: :icon_btn_join} = assigns),
    do: ~H"<Icons.icon_btn_join class={@class} />"

  defp timeline_icon(%{name: :icon_btn_link} = assigns),
    do: ~H"<Icons.icon_btn_link class={@class} />"

  defp timeline_icon(%{name: :icon_btn_open} = assigns),
    do: ~H"<Icons.icon_btn_open class={@class} />"
end
