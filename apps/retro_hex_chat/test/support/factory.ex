defmodule RetroHexChat.Factory do
  @moduledoc """
  ExMachina factory for test data generation.
  """
  use ExMachina.Ecto, repo: RetroHexChat.Repo

  alias RetroHexChat.Chat.{Message, PrivateMessage}
  alias RetroHexChat.Services.{AccessListEntry, Ban, RegisteredChannel, RegisteredNick}

  def message_factory do
    %Message{
      channel_name: sequence(:channel_name, &"#channel-#{&1}"),
      author_nickname: sequence(:author_nickname, &"user#{&1}"),
      content: "Hello, world!",
      type: "message"
    }
  end

  def private_message_factory do
    %PrivateMessage{
      sender_nickname: sequence(:sender_nickname, &"sender#{&1}"),
      recipient_nickname: sequence(:recipient_nickname, &"recipient#{&1}"),
      content: "Hey there!",
      type: "message"
    }
  end

  def registered_nick_factory do
    %RegisteredNick{
      nickname: sequence(:nickname, &"nick#{&1}"),
      password_hash: Bcrypt.hash_pwd_salt("password123"),
      registered_at: DateTime.utc_now(),
      last_seen_at: DateTime.utc_now()
    }
  end

  def registered_channel_factory do
    %RegisteredChannel{
      name: sequence(:channel_name, &"#chan-#{&1}"),
      founder_nickname: sequence(:founder_nickname, &"founder#{&1}"),
      modes: "",
      registered_at: DateTime.utc_now()
    }
  end

  def access_list_entry_factory do
    %AccessListEntry{
      channel_name: sequence(:channel_name, &"#chan-#{&1}"),
      nickname: sequence(:nickname, &"user#{&1}"),
      level: "aop",
      added_by: "Admin"
    }
  end

  def ban_factory do
    %Ban{
      channel_name: sequence(:channel_name, &"#chan-#{&1}"),
      banned_nickname: sequence(:banned_nickname, &"troll#{&1}"),
      banned_by: "Admin",
      reason: "Spamming"
    }
  end
end
