defmodule RetroHexChatWeb.ConnCase do
  @moduledoc """
  This module defines the test case to be used by
  tests that require setting up a connection.

  Such tests rely on `Phoenix.ConnTest` and also
  import other functionality to make it easier
  to build common data structures and query the data layer.

  Finally, if the test case interacts with the database,
  we enable the SQL sandbox, so changes done to the database
  are reverted at the end of every test. If you are using
  PostgreSQL, you can even run database tests asynchronously
  by setting `use RetroHexChatWeb.ConnCase, async: true`, although
  this option is not recommended for other databases.
  """

  use ExUnit.CaseTemplate

  using do
    quote do
      # The default endpoint for testing
      @endpoint RetroHexChatWeb.Endpoint

      use RetroHexChatWeb, :verified_routes

      # Import conveniences for testing with connections
      import Plug.Conn
      import Phoenix.ConnTest
      import RetroHexChatWeb.ConnCase
    end
  end

  setup tags do
    RetroHexChat.DataCase.setup_sandbox(tags)
    {:ok, conn: Phoenix.ConnTest.build_conn()}
  end

  @doc """
  Returns a short unique integer suitable for use in test nicknames.
  Capped at 5 digits to stay within the 16-char IRC nickname limit.
  """
  @spec uid() :: non_neg_integer()
  def uid, do: rem(System.unique_integer([:positive]), 100_000)

  @doc """
  Returns a connection with the chat session initialized for the given nickname.
  Use this instead of appending `?nickname=X` to the URL.
  """
  @spec chat_conn(Plug.Conn.t(), String.t(), keyword()) :: Plug.Conn.t()
  def chat_conn(conn, nickname, opts \\ []) do
    session = %{"chat_nickname" => nickname}

    session =
      if Keyword.get(opts, :pre_identified, false) do
        Map.put(session, "chat_pre_identified", true)
      else
        session
      end

    Phoenix.ConnTest.init_test_session(conn, session)
  end
end
