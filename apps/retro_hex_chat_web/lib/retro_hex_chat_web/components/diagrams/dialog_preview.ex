defmodule RetroHexChatWeb.Components.Diagrams.DialogPreview do
  @moduledoc """
  The banner illustration most dialogs get: a miniature of the surface their
  settings actually come out on.

  One module, one chrome routine, and a different **anatomy** per kind — not
  merely different text. A first cut drew the same window for every dialog
  and changed only the title word, which made ten banners that were one
  picture repeated: at 128×96 nobody reads two lines of 7px type, they read
  the silhouette. So a composer draws its input strip, an ordered list draws
  its column header and numbered rows, a schedule draws a clock, a whois card
  draws a portrait well with label/value rows, a roster draws a running lamp
  per row, and a checklist draws a box per row with nothing ticked.

  Three of them are not lists at all: a settings sheet draws a value well
  beside each label, a relay draws the two ends and the thing between them,
  and a broadcast draws the same line in three windows at once.

  Two more draw what happens *to* a line rather than what it says: a
  highlighted row wears the band the real one wears, and a hidden row is
  struck out where it would have been. Both windows used to draw the same
  channel with the same two bullets, and the only thing telling them apart
  was text nobody reads at 7px.

  The rows still come from what the form is holding right now, so an empty
  setting looks empty.
  """
  use Phoenix.Component
  use Gettext, backend: RetroHexChatWeb.Gettext

  @kinds [
    :status,
    :query,
    :composer,
    :tabs,
    :ordered,
    :schedule,
    :card,
    :menu,
    :pinned,
    :roster,
    :checklist,
    :highlighted,
    :hidden,
    :fields,
    :relay,
    :broadcast
  ]

  @doc """
  Renders the miniature.

  `lines` are maps of `%{text:, tone:}`; the tone picks the colour the real
  surface would give that row (`:accent`, `:system`, `:muted`, `:danger`,
  and for a lamp `:ok` or `:warn`). A `:fields` line carries a second string
  under `value`, drawn in the well beside its label, and a `:tabs` line sets
  `tab: true` to be drawn on the tab strip instead of in the well.
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
      
    <!-- Pin bar: what a pinned line actually is, a strip the room wears
           above its messages -->
      <g :if={@kind == :pinned}>
        <rect x="6" y="22" width="116" height="13" fill="#ffffcc" />
        <polyline points="6,34 6,22 121,22" fill="none" stroke="#808080" stroke-width="1" />
        <rect x="9" y="25" width="7" height="7" fill="#800000" />
      </g>
      
    <!-- Roster column header -->
      <g :if={@kind == :ordered}>
        <rect x="6" y="22" width="116" height="9" fill="#c0c0c0" />
        <polyline points="6,30 6,22 121,22" fill="none" stroke="#ffffff" stroke-width="1" />
        <polyline points="121,23 121,30 6,30" fill="none" stroke="#808080" stroke-width="1" />
      </g>
      
    <!-- Running lamps: a roster of processes is read by which ones are lit -->
      <g :if={@kind == :roster}>
        <circle
          :for={row <- @rows}
          cx="11"
          cy={row.y - 3}
          r="3"
          fill={lamp_fill(row.tone)}
          stroke="#404040"
          stroke-width="1"
        />
      </g>
      
    <!-- Checkboxes: a capability list is a set of things not yet chosen -->
      <g :if={@kind == :checklist}>
        <g :for={row <- @rows}>
          <rect
            x="9"
            y={row.y - 7}
            width="8"
            height="8"
            fill="#ffffff"
            stroke="#404040"
            stroke-width="1"
          />
          <g :if={row.tone == :accent}>
            <rect x="11" y={row.y - 4} width="2" height="2" fill="#000000" />
            <rect x="13" y={row.y - 2} width="2" height="2" fill="#000000" />
            <rect x="15" y={row.y - 6} width="2" height="4" fill="#000000" />
          </g>
        </g>
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
      
    <!-- Highlight band: the row does not merely say it matched, it wears
           the colour the real line wears -->
      <g :if={@kind == :highlighted}>
        <rect
          :for={row <- Enum.filter(@rows, &(&1.tone == :accent))}
          x="6"
          y={row.y - 7}
          width="116"
          height="10"
          fill="#ffffcc"
        />
        <rect
          :for={row <- Enum.filter(@rows, &(&1.tone == :accent))}
          x="6"
          y={row.y - 7}
          width="2"
          height="10"
          fill="#800000"
        />
      </g>
      
    <!-- A hidden line is not a line with different words, it is a line that
           is not there -->
      <g :if={@kind == :hidden}>
        <g :for={row <- Enum.filter(@rows, &(&1.tone == :muted))}>
          <rect x="8" y={row.y - 7} width="112" height="9" fill="#e8e8e8" />
          <rect x="10" y={row.y - 3} width="108" height="1" fill="#808080" />
        </g>
      </g>
      
    <!-- Settings sheet: a name is only half a setting, the value is the half
           that changes -->
      <g :if={@kind == :fields}>
        <g :for={row <- @rows}>
          <rect x="62" y={row.y - 7} width="56" height="9" fill="#ffffff" />
          <polyline
            points={"62,#{row.y + 1} 62,#{row.y - 7} 117,#{row.y - 7}"}
            fill="none"
            stroke="#808080"
            stroke-width="1"
          />
          <text
            x="64"
            y={row.y}
            fill={tone_fill(row.tone)}
            font-size="7"
            font-family="Tahoma,sans-serif"
          >
            {row.value}
          </text>
        </g>
      </g>
      
    <!-- Relay: the two ends, and the box that carries the call when they
           cannot reach each other -->
      <g :if={@kind == :relay}>
        <rect x="32" y="40" width="18" height="2" fill="#000080" />
        <rect x="78" y="40" width="18" height="2" fill="#000080" />
        <rect x="10" y="33" width="22" height="16" fill="#c0c0c0" stroke="#000000" stroke-width="1" />
        <polyline points="11,48 11,34 30,34" fill="none" stroke="#ffffff" stroke-width="1" />
        <rect x="96" y="33" width="22" height="16" fill="#c0c0c0" stroke="#000000" stroke-width="1" />
        <polyline points="97,48 97,34 116,34" fill="none" stroke="#ffffff" stroke-width="1" />
        <rect x="50" y="29" width="28" height="24" fill="#c0c0c0" stroke="#000000" stroke-width="1" />
        <polyline points="51,52 51,30 76,30" fill="none" stroke="#ffffff" stroke-width="1" />
        <rect x="55" y="34" width="18" height="3" fill="#000080" />
        <rect x="55" y="39" width="18" height="3" fill="#008080" />
        <rect x="55" y="44" width="18" height="3" fill="#000080" />
      </g>
      
    <!-- Broadcast: one line, and every window that receives it -->
      <g :if={@kind == :broadcast}>
        <g :for={{top, left} <- [{25, 30}, {44, 20}, {63, 10}]}>
          <rect
            x={left}
            y={top}
            width="84"
            height="17"
            fill="#c0c0c0"
            stroke="#000000"
            stroke-width="1"
          />
          <polyline
            points={"#{left + 1},#{top + 16} #{left + 1},#{top + 1} #{left + 82},#{top + 1}"}
            fill="none"
            stroke="#ffffff"
            stroke-width="1"
          />
          <rect x={left + 2} y={top + 2} width="80" height="5" fill="#000080" />
          <text
            x={left + 4}
            y={top + 14}
            fill={tone_fill(broadcast_tone(@rows))}
            font-size="7"
            font-family="Tahoma,sans-serif"
          >
            {broadcast_line(@rows)}
          </text>
        </g>
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
          :if={row.text != "-" and text_row?(@kind, row)}
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
      <g :if={@rows == [] and @kind not in [:relay, :broadcast]}>
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
  defp row_x(:pinned), do: 20
  defp row_x(:roster), do: 18
  defp row_x(:checklist), do: 21
  defp row_x(:relay), do: 8
  defp row_x(:highlighted), do: 11
  defp row_x(:hidden), do: 10
  defp row_x(_kind), do: 8

  @spec empty_top(atom()) :: pos_integer()
  defp empty_top(:card), do: 33
  defp empty_top(:schedule), do: 34
  defp empty_top(:pinned), do: 42
  defp empty_top(kind) when kind in [:roster, :checklist], do: 29
  defp empty_top(_kind), do: 38

  @spec first_row(atom()) :: pos_integer()
  defp first_row(:card), do: 36
  defp first_row(:ordered), do: 41
  defp first_row(:schedule), do: 38
  defp first_row(:pinned), do: 32
  defp first_row(kind) when kind in [:roster, :checklist], do: 32
  defp first_row(:relay), do: 66
  defp first_row(kind) when kind in [:highlighted, :hidden], do: 33
  defp first_row(:broadcast), do: 32
  defp first_row(_kind), do: 40

  @spec max_rows(atom()) :: pos_integer()
  defp max_rows(kind) when kind in [:composer, :tabs], do: 3
  defp max_rows(:schedule), do: 3
  defp max_rows(kind) when kind in [:roster, :checklist], do: 6
  defp max_rows(:fields), do: 6
  defp max_rows(:relay), do: 3
  defp max_rows(kind) when kind in [:highlighted, :hidden], do: 5
  defp max_rows(:broadcast), do: 1
  defp max_rows(_kind), do: 5

  @spec rows([map()], atom()) :: [map()]
  defp rows(lines, kind) do
    kept =
      lines
      |> Enum.reject(&(Map.get(&1, :text) != "-" and clip(Map.get(&1, :text), 26) == ""))
      |> Enum.take(max_rows(kind))

    last = length(kept) - 1

    kept
    |> Enum.with_index()
    |> Enum.map(fn {line, index} ->
      %{
        text: if(line.text == "-", do: "-", else: clip(line.text, row_chars(kind))),
        value: clip(Map.get(line, :value), 13),
        tone: Map.get(line, :tone, :normal),
        index: index,
        last?: index == last,
        tab?: Map.get(line, :tab, false),
        y: first_row(kind) + index * 9
      }
    end)
  end

  @spec row_chars(atom()) :: pos_integer()
  defp row_chars(kind) when kind in [:query, :ordered, :card], do: 23
  defp row_chars(:schedule), do: 18
  defp row_chars(:pinned), do: 22
  defp row_chars(:roster), do: 21
  defp row_chars(:checklist), do: 20
  defp row_chars(:fields), do: 15
  defp row_chars(:relay), do: 26
  defp row_chars(kind) when kind in [:highlighted, :hidden], do: 24
  defp row_chars(:broadcast), do: 24
  defp row_chars(_kind), do: 26

  # The composer's own strip shows the last row — what the person typed —
  # while the rows above show what it turned into.
  @spec typed_line([map()]) :: String.t()
  defp typed_line([]), do: ""
  defp typed_line(rows), do: rows |> List.last() |> Map.get(:text) |> clip(22)

  # A tab says so. Deciding it by position meant a caller with one tab and one
  # line lost the line, because position two was assumed to be a second tab.
  @spec tab_labels([map()]) :: [String.t()]
  defp tab_labels(rows) do
    rows |> Enum.filter(& &1.tab?) |> Enum.take(2) |> Enum.map(&clip(&1.text, 11))
  end

  # A turn marker takes the colour of the voice that said it, so the two
  # sides of a query read as two sides.
  @spec turn_fill(map()) :: String.t()
  defp turn_fill(%{tone: :normal}), do: "#808080"
  defp turn_fill(row), do: tone_fill(row.tone)

  # The lamp takes the roster's own colours, so the picture and the list under
  # it do not disagree about what "up" looks like.
  @spec lamp_fill(atom()) :: String.t()
  defp lamp_fill(:ok), do: "#00a000"
  defp lamp_fill(:warn), do: "#e0b000"
  defp lamp_fill(_tone), do: "#a0a0a0"

  # A row the surface has already drawn somewhere else is not drawn again.
  # Three anatomies place a row outside the well — a broadcast puts it in
  # every window, a tab strip puts it on a tab, a composer puts it on the
  # typed strip — and each of them was also printing it as a plain line, so
  # half of a 128×96 picture said the same thing twice.
  @spec text_row?(atom(), map()) :: boolean()
  defp text_row?(:broadcast, _row), do: false
  defp text_row?(:tabs, row), do: not row.tab?
  defp text_row?(:composer, row), do: not row.last?
  defp text_row?(_kind, _row), do: true

  # Every window gets the same line, so the picture draws the same line in
  # every window.
  @spec broadcast_line([map()]) :: String.t()
  defp broadcast_line([]), do: ""
  defp broadcast_line([row | _rest]), do: row.text

  @spec broadcast_tone([map()]) :: atom()
  defp broadcast_tone([]), do: :normal
  defp broadcast_tone([row | _rest]), do: row.tone

  @spec tone_fill(atom()) :: String.t()
  defp tone_fill(:ok), do: "#006000"
  defp tone_fill(:warn), do: "#805000"
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

  defp kind_label(:pinned),
    do: dgettext("diagrams", "A miniature of the room with its pinned line across the top")

  defp kind_label(:roster),
    do:
      dgettext(
        "diagrams",
        "A miniature of the list that shows these. Each row has a lamp for its state."
      )

  defp kind_label(:checklist),
    do:
      dgettext(
        "diagrams",
        "A miniature of a list of choices. Nothing is selected yet."
      )

  defp kind_label(:highlighted),
    do:
      dgettext(
        "diagrams",
        "A miniature of the conversation with the matching line wearing its highlight"
      )

  defp kind_label(:hidden),
    do:
      dgettext(
        "diagrams",
        "A miniature of a conversation with a grey bar where the hidden line was"
      )

  defp kind_label(:fields),
    do: dgettext("diagrams", "A miniature of the settings sheet, each name beside its value")

  defp kind_label(:relay),
    do:
      dgettext(
        "diagrams",
        "A miniature of two people and the relay that carries the call between them"
      )

  defp kind_label(:broadcast),
    do: dgettext("diagrams", "A miniature of one line arriving in every window at once")

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
