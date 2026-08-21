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
  def html_bytes(:connect), do: 132_000
  def html_bytes(:help), do: 310_000
  # /chat's disconnected render is the boot overlay and the dialog mount points:
  # the desktop under it is invisible and arrives with the connected render.
  # 92_554 B raw measured, but 7_599 B gzipped — the dialog chrome repeats, so
  # the wire cost fell from 57_712 B to 7_599 B.
  def html_bytes(:chat), do: 105_000

  @doc """
  The most elements a surface's dead render may contain.
  """
  @spec dom_nodes(atom()) :: pos_integer()
  def dom_nodes(:connect), do: 1_260
  def dom_nodes(:help), do: 3_090
  def dom_nodes(:chat), do: 600

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
