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

  alias RetroHexChat.Nickname

  alias RetroHexChat.Channels.Directory
  alias RetroHexChat.Channels.Modes
  alias RetroHexChat.Channels.Server
  alias RetroHexChat.Services.Queries, as: ServiceQueries

  @doc """
  The channels `target` is in, as far as a viewer already in `viewer_channels`
  may know, alphabetically.
  """
  @spec channels_of(String.t(), [String.t()]) :: [String.t()]
  def channels_of(target, viewer_channels)
      when is_binary(target) and is_list(viewer_channels) do
    wanted = Nickname.key(target)

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
    case visibility_modes(channel_name) do
      %{} = modes -> not (modes.secret or modes.private or modes.invite_only)
      nil -> false
    end
  end

  def nameable?(_channel_name), do: false

  @doc """
  Whether somebody without an account may read `channel_name` — what a visitor
  watching it sees, attachments included.

  Stricter again than `nameable?/1`: a channel may be named to a stranger and
  still be locked with a key, and a key is a door a reader without one does
  not get through. Same answer as `Modes.watchable?/1`, which the channel itself
  applies when a visitor asks to watch it.
  """
  @spec watchable?(term()) :: boolean()
  def watchable?(channel_name) when is_binary(channel_name) do
    case visibility_modes(channel_name) do
      %{} = modes -> not (modes.secret or modes.private or modes.invite_only or modes.key?)
      nil -> false
    end
  end

  def watchable?(_channel_name), do: false

  # The modes that decide who may see a channel, from its process when it has
  # one. A registered channel that nobody has joined since the node started has
  # no process, and a node restarts on every deploy. Answering "not visible"
  # for one refused to let a link to a perfectly public room say its own name;
  # the modes it would have come up with are in the row it would have come up
  # from. A channel with neither answers nothing.
  defp visibility_modes(channel_name) do
    case Server.get_state(channel_name) do
      {:ok, %{modes_detail: modes}} ->
        %{
          secret: Map.get(modes, :secret, false),
          private: Map.get(modes, :private, false),
          invite_only: Map.get(modes, :invite_only, false),
          key?: Map.get(modes, :key) not in [nil, ""]
        }

      _unreachable ->
        cold_visibility_modes(channel_name)
    end
  end

  defp cold_visibility_modes(channel_name) do
    case ServiceQueries.find_registered_channel(channel_name) do
      nil ->
        nil

      channel ->
        modes = Modes.from_string(channel.modes)

        %{
          secret: Modes.secret?(modes),
          private: Modes.private?(modes),
          invite_only: Modes.invite_only?(modes),
          key?: Modes.has_key?(modes)
        }
    end
  end

  # Cheaper than asking the channel, so it runs first: a secret channel the
  # viewer is not in is dropped without a message being sent at all.
  defp tellable?(%{secret?: true, name: name}, viewer_channels), do: name in viewer_channels
  defp tellable?(_snapshot, _viewer_channels), do: true

  defp member?(channel_name, wanted) do
    case Server.get_state(channel_name) do
      {:ok, state} ->
        Enum.any?(state.members, fn {nick, _role} -> Nickname.key(nick) == wanted end)

      {:error, _unreachable} ->
        false
    end
  end
end
