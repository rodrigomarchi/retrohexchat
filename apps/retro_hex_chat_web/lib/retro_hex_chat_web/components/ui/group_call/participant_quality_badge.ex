defmodule RetroHexChatWeb.Components.UI.GroupCall.ParticipantQualityBadge do
  @moduledoc """
  Compact participant connection-quality badge for the group-call UI.
  """
  use RetroHexChatWeb.Component

  alias RetroHexChatWeb.Components.UI.MediaSession.CallQuality

  attr :participant_id, :any, required: true
  attr :quality, :map, default: nil

  @spec participant_quality_badge(map()) :: Phoenix.LiveView.Rendered.t()
  def participant_quality_badge(assigns) do
    assigns =
      assigns
      |> assign(:level, CallQuality.level(assigns.quality))
      |> assign(:title, quality_title(assigns.quality))

    ~H"""
    <span
      :if={@level != :unknown}
      class={[
        "flex h-8 w-8 items-center justify-center",
        quality_class(@level)
      ]}
      title={@title}
      aria-label={@title}
      data-testid={"group-call-participant-quality-#{@participant_id}"}
      data-group-call-participant-quality
      data-quality-level={Atom.to_string(@level)}
    >
      <CallQuality.quality_icon level={@level} />
    </span>
    """
  end

  defp quality_class(:excellent), do: "bg-surface text-primary"
  defp quality_class(:good), do: "bg-surface text-primary"
  defp quality_class(:fair), do: "bg-warning-bg text-foreground"
  defp quality_class(:poor), do: "bg-destructive text-destructive-foreground"
  defp quality_class(:reconnecting), do: "bg-muted text-muted-foreground"

  defp quality_title(nil), do: dgettext("group_call", "Quality unknown")

  defp quality_title(%{} = quality) do
    dgettext(
      "group_call",
      "%{level} quality: RTT %{rtt} ms, loss %{loss}%, %{bitrate} kbps, %{fps} fps, freezes %{freezes}",
      level: CallQuality.label(CallQuality.level(quality)),
      rtt: Map.get(quality, :rtt_ms, 0),
      loss: Map.get(quality, :loss_pct, 0),
      bitrate: Map.get(quality, :bitrate_kbps, 0),
      fps: Map.get(quality, :fps, 0),
      freezes: Map.get(quality, :freeze_count, 0)
    )
  end
end
