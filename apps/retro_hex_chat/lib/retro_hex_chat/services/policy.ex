defmodule RetroHexChat.Services.Policy do
  @moduledoc "Authorization checks for NickServ and ChanServ services."

  alias RetroHexChat.Services.NickServ

  @spec identify_required?(String.t()) :: boolean()
  def identify_required?(nickname) do
    NickServ.registered?(nickname)
  end

  @spec identified?(String.t()) :: boolean()
  def identified?(nickname) do
    case NickServ.info(nickname) do
      {:ok, %{identified: true}} -> true
      _ -> false
    end
  end
end
