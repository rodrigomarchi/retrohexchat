defmodule RetroHexChatWeb.Components.Diagrams.DialogChannel do
  @moduledoc """
  The Channel Central banner illustration: a miniature of the channel as the
  next person to join will meet it.

  The topic strip and the welcome lines are drawn from the values currently in
  the form, so the picture answers "who sees this, and where" without a
  sentence explaining it — the same reason Display Properties drew a monitor
  instead of naming the wallpaper file.
  """
  use Phoenix.Component
  use Gettext, backend: RetroHexChatWeb.Gettext

  @chars_per_line 26
  @max_lines 4

  @doc "Renders the channel as a joiner sees it: title bar, topic strip, welcome text."
  attr :class, :string, default: nil
  attr :channel_name, :string, required: true
  attr :topic, :string, default: ""
  attr :welcome, :string, default: ""

  @spec diagram_channel_preview(map()) :: Phoenix.LiveView.Rendered.t()
  def diagram_channel_preview(assigns) do
    assigns =
      assigns
      |> assign(:title, clip(assigns.channel_name, 18))
      |> assign(:topic_line, clip(assigns.topic, @chars_per_line))
      |> assign(:welcome_lines, wrap(assigns.welcome))

    ~H"""
    <svg
      class={@class}
      viewBox="0 0 128 96"
      shape-rendering="crispEdges"
      xmlns="http://www.w3.org/2000/svg"
      role="img"
      aria-label={
        dgettext("diagrams", "A miniature of the channel window as the next person to join sees it")
      }
    >
      <!-- Window frame -->
      <rect x="2" y="4" width="124" height="88" fill="#c0c0c0" stroke="#000000" stroke-width="1" />
      <polyline points="3,91 3,5 125,5" fill="none" stroke="#ffffff" stroke-width="1" />
      <polyline points="125,6 125,91 3,91" fill="none" stroke="#808080" stroke-width="1" />
      
    <!-- Title bar -->
      <rect x="5" y="7" width="118" height="11" fill="#000080" />
      <text
        x="8"
        y="15"
        fill="#ffffff"
        font-size="8"
        font-family="'Source Code Pro',monospace"
        font-weight="bold"
      >
        {@title}
      </text>
      
    <!-- Topic strip -->
      <rect x="5" y="20" width="118" height="12" fill="#c0c0c0" />
      <polyline points="5,31 5,20 122,20" fill="none" stroke="#808080" stroke-width="1" />
      <polyline points="123,21 123,32 5,32" fill="none" stroke="#ffffff" stroke-width="1" />
      <text
        :if={@topic_line != ""}
        x="8"
        y="29"
        fill="#000000"
        font-size="7"
        font-family="Tahoma,sans-serif"
      >
        {@topic_line}
      </text>
      <rect :if={@topic_line == ""} x="8" y="24" width="60" height="4" fill="#a0a0a0" />
      
    <!-- Message area -->
      <rect x="5" y="34" width="118" height="55" fill="#ffffff" />
      <polyline points="5,88 5,34 122,34" fill="none" stroke="#808080" stroke-width="1" />
      
    <!-- The join line the channel always writes -->
      <text x="8" y="43" fill="#008080" font-size="7" font-family="Tahoma,sans-serif">
        {system_line(dgettext("diagrams", "someone joined"))}
      </text>
      
    <!-- The welcome message, as the joiner reads it -->
      <g :if={@welcome_lines != []}>
        <text
          :for={{line, index} <- Enum.with_index(@welcome_lines)}
          x="8"
          y={53 + index * 9}
          fill="#000080"
          font-size="7"
          font-family="Tahoma,sans-serif"
        >
          {line}
        </text>
      </g>
      
    <!-- Nothing greets them: the space the message would occupy, left empty -->
      <g :if={@welcome_lines == []}>
        <rect x="8" y="50" width="88" height="4" fill="#e0e0e0" />
        <rect x="8" y="59" width="70" height="4" fill="#e0e0e0" />
        <rect x="8" y="68" width="80" height="4" fill="#e0e0e0" />
      </g>
    </svg>
    """
  end

  @spec clip(String.t() | nil, pos_integer()) :: String.t()
  defp clip(nil, _limit), do: ""

  defp clip(text, limit) when is_binary(text) do
    trimmed = String.trim(text)

    if String.length(trimmed) > limit,
      do: String.slice(trimmed, 0, limit - 1) <> "…",
      else: trimmed
  end

  @spec wrap(String.t() | nil) :: [String.t()]
  defp wrap(nil), do: []

  defp wrap(text) when is_binary(text) do
    text
    |> String.split(~r/\s+/, trim: true)
    |> Enum.reduce([], &append_word/2)
    |> Enum.reverse()
    |> trim_to_max()
  end

  @spec append_word(String.t(), [String.t()]) :: [String.t()]
  defp append_word(word, []), do: [String.slice(word, 0, @chars_per_line)]

  defp append_word(word, [current | rest] = lines) do
    candidate = current <> " " <> word

    if String.length(candidate) <= @chars_per_line,
      do: [candidate | rest],
      else: [String.slice(word, 0, @chars_per_line) | lines]
  end

  @spec trim_to_max([String.t()]) :: [String.t()]
  defp trim_to_max(lines) when length(lines) <= @max_lines, do: lines

  defp trim_to_max(lines) do
    kept = Enum.take(lines, @max_lines)
    List.update_at(kept, @max_lines - 1, &(String.slice(&1, 0, @chars_per_line - 1) <> "…"))
  end

  # The chat's own marker for a line nobody typed. It is punctuation, not
  # prose: inside a msgid the engine reads it as list markup and mangles the
  # sentence after it, so it is prefixed here instead.
  @spec system_line(String.t()) :: String.t()
  defp system_line(text), do: "* " <> text
end
