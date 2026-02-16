defmodule RetroHexChatWeb.LiveViewCase do
  @moduledoc """
  Test case template for LiveView tests that need database access
  and the full OTP tree running.
  """

  use ExUnit.CaseTemplate

  using do
    quote do
      @endpoint RetroHexChatWeb.Endpoint
      use RetroHexChatWeb, :verified_routes
      import Plug.Conn
      import Phoenix.ConnTest
      import Phoenix.LiveViewTest
      import RetroHexChatWeb.LiveViewCase
    end
  end

  setup tags do
    RetroHexChat.DataCase.setup_sandbox(tags)
    {:ok, conn: Phoenix.ConnTest.build_conn()}
  end

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
