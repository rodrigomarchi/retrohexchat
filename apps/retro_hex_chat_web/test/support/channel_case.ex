defmodule RetroHexChatWeb.ChannelCase do
  @moduledoc """
  This module defines the test case to be used by Phoenix Channel tests.

  Channels connect through `RetroHexChatWeb.UserSocket` and talk to domain
  processes backed by the database, so the SQL sandbox is enabled exactly
  like `RetroHexChat.DataCase`.
  """

  use ExUnit.CaseTemplate

  using do
    quote do
      import Phoenix.ChannelTest
      import RetroHexChatWeb.ChannelCase

      @endpoint RetroHexChatWeb.Endpoint
    end
  end

  setup tags do
    RetroHexChat.DataCase.setup_sandbox(tags)
    :ok
  end
end
