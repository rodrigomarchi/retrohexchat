defmodule RetroHexChat.Channels.Visibility do
  @moduledoc """
  Which of someone's channels another person is allowed to be told about.

  `/whois` and the hover card both answer this, and the answer is not simply
  "every channel they are in": a channel marked `+s` is secret, and naming it to
  somebody who is not in it would leak the channel's existence along with its
  membership. Somebody already in it learns nothing new, so for them it is
  listed.

  Reading it goes through `Channels.Directory`, whose snapshot already carries
  each channel's `secret?` — so the only thing still worth a message to a
  channel process is its member list, one question per channel rather than two.
  A channel whose process cannot be reached contributes nothing rather than
  raising: this describes where somebody is, and a channel that is not answering
  is a channel nobody is being told about.
  """

  alias RetroHexChat.Channels.Directory
  alias RetroHexChat.Channels.Server

  @doc """
  The channels `target` is in, as far as a viewer already in `viewer_channels`
  may know, alphabetically.
  """
  @spec channels_of(String.t(), [String.t()]) :: [String.t()]
  def channels_of(target, viewer_channels)
      when is_binary(target) and is_list(viewer_channels) do
    wanted = String.downcase(target)

    Directory.all()
    |> Enum.filter(&tellable?(&1, viewer_channels))
    |> Enum.filter(&member?(&1.name, wanted))
    |> Enum.map(& &1.name)
    |> Enum.sort()
  end

  # Cheaper than asking the channel, so it runs first: a secret channel the
  # viewer is not in is dropped without a message being sent at all.
  defp tellable?(%{secret?: true, name: name}, viewer_channels), do: name in viewer_channels
  defp tellable?(_snapshot, _viewer_channels), do: true

  defp member?(channel_name, wanted) do
    case Server.get_state(channel_name) do
      {:ok, state} ->
        Enum.any?(state.members, fn {nick, _role} -> String.downcase(nick) == wanted end)

      {:error, _unreachable} ->
        false
    end
  end
end
