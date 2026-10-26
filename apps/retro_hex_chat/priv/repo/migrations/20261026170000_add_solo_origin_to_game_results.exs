defmodule RetroHexChat.Repo.Migrations.AddSoloOriginToGameResults do
  use Ecto.Migration

  # A match played alone (a one-player game) is a third origin beside a match
  # against the computer and one between two people.
  def up do
    drop constraint(:game_results, :game_results_origin_check)

    create constraint(:game_results, :game_results_origin_check,
             check: "origin IN ('ai', 'p2p', 'solo')"
           )
  end

  def down do
    execute "DELETE FROM game_results WHERE origin = 'solo'"
    drop constraint(:game_results, :game_results_origin_check)
    create constraint(:game_results, :game_results_origin_check, check: "origin IN ('ai', 'p2p')")
  end
end
