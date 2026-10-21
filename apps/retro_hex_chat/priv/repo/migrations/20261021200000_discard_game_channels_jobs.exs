defmodule RetroHexChat.Repo.Migrations.DiscardGameChannelsJobs do
  use Ecto.Migration

  # The worker that kept the Retro Games channels no longer exists; a job of
  # it still waiting would fail on every attempt for want of its module.
  def up do
    execute """
    DELETE FROM oban_jobs
    WHERE worker = 'RetroHexChat.Jobs.GameChannelsWorker'
      AND state IN ('available', 'scheduled', 'retryable')
    """
  end

  def down, do: :ok
end
