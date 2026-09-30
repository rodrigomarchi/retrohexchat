defmodule RetroHexChatWeb.Components.Diagrams.DialogPreview do
  @moduledoc """
  The banner illustration most dialogs get: a miniature of the surface their
  settings actually come out on.

  One module, one chrome routine, and a different **anatomy** per kind — not
  merely different text. A first cut drew the same window for every dialog
  and changed only the title word, which made ten banners that were one
  picture repeated: at 128×96 nobody reads two lines of 7px type, they read
  the silhouette. So a composer draws its input strip, a roster draws its
  column header and rows, a schedule draws a clock, and a whois card draws a
  portrait well with label/value rows.

  The rows still come from what the form is holding right now, so an empty
  setting looks empty.
  """
  use Phoenix.Component
  use Gettext, backend: RetroHexChatWeb.Gettext

  @kinds [:status, :query, :composer, :tabs, :ordered, :schedule, :card, :menu]

  @doc """
  Renders the miniature.

  `lines` are maps of `%{text:, tone:}`; the tone picks the colour the real
  surface would give that row (`:accent`, `:system`, `:muted`, `:danger`).
  """
  attr :class, :string, default: nil
  attr :title, :string, required: true
  attr :kind, :atom, default: :status, values: @kinds
  attr :lines, :list, default: []
  attr :label, :string, default: nil, doc: "aria-label; defaults to a description of the kind"

  @spec diagram_dialog_preview(map()) :: Phoenix.LiveView.Rendered.t()
  def diagram_dialog_preview(assigns) do
    assigns =
      assigns
      |> assign(:rows, rows(assigns.lines, assigns.kind))
      |> assign(:heading, clip(assigns.title, 20))
      |> assign(:aria, assigns.label || kind_label(assigns.kind))

    ~H"""
    <svg
      class={@class}
      viewBox="0 0 128 96"
      shape-rendering="crispEdges"
      xmlns="http://www.w3.org/2000/svg"
      role="img"
      aria-label={@aria}
    >
      <!-- Frame and title bar, the one part every surface shares -->
      <rect x="2" y="4" width="124" height="88" fill="#c0c0c0" stroke="#000000" stroke-width="1" />
      <polyline points="3,91 3,5 125,5" fill="none" stroke="#ffffff" stroke-width="1" />
      <polyline points="125,6 125,91 3,91" fill="none" stroke="#808080" stroke-width="1" />
      <rect x="5" y="7" width="118" height="11" fill="#000080" />
      <text
        x="8"
        y="15"
        fill="#ffffff"
        font-size="8"
        font-family="Tahoma,sans-serif"
        font-weight="bold"
      >
        {@heading}
      </text>
      
    <!-- The well, shaped by what this surface is -->
      <g :if={@kind == :menu}>
        <rect x="5" y="21" width="118" height="67" fill="#c0c0c0" />
        <polyline points="6,87 6,22 122,22" fill="none" stroke="#ffffff" stroke-width="1" />
        <polyline points="122,22 122,87 6,87" fill="none" stroke="#808080" stroke-width="1" />
      </g>
      <g :if={@kind == :card}>
        <rect x="5" y="21" width="118" height="67" fill="#c0c0c0" />
        <rect x="9" y="25" width="110" height="59" fill="#ffffff" />
        <polyline points="9,83 9,25 118,25" fill="none" stroke="#808080" stroke-width="1" />
        <!-- Portrait well: a whois card leads with who, not with text -->
        <rect x="13" y="29" width="22" height="22" fill="#c0c0c0" />
        <polyline points="13,50 13,29 34,29" fill="none" stroke="#808080" stroke-width="1" />
        <rect x="21" y="33" width="7" height="7" fill="#000080" />
        <rect x="17" y="42" width="15" height="7" fill="#000080" />
      </g>
      <g :if={@kind not in [:menu, :card]}>
        <rect x="5" y="21" width="118" height={well_height(@kind)} fill="#ffffff" />
        <polyline
          points={"5,#{21 + well_height(@kind) - 1} 5,21 122,21"}
          fill="none"
          stroke="#808080"
          stroke-width="1"
        />
      </g>
      
    <!-- Roster column header -->
      <g :if={@kind == :ordered}>
        <rect x="6" y="22" width="116" height="9" fill="#c0c0c0" />
        <polyline points="6,30 6,22 121,22" fill="none" stroke="#ffffff" stroke-width="1" />
        <polyline points="121,23 121,30 6,30" fill="none" stroke="#808080" stroke-width="1" />
      </g>
      
    <!-- Clock face: a schedule is a time before it is a command -->
      <g :if={@kind == :schedule}>
        <rect x="14" y="30" width="20" height="20" fill="#ffffff" stroke="#000000" stroke-width="1" />
        <rect x="18" y="28" width="12" height="2" fill="#000000" />
        <rect x="18" y="50" width="12" height="2" fill="#000000" />
        <rect x="12" y="34" width="2" height="12" fill="#000000" />
        <rect x="34" y="34" width="2" height="12" fill="#000000" />
        <rect x="23" y="34" width="2" height="7" fill="#000000" />
        <rect x="23" y="39" width="8" height="2" fill="#000000" />
      </g>
      
    <!-- Speech turns: a query is two people, so it is drawn as two -->
      <g :if={@kind == :query}>
        <rect :for={row <- @rows} x="8" y={row.y - 5} width="4" height="4" fill={turn_fill(row)} />
      </g>
      
    <!-- The rows themselves -->
      <g :for={row <- @rows}>
        <rect
          :if={row.text == "-"}
          x="10"
          y={row.y - 4}
          width="108"
          height="1"
          fill="#808080"
        />
        <rect
          :if={@kind == :ordered and row.text != "-"}
          x="8"
          y={row.y - 6}
          width="8"
          height="7"
          fill="#000080"
        />
        <text
          :if={row.text != "-"}
          x={row_x(@kind)}
          y={row.y}
          fill={tone_fill(row.tone)}
          font-size="7"
          font-family="Tahoma,sans-serif"
        >
          {row.text}
        </text>
      </g>
      
    <!-- Nothing set yet: the space the rows would occupy, left empty -->
      <g :if={@rows == []}>
        <rect x={row_x(@kind)} y={empty_top(@kind)} width="82" height="4" fill="#e0e0e0" />
        <rect x={row_x(@kind)} y={empty_top(@kind) + 9} width="64" height="4" fill="#e0e0e0" />
        <rect x={row_x(@kind)} y={empty_top(@kind) + 18} width="74" height="4" fill="#e0e0e0" />
      </g>
      
    <!-- Composer strip: the line you type sits under what it produced -->
      <g :if={@kind == :composer}>
        <rect x="5" y="72" width="94" height="14" fill="#ffffff" />
        <polyline points="5,85 5,72 98,72" fill="none" stroke="#808080" stroke-width="1" />
        <rect x="101" y="72" width="22" height="14" fill="#c0c0c0" stroke="#000000" stroke-width="1" />
        <polyline points="102,84 102,73 121,73" fill="none" stroke="#ffffff" stroke-width="1" />
        <text
          x="8"
          y="82"
          fill="#000000"
          font-size="7"
          font-family="'Source Code Pro',monospace"
        >
          {typed_line(@rows)}
        </text>
      </g>
      
    <!-- Tab strip: the channels that will be sitting there when you arrive -->
      <g :if={@kind == :tabs}>
        <g :for={{tab, index} <- Enum.with_index(tab_labels(@rows))}>
          <rect
            x={6 + index * 59}
            y="73"
            width="57"
            height="14"
            fill="#c0c0c0"
            stroke="#000000"
            stroke-width="1"
          />
          <polyline
            points={"#{7 + index * 59},86 #{7 + index * 59},74 #{61 + index * 59},74"}
            fill="none"
            stroke="#ffffff"
            stroke-width="1"
          />
          <text
            x={10 + index * 59}
            y="83"
            fill="#000000"
            font-size="7"
            font-family="Tahoma,sans-serif"
          >
            {tab}
          </text>
        </g>
      </g>
    </svg>
    """
  end

  # A surface with furniture at the bottom gets a shorter well.
  @spec well_height(atom()) :: pos_integer()
  defp well_height(kind) when kind in [:composer, :tabs], do: 50
  defp well_height(_kind), do: 67

  # Where a row's text starts: after the turn marker, the row icon, or the
  # clock, depending on what the surface put there.
  @spec row_x(atom()) :: pos_integer()
  defp row_x(:query), do: 15
  defp row_x(:ordered), do: 19
  defp row_x(:schedule), do: 38
  defp row_x(:card), do: 39
  defp row_x(:menu), do: 14
  defp row_x(_kind), do: 8

  @spec empty_top(atom()) :: pos_integer()
  defp empty_top(:card), do: 33
  defp empty_top(:schedule), do: 34
  defp empty_top(_kind), do: 38

  @spec first_row(atom()) :: pos_integer()
  defp first_row(:card), do: 36
  defp first_row(:ordered), do: 41
  defp first_row(:schedule), do: 38
  defp first_row(_kind), do: 40

  @spec max_rows(atom()) :: pos_integer()
  defp max_rows(kind) when kind in [:composer, :tabs], do: 3
  defp max_rows(:schedule), do: 3
  defp max_rows(_kind), do: 5

  @spec rows([map()], atom()) :: [map()]
  defp rows(lines, kind) do
    lines
    |> Enum.reject(&(Map.get(&1, :text) != "-" and clip(Map.get(&1, :text), 26) == ""))
    |> Enum.take(max_rows(kind))
    |> Enum.with_index()
    |> Enum.map(fn {line, index} ->
      %{
        text: if(line.text == "-", do: "-", else: clip(line.text, row_chars(kind))),
        tone: Map.get(line, :tone, :normal),
        y: first_row(kind) + index * 9
      }
    end)
  end

  @spec row_chars(atom()) :: pos_integer()
  defp row_chars(kind) when kind in [:query, :ordered, :card], do: 23
  defp row_chars(:schedule), do: 18
  defp row_chars(_kind), do: 26

  # The composer's own strip shows the last row — what the person typed —
  # while the rows above show what it turned into.
  @spec typed_line([map()]) :: String.t()
  defp typed_line([]), do: ""
  defp typed_line(rows), do: rows |> List.last() |> Map.get(:text) |> clip(22)

  @spec tab_labels([map()]) :: [String.t()]
  defp tab_labels(rows), do: rows |> Enum.take(2) |> Enum.map(&clip(&1.text, 11))

  # A turn marker takes the colour of the voice that said it, so the two
  # sides of a query read as two sides.
  @spec turn_fill(map()) :: String.t()
  defp turn_fill(%{tone: :normal}), do: "#808080"
  defp turn_fill(row), do: tone_fill(row.tone)

  @spec tone_fill(atom()) :: String.t()
  defp tone_fill(:accent), do: "#000080"
  defp tone_fill(:system), do: "#008080"
  defp tone_fill(:muted), do: "#808080"
  defp tone_fill(:danger), do: "#800000"
  defp tone_fill(_tone), do: "#000000"

  @spec clip(String.t() | nil, pos_integer()) :: String.t()
  defp clip(nil, _limit), do: ""

  defp clip(text, limit) when is_binary(text) do
    trimmed = text |> String.replace(~r/\s+/, " ") |> String.trim()

    if String.length(trimmed) > limit,
      do: String.slice(trimmed, 0, limit - 1) <> "…",
      else: trimmed
  end

  @spec kind_label(atom()) :: String.t()
  defp kind_label(:query),
    do: dgettext("diagrams", "A miniature of the private conversation this appears in")

  defp kind_label(:composer),
    do: dgettext("diagrams", "A miniature of the composer, showing what typing this sends")

  defp kind_label(:tabs),
    do: dgettext("diagrams", "A miniature of the channel tabs this opens")

  defp kind_label(:ordered),
    do: dgettext("diagrams", "A miniature of the list these entries run from, in order")

  defp kind_label(:schedule),
    do: dgettext("diagrams", "A miniature of the clock this runs on and the line it sends")

  defp kind_label(:card),
    do: dgettext("diagrams", "A miniature of the card other people read this on")

  defp kind_label(:menu),
    do: dgettext("diagrams", "A miniature of the menu these entries appear in")

  defp kind_label(_kind),
    do: dgettext("diagrams", "A miniature of the Status window these lines arrive in")

  @doc """
  Breaks a paragraph into miniature-width lines of the given tone.

  Both the whois card and the channel preview need this, and a second copy
  drifts: the two would stop agreeing on where a line breaks.
  """
  @spec wrap_lines(String.t() | nil, atom(), pos_integer()) :: [map()]
  def wrap_lines(text, tone \\ :normal, limit \\ 26)
  def wrap_lines(nil, _tone, _limit), do: []

  def wrap_lines(text, tone, limit) when is_binary(text) do
    case String.trim(text) do
      "" -> []
      trimmed -> trimmed |> words_into_lines(limit) |> Enum.map(&%{text: &1, tone: tone})
    end
  end

  @spec words_into_lines(String.t(), pos_integer()) :: [String.t()]
  defp words_into_lines(text, limit) do
    text
    |> String.split(~r/\s+/, trim: true)
    |> Enum.reduce([], &append_word(&1, &2, limit))
    |> Enum.reverse()
  end

  @spec append_word(String.t(), [String.t()], pos_integer()) :: [String.t()]
  defp append_word(word, [], _limit), do: [word]

  defp append_word(word, [current | rest] = lines, limit) do
    candidate = current <> " " <> word
    if String.length(candidate) <= limit, do: [candidate | rest], else: [word | lines]
  end
end
