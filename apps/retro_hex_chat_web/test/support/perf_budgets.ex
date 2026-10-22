defmodule RetroHexChatWeb.PerfBudgets do
  @moduledoc """
  What a page is allowed to weigh, and how long a mount is allowed to block.

  A budget catches a regression; it does not describe today. Each number is the
  target plus roughly 10% headroom, so ordinary work passes and a step change
  has to be argued for — the same contract `assets/scripts/bundle_budget.cjs`
  holds the JS bundles to.

  The baselines these replace were measured against production on 2026-08-20,
  from a load test whose RUM showed LCP p50 of 2664 ms on `/chat` with 82% of it
  spent rendering rather than waiting on the server. Inline SVG was 56% of the
  `/connect` document and 65% of a help page, half of it duplicate drawings.

      surface     before (raw)   before (gzip)   before (nodes)
      /connect       191_772 B        22_814 B            1_804
      /chat          568_352 B        57_712 B                —
      help           611_705 B        51_594 B            6_049

  Raised once since, on 2026-08-21, when the Start menu became a superset of
  every menu bar: it carries every entry on every screen, gray where the screen
  cannot reach it, so completing the set added the same 177 rows everywhere.

      surface     Δ raw      Δ gzip     Δ nodes
      /connect    +17_628 B   +1_056 B     +177
      help        +17_161 B   +1_076 B     +177
      landing     +17_234 B   +1_035 B     +177

  Raw grew by 17 KB and the wire by 1 KB: the rows are near-identical markup and
  compress by 94%, the same effect that took `/chat` from 57_712 B to 7_599 B.
  The node count is the half that is not free, and it is the half these numbers
  are really guarding — a node costs main-thread time no compressor gives back.
  """

  @doc """
  The largest a surface's dead render may be, in bytes of HTML.
  """
  @spec html_bytes(atom()) :: pos_integer()
  # The sign-in window over the chat's frame: 84_675 B raw and 904 elements
  # measured on 2026-10-16.
  def html_bytes(:connect), do: 93_000
  # 243_104 B raw at 297 topics, measured 2026-10-02, down from 303_678 B on
  # 2026-09-28 — the page is unchanged; what left was repeated `class` attributes,
  # now project classes in the stylesheet. The index still draws a row per topic
  # and a topic is still mandatory for anything with a control surface, so this
  # number tracks documented features rather than bloat. Room for roughly fifty
  # more at the new per-row cost; past that the question is what the index should
  # show, not what it may weigh — and the element count, not this, is the tighter
  # guard on that.
  def html_bytes(:help), do: 265_000
  # A member's desktop before the chat is live: its chrome and the chat window
  # saying it is opening. The chat's body, menus, folders and dialogs arrive
  # with the connected render. 50_174 B raw and 530 elements measured on
  # 2026-10-16, down from 92_554 B when the dialogs' mount points came first.
  def html_bytes(:chat), do: 56_000
  # The first surface that is not the chat. 39_284 B raw / 3_566 B gzip and 267
  # elements measured on 2026-08-28, with every icon a `<use>` reference. It is
  # this small because it carries no taskbar and no Start menu — whether a
  # single-purpose surface should is an open question, and this number is what
  # answering it costs against.
  def html_bytes(:play), do: 44_000
  # The conference at an address of its own, measured at its antechamber — the
  # state everyone arrives in, and the only one a dead render can show. 26_118 B
  # raw / 4_920 B gzip and 233 elements measured on 2026-08-28. Smaller than
  # `/play` because the antechamber is a form and a roster; the conference
  # panel itself only exists after the connected render.
  def html_bytes(:call), do: 29_000
  # The space at an address of its own, measured at its antechamber — the state
  # everyone arrives in, and the only one a dead render can show. 12_481 B raw /
  # 2_991 B gzip and 107 elements measured on 2026-08-30, the smallest surface
  # here: the world it opens onto is a canvas the client fills, so none of it is
  # in the document. 14_449 B raw measured on 2026-10-14, with the character
  # creator open on the skin's colours, its first tab.
  def html_bytes(:space), do: 16_000
  # The P2P session at an address of its own, measured at its starting room —
  # the state everyone arrives in, and the only one a dead render can show.
  # 27_360 B raw and 248 elements measured on 2026-08-30. The largest of the
  # three antechambers, because it is the only one carrying a device form, a
  # camera preview and a roster at once; the session console itself only exists
  # after the host presses Start.
  def html_bytes(:p2p), do: 30_000
  # The public card a shared link resolves to, opened as a window of the one
  # desktop over the chat it invites into. About 86_000 B raw and 946 elements
  # measured on 2026-10-16: the card is the small part, and the rest is the
  # desktop a stranger lands on and stays on — the chat's frame, the taskbar
  # and a Start menu of the pages, the languages and the help.
  def html_bytes(:join), do: 95_000
  # The home: the chat's frame in front, and the home's windows — every section
  # the landing page carried — closed on the desk behind it, with a visitor's
  # icon for every page. 151_774 B raw and 1_469 elements measured on
  # 2026-10-16, against 229_594 B and about 2_300 elements for the landing page
  # it replaced — the desktop's own folders, menus and dialogs arrive with the
  # chat, not with the page. The Start menu's groups are there from the first
  # paint, empty, so the menu does not rearrange itself when the chat starts.
  # Raised on 2026-10-22, when the Arcade window began listing its games under
  # their engines, each a link to its page, as the Multiplayer window beside it
  # lists its own: 167_369 B and 1_668 elements measured with the list, the
  # baseline these two budgets now hold 10% above.
  def html_bytes(:home), do: 184_000
  # The largest page of the site — `/features`, twelve windows, 167_275 B raw
  # and 1_652 elements measured on 2026-10-16 (235_526 B as a page of its own).
  # Each section is a window of its own now, with the title bar, controls and
  # resize edges a window carries, and the site's About rides beside the page.
  # Every other page fits under it.
  def html_bytes(:page), do: 184_000
  # A channel's address for a visitor: the desktop with the chat opening in it,
  # and the visitor's icon for every page of the site. 55_261 B raw and 581
  # elements measured on 2026-10-16.
  def html_bytes(:channel), do: 61_000

  @doc """
  The most elements a surface's dead render may contain.
  """
  @spec dom_nodes(atom()) :: pos_integer()
  def dom_nodes(:connect), do: 995
  # 3_030 measured at 297 topics on 2026-09-28. This is the half that costs
  # main-thread time, and the tighter of the two.
  def dom_nodes(:help), do: 3_200
  def dom_nodes(:chat), do: 580
  def dom_nodes(:play), do: 300
  def dom_nodes(:call), do: 260
  def dom_nodes(:space), do: 120
  def dom_nodes(:p2p), do: 270
  def dom_nodes(:join), do: 1_040
  def dom_nodes(:home), do: 1_840
  def dom_nodes(:page), do: 1_800
  def dom_nodes(:channel), do: 640

  @doc """
  The longest a connected mount may block before it renders.

  It used to sit on a 1000 ms `receive` waiting for a previous session to hand
  over — measured at 1486 ms end to end when the previous session was already
  gone and could never answer, against ~50 ms when it was there.
  """
  @spec connected_mount_ms() :: pos_integer()
  def connected_mount_ms, do: 600

  @doc """
  Counts the HTML elements in a rendered document, the way a browser would.
  """
  @spec count_elements(String.t()) :: non_neg_integer()
  def count_elements(html) do
    ~r/<[a-zA-Z][a-zA-Z0-9-]*[\s>\/]/
    |> Regex.scan(html)
    |> length()
  end

  @doc """
  Counts non-overlapping occurrences of a literal in a document.
  """
  @spec count(String.t(), String.t()) :: non_neg_integer()
  def count(html, needle) do
    html |> String.split(needle) |> length() |> Kernel.-(1)
  end
end
