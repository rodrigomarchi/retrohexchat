defmodule RetroHexChat.VirtualSpace.Maps.GameRoom do
  @moduledoc """
  The Game Room: a furnished floor floating in the End of Time's sky, behind the
  neon door across the north bridge from the green gate. A row of arcade
  cabinets, a pool table and a ping-pong table, a lounge of beanbags and a LAN
  corner stand around a clear centre, and the people inside add to it with the
  Construct's own pieces.

  Authored by `virtual.space/tools/author_game_room.py`, which writes
  `priv/maps/game_room.json` from the Construct's catalog and sheets; it is read
  by `Maps.Construct`, whose moduledoc describes the fields. The furniture it
  comes with is its `fixed_items`, which `VirtualSpace.Construct.Layout` draws
  and lets people use like any piece, and never lets them move.
  """

  alias RetroHexChat.VirtualSpace.Maps.Construct

  @spec definition() :: map()
  def definition, do: Construct.definition("game_room")
end
