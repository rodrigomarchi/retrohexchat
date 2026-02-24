defmodule RetroHexChat.Games.RateLimitTable do
  @moduledoc """
  Owns the ETS table for game session rate limiting.
  Started as an Agent in the supervision tree.
  """

  use Agent

  @table_name :game_rate_limits

  @spec start_link(keyword()) :: Agent.on_start()
  def start_link(_opts) do
    Agent.start_link(
      fn ->
        :ets.new(@table_name, [:set, :public, :named_table])
      end,
      name: __MODULE__
    )
  end

  @spec table_name() :: atom()
  def table_name, do: @table_name
end
