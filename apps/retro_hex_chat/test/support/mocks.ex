defmodule RetroHexChat.TestMocks do
  @moduledoc """
  Mox mock definitions. Mocks are added here as behaviours are created.
  """

  Mox.defmock(RetroHexChat.Chat.LinkPreviewMock, for: RetroHexChat.Chat.LinkPreview)
  Mox.defmock(RetroHexChat.Commands.MockHandler, for: RetroHexChat.Commands.Handler)
end
