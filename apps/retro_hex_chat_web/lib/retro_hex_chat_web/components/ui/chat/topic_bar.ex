defmodule RetroHexChatWeb.Components.UI.TopicBar do
  @moduledoc """
  Topic bar component for the showcase design system.

  Composed from badge + simple layout.
  Displays channel topic and mode badges, with variants for channel, PM and
  status windows.

  ## Usage

      <.topic_bar
        topic="Welcome to #lobby!"
        modes={["+nt", "+l 50"]}
      />
  """
  use RetroHexChatWeb.Component

  import RetroHexChatWeb.Components.UI.Badge
  import RetroHexChatWeb.Components.UI.NickFlag, only: [channel_badges: 1]

  alias RetroHexChatWeb.Icons

  @doc """
  Renders the topic bar.

  `modes` accepts either a pre-built list of badge strings or the raw active-modes
  string; the visible badge list is derived here from `variant` + `modes`
  (status/PM windows never show modes).
  """
  attr :topic, :string, default: ""
  attr :modes, :any, default: []
  attr :variant, :string, default: "channel", values: ~w(channel pm status)
  attr :channel_name, :string, default: nil
  attr :locale, :string, default: nil, doc: "the language the channel is spoken in"
  attr :category, :string, default: nil, doc: "what the channel is about"

  attr :heading_id, :string,
    default: nil,
    doc: "makes the name and topic the page's heading, under this id, where the bar heads a page"

  attr :class, :string, default: nil
  attr :rest, :global

  @spec topic_bar(map()) :: Phoenix.LiveView.Rendered.t()
  def topic_bar(assigns) do
    assigns = assign(assigns, :mode_badges, mode_badges(assigns.modes, assigns.variant))

    ~H"""
    <div
      class={
        classes([
          "flex items-center gap-retro-4 px-retro-4 py-retro-2 text-xs",
          "shadow-retro-sunken bg-white",
          @class
        ])
      }
      data-testid="topic-bar"
      {@rest}
    >
      <.topic_icon variant={@variant} />

      <.dynamic_tag
        tag_name={if @heading_id, do: "h1", else: "span"}
        id={@heading_id}
        class="contents"
      >
        <.channel_badges
          :if={@variant == "channel"}
          category={@category}
          locale={@locale}
          class="shrink-0"
        />
        <span :if={@channel_name} class="font-bold shrink-0">{@channel_name}</span>

        <span class="flex-1 truncate text-muted-foreground">
          {if @topic == "", do: dgettext("chat", "No topic set"), else: @topic}
        </span>
      </.dynamic_tag>

      <.badge :for={mode <- @mode_badges} variant="outline" class="text-[10px] px-1 py-0 shrink-0">
        {mode}
      </.badge>
    </div>
    """
  end

  # ── Private helpers ───────────────────────────────────

  # Status/PM windows never show channel modes. Otherwise: a non-empty raw mode
  # string becomes a single badge; a pre-built list (showcase) passes through.
  @spec mode_badges(term(), String.t()) :: [String.t()]
  defp mode_badges(_modes, variant) when variant in ~w(status pm), do: []
  defp mode_badges(modes, _variant) when is_list(modes), do: modes
  defp mode_badges(modes, _variant) when modes in [nil, ""], do: []
  defp mode_badges(modes, _variant) when is_binary(modes), do: [modes]

  attr :variant, :string, required: true

  defp topic_icon(%{variant: "channel"} = assigns) do
    ~H"""
    <Icons.icon_tab_channel class="w-3 h-3 shrink-0" />
    """
  end

  defp topic_icon(%{variant: "pm"} = assigns) do
    ~H"""
    <Icons.icon_tab_pm class="w-3 h-3 shrink-0" />
    """
  end

  defp topic_icon(%{variant: "status"} = assigns) do
    ~H"""
    <Icons.icon_status_signal class="w-3 h-3 shrink-0" />
    """
  end
end
