defmodule RetroHexChat.Accounts.Session do
  @moduledoc """
  In-memory session struct representing a connected user's state.
  Lives in the LiveView socket assigns, not persisted to DB.
  """

  alias RetroHexChat.Accounts.ContactList
  alias RetroHexChat.Accounts.NickColors
  alias RetroHexChat.Chat.AutoJoinList
  alias RetroHexChat.Chat.ContextualTips
  alias RetroHexChat.Chat.FloodProtection
  alias RetroHexChat.Chat.HighlightWords
  alias RetroHexChat.Chat.IgnoreList
  alias RetroHexChat.Chat.InputHistory
  alias RetroHexChat.Chat.PerformList
  alias RetroHexChat.Chat.SoundSettings

  alias RetroHexChat.Nickname
  alias RetroHexChat.Presence.NotifyList

  @type t :: %__MODULE__{
          nickname: String.t(),
          account: String.t() | nil,
          channels: [String.t()],
          active_channel: String.t() | nil,
          pm_conversations: [String.t()],
          pm_conversations_truncated: boolean(),
          active_pm: String.t() | nil,
          identified: boolean(),
          connected_at: DateTime.t(),
          away: boolean(),
          away_message: String.t() | nil,
          strip_formatting: boolean(),
          show_avatars: boolean(),
          notify_list: map(),
          contacts: map(),
          nick_colors: map(),
          highlight_words: map(),
          ignore_list: map(),
          perform_list: map(),
          autojoin_list: map(),
          auto_join_on_invite: boolean(),
          notice_routing: :active | :status | :sender,
          contextual_tips: map(),
          input_history: map(),
          flood_protection: map(),
          sound_settings: map(),
          aliases: map(),
          custom_menus: map(),
          autorespond_rules: map(),
          bio: String.t() | nil,
          last_message_at: DateTime.t(),
          user_modes: map(),
          welcomed_channels: map()
        }

  @enforce_keys [:nickname]
  defstruct [
    :nickname,
    # The registration this person proved, in its registered spelling — what
    # every per-user record is filed under. `nickname` is how they chose to be
    # shown, and may differ from it by case. Nil until identified.
    account: nil,
    channels: [],
    active_channel: nil,
    pm_conversations: [],
    pm_conversations_truncated: false,
    active_pm: nil,
    identified: false,
    connected_at: nil,
    away: false,
    away_message: nil,
    strip_formatting: false,
    show_avatars: true,
    notify_list: nil,
    contacts: nil,
    nick_colors: nil,
    highlight_words: nil,
    ignore_list: nil,
    perform_list: nil,
    autojoin_list: nil,
    auto_join_on_invite: false,
    notice_routing: :active,
    contextual_tips: nil,
    input_history: nil,
    flood_protection: nil,
    sound_settings: nil,
    aliases: nil,
    custom_menus: nil,
    autorespond_rules: nil,
    bio: nil,
    last_message_at: nil,
    user_modes: nil,
    welcomed_channels: nil
  ]

  @spec new(String.t()) :: t()
  def new(nickname) do
    %__MODULE__{
      nickname: nickname,
      connected_at: DateTime.utc_now(),
      notify_list: NotifyList.new(),
      contacts: ContactList.new(),
      nick_colors: NickColors.new(),
      highlight_words: HighlightWords.new(),
      ignore_list: IgnoreList.new(),
      perform_list: PerformList.new(),
      autojoin_list: AutoJoinList.new(),
      contextual_tips: ContextualTips.new(),
      input_history: InputHistory.new(),
      flood_protection: FloodProtection.new(),
      sound_settings: SoundSettings.new(),
      aliases: %{entries: []},
      custom_menus: %{entries: []},
      autorespond_rules: %{entries: []},
      last_message_at: DateTime.utc_now(),
      user_modes: MapSet.new(),
      welcomed_channels: MapSet.new()
    }
  end

  @spec update_nickname(t(), String.t()) :: t()
  def update_nickname(%__MODULE__{} = session, new_nickname) do
    # A change of case is the same person: the account stays. Any other change
    # is somebody who has not proved anything yet.
    account = if Nickname.equal?(session.nickname, new_nickname), do: session.account
    %{session | nickname: new_nickname, account: account}
  end

  @spec add_channel(t(), String.t()) :: t()
  def add_channel(%__MODULE__{channels: channels} = session, channel_name) do
    if channel_name in channels do
      session
    else
      %{session | channels: channels ++ [channel_name]}
    end
  end

  @spec remove_channel(t(), String.t()) :: t()
  def remove_channel(
        %__MODULE__{channels: channels, active_channel: active} = session,
        channel_name
      ) do
    new_channels = List.delete(channels, channel_name)
    new_active = if active == channel_name, do: List.first(new_channels), else: active
    %{session | channels: new_channels, active_channel: new_active}
  end

  @spec set_identified(t(), boolean()) :: t()
  def set_identified(%__MODULE__{} = session, true), do: %{session | identified: true}

  def set_identified(%__MODULE__{} = session, false) do
    %{session | identified: false, account: nil}
  end

  @doc """
  Whether `nickname` is this identified person's own nickname in another case —
  a change that needs no password: they have already proved who they are, and a
  different case is not a different person.
  """
  @spec case_change?(t(), String.t()) :: boolean()
  def case_change?(%__MODULE__{identified: true, nickname: current}, nickname),
    do: Nickname.equal?(current, nickname)

  def case_change?(%__MODULE__{}, _nickname), do: false

  @doc """
  Identified, as the registration `account` — its registered spelling, which may
  differ by case from the nickname shown.
  """
  @spec identified_as(t(), String.t() | nil) :: t()
  def identified_as(%__MODULE__{} = session, account),
    do: %{session | identified: true, account: account}

  @doc """
  The name this person's records are filed under: their account — the spelling
  it was registered under — once they have identified. Every read and write of
  per-user data asks this rather than `nickname`, which may differ by case. A
  guest has no account, so their own nickname stands in; nothing of theirs is
  filed anyway, since every per-user table belongs to a registration.
  """
  @spec owner(t()) :: String.t()
  def owner(%__MODULE__{account: account}) when is_binary(account), do: account
  def owner(%__MODULE__{nickname: nickname}), do: nickname

  @spec identity_state(t()) :: :away | :identified | :guest
  def identity_state(%__MODULE__{away: true}), do: :away
  def identity_state(%__MODULE__{identified: true}), do: :identified
  def identity_state(%__MODULE__{}), do: :guest

  @spec set_active_channel(t(), String.t() | nil) :: t()
  def set_active_channel(%__MODULE__{} = session, channel_name) do
    %{session | active_channel: channel_name, active_pm: nil}
  end

  @spec add_pm_conversation(t(), String.t()) :: t()
  def add_pm_conversation(%__MODULE__{pm_conversations: pms} = session, nickname) do
    %{session | pm_conversations: [nickname | Nickname.without(pms, nickname)]}
  end

  @spec move_pm_to_front(t(), String.t()) :: t()
  def move_pm_to_front(%__MODULE__{pm_conversations: pms} = session, nickname) do
    if Nickname.member?(pms, nickname) do
      %{session | pm_conversations: [nickname | Nickname.without(pms, nickname)]}
    else
      session
    end
  end

  @doc """
  Take a private conversation off the sidebar.

  The list is of conversations, not of unread things: dropping one says the
  person is done with it, and it says nothing about whether they read it. The
  messages stay in the database and the next line from that nickname puts the
  conversation back — this is a dismissal, not a delete.
  """
  @spec remove_pm_conversation(t(), String.t()) :: t()
  def remove_pm_conversation(
        %__MODULE__{pm_conversations: pms, active_pm: active} = session,
        nick
      ) do
    %{
      session
      | pm_conversations: Nickname.without(pms, nick),
        active_pm: if(Nickname.equal?(active, nick), do: nil, else: active)
    }
  end

  @spec rename_pm_conversation(t(), String.t(), String.t()) :: t()
  def rename_pm_conversation(
        %__MODULE__{pm_conversations: pms, active_pm: active} = session,
        old_nickname,
        new_nickname
      ) do
    new_pms =
      pms
      |> Enum.map(&if(Nickname.equal?(&1, old_nickname), do: new_nickname, else: &1))
      |> Enum.uniq_by(&Nickname.key/1)

    new_active = if Nickname.equal?(active, old_nickname), do: new_nickname, else: active

    %{session | pm_conversations: new_pms, active_pm: new_active}
  end

  @spec set_active_pm(t(), String.t() | nil) :: t()
  def set_active_pm(%__MODULE__{} = session, nickname) do
    %{session | active_pm: nickname, active_channel: nil}
  end

  @doc """
  Turns the character portraits beside nicknames on or off.

  On by default: the chosen character is this product's own visual identity, and
  a person who picked one has said who they are. Off is a real choice all the
  same — the plain mIRC line is the other half of what this looks like, and
  somebody reading a busy channel may want the text and nothing else.
  """
  @spec toggle_show_avatars(t()) :: t()
  def toggle_show_avatars(%__MODULE__{show_avatars: current} = session) do
    %{session | show_avatars: !current}
  end

  @spec toggle_strip_formatting(t()) :: t()
  def toggle_strip_formatting(%__MODULE__{strip_formatting: current} = session) do
    %{session | strip_formatting: !current}
  end

  @spec set_away(t(), String.t() | nil) :: t()
  def set_away(%__MODULE__{} = session, nil) do
    %{session | away: false, away_message: nil}
  end

  def set_away(%__MODULE__{} = session, message) do
    %{session | away: true, away_message: message}
  end

  @spec set_notify_list(t(), map()) :: t()
  def set_notify_list(%__MODULE__{} = session, notify_list) do
    %{session | notify_list: notify_list}
  end

  @spec get_notify_list(t()) :: map()
  def get_notify_list(%__MODULE__{notify_list: notify_list}) do
    notify_list
  end

  @spec set_contacts(t(), map()) :: t()
  def set_contacts(%__MODULE__{} = session, contacts) do
    %{session | contacts: contacts}
  end

  @spec set_nick_colors(t(), map()) :: t()
  def set_nick_colors(%__MODULE__{} = session, nick_colors) do
    %{session | nick_colors: nick_colors}
  end

  @spec set_highlight_words(t(), map()) :: t()
  def set_highlight_words(%__MODULE__{} = session, highlight_words) do
    %{session | highlight_words: highlight_words}
  end

  @spec get_highlight_words(t()) :: map()
  def get_highlight_words(%__MODULE__{highlight_words: highlight_words}) do
    highlight_words
  end

  @spec set_ignore_list(t(), map()) :: t()
  def set_ignore_list(%__MODULE__{} = session, ignore_list) do
    %{session | ignore_list: ignore_list}
  end

  @spec set_perform_list(t(), map()) :: t()
  def set_perform_list(%__MODULE__{} = session, perform_list) do
    %{session | perform_list: perform_list}
  end

  @spec set_autojoin_list(t(), map()) :: t()
  def set_autojoin_list(%__MODULE__{} = session, autojoin_list) do
    %{session | autojoin_list: autojoin_list}
  end

  @spec get_auto_join_on_invite(t()) :: boolean()
  def get_auto_join_on_invite(%__MODULE__{auto_join_on_invite: value}), do: value

  @spec set_auto_join_on_invite(t(), boolean()) :: t()
  def set_auto_join_on_invite(%__MODULE__{} = session, value) when is_boolean(value) do
    %{session | auto_join_on_invite: value}
  end

  @spec toggle_auto_join_on_invite(t()) :: t()
  def toggle_auto_join_on_invite(%__MODULE__{auto_join_on_invite: current} = session) do
    %{session | auto_join_on_invite: not current}
  end

  @spec get_notice_routing(t()) :: :active | :status | :sender
  def get_notice_routing(%__MODULE__{notice_routing: value}), do: value

  @spec set_notice_routing(t(), :active | :status | :sender) :: t()
  def set_notice_routing(%__MODULE__{} = session, routing)
      when routing in [:active, :status, :sender] do
    %{session | notice_routing: routing}
  end

  @spec set_flood_protection(t(), map()) :: t()
  def set_flood_protection(%__MODULE__{} = session, settings) do
    %{session | flood_protection: settings}
  end

  @spec set_input_history(t(), map()) :: t()
  def set_input_history(%__MODULE__{} = session, history) do
    %{session | input_history: history}
  end

  @spec set_contextual_tips(t(), map()) :: t()
  def set_contextual_tips(%__MODULE__{} = session, tips) do
    %{session | contextual_tips: tips}
  end

  @spec set_sound_settings(t(), map()) :: t()
  def set_sound_settings(%__MODULE__{} = session, settings) do
    %{session | sound_settings: settings}
  end

  @spec set_aliases(t(), map()) :: t()
  def set_aliases(%__MODULE__{} = session, aliases) do
    %{session | aliases: aliases}
  end

  @spec set_custom_menus(t(), map()) :: t()
  def set_custom_menus(%__MODULE__{} = session, custom_menus) do
    %{session | custom_menus: custom_menus}
  end

  @spec set_autorespond_rules(t(), map()) :: t()
  def set_autorespond_rules(%__MODULE__{} = session, rules) do
    %{session | autorespond_rules: rules}
  end

  @spec get_bio(t()) :: String.t() | nil
  def get_bio(%__MODULE__{bio: bio}), do: bio

  @spec set_bio(t(), String.t() | nil) :: t()
  def set_bio(%__MODULE__{} = session, bio) do
    %{session | bio: bio}
  end

  @spec set_last_message_at(t(), DateTime.t()) :: t()
  def set_last_message_at(%__MODULE__{} = session, %DateTime{} = timestamp) do
    %{session | last_message_at: timestamp}
  end

  @spec has_mode?(t(), atom()) :: boolean()
  def has_mode?(%__MODULE__{user_modes: modes}, mode) do
    MapSet.member?(modes, mode)
  end

  @spec set_mode(t(), atom()) :: t()
  def set_mode(%__MODULE__{user_modes: modes} = session, mode) do
    %{session | user_modes: MapSet.put(modes, mode)}
  end

  @spec unset_mode(t(), atom()) :: t()
  def unset_mode(%__MODULE__{user_modes: modes} = session, mode) do
    %{session | user_modes: MapSet.delete(modes, mode)}
  end

  @spec add_welcomed_channel(t(), String.t()) :: t()
  def add_welcomed_channel(%__MODULE__{welcomed_channels: channels} = session, channel_name) do
    %{session | welcomed_channels: MapSet.put(channels, channel_name)}
  end

  @spec welcomed_channel?(t(), String.t()) :: boolean()
  def welcomed_channel?(%__MODULE__{welcomed_channels: channels}, channel_name) do
    MapSet.member?(channels, channel_name)
  end
end
