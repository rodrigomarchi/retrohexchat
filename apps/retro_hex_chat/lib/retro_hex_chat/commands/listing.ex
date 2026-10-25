defmodule RetroHexChat.Commands.Listing do
  @moduledoc """
  The text of a command that lists things — channels, bans, settings, log
  entries: a line saying there are none, or a header followed by one line
  per item. The words stay in each command, so gettext finds them there.
  """

  @doc """
  `empty` when there are no items; otherwise the header `header` builds from
  the number of items, then each item through `line`, one per line.
  """
  @spec text(list(), String.t(), (non_neg_integer() -> String.t()), (term() -> String.t())) ::
          String.t()
  def text([], empty, _header, _line), do: empty

  def text(items, _empty, header, line) do
    Enum.join([header.(length(items)) | Enum.map(items, line)], "\n")
  end
end
