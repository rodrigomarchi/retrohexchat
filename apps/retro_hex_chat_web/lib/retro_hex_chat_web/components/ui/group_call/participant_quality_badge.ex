defmodule RetroHexChatWeb.Components.UI.GroupCall.ParticipantQualityBadge do
  @moduledoc """
  Compact participant connection-quality badge for the group-call UI.
  """
  use RetroHexChatWeb.Component

  alias RetroHexChatWeb.Icons

  attr :participant_id, :any, required: true
  attr :quality, :map, default: nil

  @spec participant_quality_badge(map()) :: Phoenix.LiveView.Rendered.t()
  def participant_quality_badge(assigns) do
    assigns =
      assigns
      |> assign(:level, quality_level(assigns.quality))
      |> assign(:title, quality_title(assigns.quality))

    ~H"""
    <span
      :if={@level != :unknown}
      class={[
        "flex h-5 w-5 items-center justify-center shadow-retro-sunken",
        quality_class(@level)
      ]}
      title={@title}
      aria-label={@title}
      data-testid={"group-call-participant-quality-#{@participant_id}"}
      data-group-call-participant-quality
      data-quality-level={Atom.to_string(@level)}
    >
      <Icons.icon_quality_high :if={@level in [:excellent, :good]} class="h-3 w-3" />
      <Icons.icon_quality_medium :if={@level == :fair} class="h-3 w-3" />
      <Icons.icon_quality_low :if={@level == :poor} class="h-3 w-3" />
      <Icons.icon_btn_timers :if={@level == :reconnecting} class="h-3 w-3" />
    </span>
    """
  end

  defp quality_level(%{level: level})
       when level in [:excellent, :good, :fair, :poor, :reconnecting],
       do: level

  defp quality_level(%{level: level}) when is_binary(level) do
    case level do
      "excellent" -> :excellent
      "good" -> :good
      "fair" -> :fair
      "poor" -> :poor
      "reconnecting" -> :reconnecting
      _other -> :unknown
    end
  end

  defp quality_level(_quality), do: :unknown

  defp quality_class(:excellent), do: "bg-surface text-primary"
  defp quality_class(:good), do: "bg-surface text-primary"
  defp quality_class(:fair), do: "bg-warning-light text-foreground"
  defp quality_class(:poor), do: "bg-destructive text-destructive-foreground"
  defp quality_class(:reconnecting), do: "bg-muted text-muted-foreground"
  defp quality_class(:unknown), do: "bg-muted text-muted-foreground"

  defp quality_title(nil), do: dgettext("group_call", "Quality unknown")

  defp quality_title(%{} = quality) do
    dgettext(
      "group_call",
      "%{level} quality: RTT %{rtt} ms, loss %{loss}%, %{bitrate} kbps, %{fps} fps, freezes %{freezes}",
      level: quality_label(quality_level(quality)),
      rtt: Map.get(quality, :rtt_ms, 0),
      loss: Map.get(quality, :loss_pct, 0),
      bitrate: Map.get(quality, :bitrate_kbps, 0),
      fps: Map.get(quality, :fps, 0),
      freezes: Map.get(quality, :freeze_count, 0)
    )
  end

  defp quality_label(:excellent), do: dgettext("group_call", "Excellent")
  defp quality_label(:good), do: dgettext("group_call", "Good")
  defp quality_label(:fair), do: dgettext("group_call", "Fair")
  defp quality_label(:poor), do: dgettext("group_call", "Poor")
  defp quality_label(:reconnecting), do: dgettext("group_call", "Reconnecting")
  defp quality_label(:unknown), do: dgettext("group_call", "Unknown")
end
