defmodule RetroHexChat.Repo.Migrations.CreateGameResults do
  use Ecto.Migration

  def change do
    create table(:game_results) do
      add :game_id, :string, size: 30, null: false
      add :base_id, :string, size: 30, null: false
      add :origin, :string, size: 8, null: false
      add :difficulty, :string, size: 8
      add :p1_id, references(:registered_nicks, on_delete: :nilify_all)
      add :p1_nickname, :string, size: 16, null: false
      add :p2_id, references(:registered_nicks, on_delete: :nilify_all)
      add :p2_nickname, :string, size: 16
      add :p1_score, :integer, null: false
      add :p2_score, :integer, null: false
      add :outcome, :string, size: 10, null: false
      add :ranked, :boolean, null: false
      add :personal_best, :boolean, null: false, default: false
      add :duration_ms, :integer, null: false
      add :started_at, :utc_datetime_usec, null: false
      add :finished_at, :utc_datetime_usec, null: false
      add :lobby_token, :string, size: 64
      add :channel_message_id, references(:messages, on_delete: :nilify_all)
      add :feed_message_id, references(:messages, on_delete: :nilify_all)
      add :pm_message_id, references(:private_messages, on_delete: :nilify_all)

      timestamps(type: :utc_datetime_usec)
    end

    create index(:game_results, [:base_id, :finished_at])
    create index(:game_results, [:game_id, :origin, :difficulty, :finished_at])
    create index(:game_results, [:p1_id, :game_id])
    create index(:game_results, [:p2_id, :game_id])
    create index(:game_results, [:channel_message_id], where: "channel_message_id IS NOT NULL")
    create index(:game_results, [:feed_message_id], where: "feed_message_id IS NOT NULL")
    create index(:game_results, [:pm_message_id], where: "pm_message_id IS NOT NULL")

    # One row per game a lobby session plays: the session's process may report
    # the same finish twice across a restart, and the second write must lose.
    create unique_index(:game_results, [:lobby_token, :started_at],
             where: "lobby_token IS NOT NULL"
           )

    create constraint(:game_results, :game_results_origin_check, check: "origin IN ('ai', 'p2p')")

    create constraint(:game_results, :game_results_outcome_check,
             check: "outcome IN ('p1', 'p2', 'draw', 'coop_win', 'coop_loss', 'none')"
           )
  end
end
