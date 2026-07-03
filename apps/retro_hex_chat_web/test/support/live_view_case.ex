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

  @doc """
  Submits a composer command and waits for it to be processed.

  The Composer bubbles commands to the LiveView via `send/2`, so the command
  runs AFTER `render_submit` returns; `render/1` is a synchronous call
  processed behind it in the mailbox — once it returns, the command completed.
  """
  @spec submit_command_sync(Phoenix.LiveViewTest.View.t(), String.t()) :: String.t()
  def submit_command_sync(view, command) do
    import Phoenix.LiveViewTest

    view
    |> element(~s([data-testid="chat-input-form"]))
    |> render_submit(%{"input" => command})

    render(view)
  end
end
