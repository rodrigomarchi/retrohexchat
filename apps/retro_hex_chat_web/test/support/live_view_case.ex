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
end
