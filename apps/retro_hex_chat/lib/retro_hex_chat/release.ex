defmodule RetroHexChat.Release do
  @moduledoc """
  Tasks for running migrations in a production release.

  Usage:

      bin/retro_hex_chat eval "RetroHexChat.Release.migrate()"
  """

  alias RetroHexChat.Nickname.Uniqueness

  @app :retro_hex_chat

  @spec migrate :: :ok
  def migrate do
    load_app()

    for repo <- repos() do
      {:ok, _, _} = Ecto.Migrator.with_repo(repo, &Ecto.Migrator.run(&1, :up, all: true))
    end

    :ok
  end

  @doc """
  Lists rows whose nicknames differ only by case — run it before a deploy that
  builds case-insensitive unique indexes. Read-only; `[]` means clear.
  """
  @spec check_nickname_duplicates() :: [{String.t(), list()}]
  def check_nickname_duplicates do
    load_app()

    Enum.flat_map(repos(), fn repo ->
      {:ok, found, _} =
        Ecto.Migrator.with_repo(repo, &Uniqueness.duplicates/1)

      found
    end)
  end

  @spec rollback(module(), integer()) :: :ok
  def rollback(repo, version) do
    load_app()
    {:ok, _, _} = Ecto.Migrator.with_repo(repo, &Ecto.Migrator.run(&1, :down, to: version))
    :ok
  end

  defp repos do
    Application.fetch_env!(@app, :ecto_repos)
  end

  defp load_app do
    Application.load(@app)
  end
end
