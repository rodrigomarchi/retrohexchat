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

  @doc """
  Whether `channel_name` may be named to somebody who is not in it and may not
  be in the product at all.

  Stricter than the rule `channels_of/2` uses, and deliberately so. That one
  answers for a viewer already inside, asking about a person, where the only
  thing worth withholding is `+s`. This one answers for a card handed to a
  stranger — a shared link, a social preview, the address bar — where naming the
  channel *is* the leak, so `+p` and `+i` count too.

  A channel whose process is not answering is not nameable. Silence is not
  permission, and the one place this is asked from is the one place a wrong
  answer is public.
  """
  @spec nameable?(term()) :: boolean()
  def nameable?(channel_name) when is_binary(channel_name) do
    case Server.get_state(channel_name) do
      {:ok, %{modes_detail: modes}} ->
        not (Map.get(modes, :secret, false) or Map.get(modes, :private, false) or
               Map.get(modes, :invite_only, false))

      _unreachable ->
        false
    end
  end

  def nameable?(_channel_name), do: false

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
