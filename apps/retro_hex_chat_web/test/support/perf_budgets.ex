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

      surface     before (raw)   before (nodes)
      /connect       191_772 B          1_804
      /chat          568_352 B              —
      help           611_705 B          6_049
  """

  @doc """
  The largest a surface's dead render may be, in bytes of HTML.
  """
  @spec html_bytes(atom()) :: pos_integer()
  def html_bytes(:connect), do: 115_000
  def html_bytes(:help), do: 300_000

  @doc """
  The most elements a surface's dead render may contain.
  """
  @spec dom_nodes(atom()) :: pos_integer()
  def dom_nodes(:connect), do: 1_060
  def dom_nodes(:help), do: 2_900

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
