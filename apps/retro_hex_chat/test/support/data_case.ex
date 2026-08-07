defmodule RetroHexChat.DataCase do
  @moduledoc """
  This module defines the setup for tests requiring
  access to the application's data layer.

  You may define functions here to be used as helpers in
  your tests.

  Finally, if the test case interacts with the database,
  we enable the SQL sandbox, so changes done to the database
  are reverted at the end of every test. If you are using
  PostgreSQL, you can even run database tests asynchronously
  by setting `use RetroHexChat.DataCase, async: true`, although
  this option is not recommended for other databases.
  """

  use ExUnit.CaseTemplate

  alias Ecto.Adapters.SQL.Sandbox
  alias RetroHexChat.Scraper.Cache, as: ScraperCache

  using do
    quote do
      alias RetroHexChat.Repo

      use Oban.Testing, repo: RetroHexChat.Repo

      import Ecto
      import Ecto.Changeset
      import Ecto.Query
      import RetroHexChat.DataCase
    end
  end

  setup tags do
    RetroHexChat.DataCase.setup_sandbox(tags)
    :ok
  end

  @doc """
  Sets up the sandbox based on the test tags.
  """
  def setup_sandbox(tags) do
    pid = Sandbox.start_owner!(RetroHexChat.Repo, shared: not tags[:async])

    # ETS caches derived from sandboxed tables do not roll back with them. Left
    # alone, a scrape one test recorded as failed is still cached when the next
    # test starts, and that test silently gets the previous test's answer instead
    # of reaching its own stub.
    ScraperCache.clear()

    on_exit(fn ->
      ScraperCache.clear()
      Sandbox.stop_owner(pid)
    end)
  end

  @doc """
  A helper that transforms changeset errors into a map of messages.

      assert {:error, changeset} = Accounts.create_user(%{password: "short"})
      assert "password is too short" in errors_on(changeset).password
      assert %{password: ["password is too short"]} = errors_on(changeset)

  """
  def errors_on(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {message, opts} ->
      Regex.replace(~r"%{(\w+)}", message, fn _, key ->
        opts |> Keyword.get(String.to_existing_atom(key), key) |> to_string()
      end)
    end)
  end
end
