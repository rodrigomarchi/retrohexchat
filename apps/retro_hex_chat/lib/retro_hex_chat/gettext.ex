defmodule RetroHexChat.Gettext do
  @moduledoc """
  Gettext backend for domain/application strings.
  """

  use Gettext.Backend, otp_app: :retro_hex_chat
end
