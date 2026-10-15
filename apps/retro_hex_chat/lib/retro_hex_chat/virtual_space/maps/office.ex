defmodule RetroHexChat.VirtualSpace.Maps.Office do
  @moduledoc """
  The Office: a furnished floor floating in the End of Time's sky, behind the
  wooden door south of the arrival lamp. Reception, desks, a meeting room, a
  kitchenette and filing stand around a clear centre, and the people inside add
  to it with the Construct's own pieces.

  Authored by `virtual.space/tools/author_office.py`, which writes
  `priv/maps/office.json` from the Construct's catalog and sheets; it is read by
  `Maps.Construct`, whose moduledoc describes the fields. The furniture it
  comes with is its `fixed_items`, which `VirtualSpace.Construct.Layout` draws
  and lets people use like any piece, and never lets them move.
  """

  alias RetroHexChat.VirtualSpace.Maps.Construct

  @spec definition() :: map()
  def definition, do: Construct.definition("office")
end
