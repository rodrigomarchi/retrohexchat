defmodule RetroHexChat.Chat.MessageRulesTest do
  @moduledoc """
  The rules both message tables obey, asserted once.

  Each schema's own test still covers what it declares — its addressing columns
  and the types it may carry. What is asserted here is what neither of them gets
  to decide alone, driven through both so a rule that stopped holding for one
  fails here rather than in whichever conversation nobody tested.
  """
  use ExUnit.Case, async: true

  @moduletag :unit

  alias Ecto.Changeset
  alias RetroHexChat.Chat.{Message, PrivateMessage}

  defp channel_attrs(extra \\ %{}) do
    Map.merge(%{channel_name: "#lobby", author_nickname: "Ada", content: "hello"}, extra)
  end

  defp private_attrs(extra \\ %{}) do
    Map.merge(%{sender_nickname: "Ada", recipient_nickname: "Mario", content: "hello"}, extra)
  end

  # Each case is stated once and driven through both schemas, which is the point:
  # a rule that holds for a room and not for a conversation is the defect.
  defp both(extra \\ %{}) do
    [
      {"channel", Message.changeset(%Message{}, channel_attrs(extra))},
      {"private", PrivateMessage.changeset(%PrivateMessage{}, private_attrs(extra))}
    ]
  end

  describe "content" do
    test "a message with content is valid in either conversation" do
      for {kind, changeset} <- both() do
        assert changeset.valid?, "#{kind} rejected a valid message"
      end
    end

    test "blank content is refused unless the writer allowed it" do
      for {kind, changeset} <- both(%{content: ""}) do
        refute changeset.valid?, "#{kind} accepted blank content"
      end
    end

    test "blank content is accepted when the writer allowed it" do
      for {kind, changeset} <- both(%{content: "", allow_blank_content: true}) do
        assert changeset.valid?, "#{kind} refused deliberately blank content"
      end
    end

    test "allowing blank content still does not allow omitting it" do
      for {kind, changeset} <- both(%{content: nil, allow_blank_content: true}) do
        refute changeset.valid?, "#{kind} accepted a message with no content field"
      end
    end
  end

  describe "content format" do
    test "an unsupported format is refused" do
      for {kind, changeset} <- both(%{content_format: "html"}) do
        refute changeset.valid?, "#{kind} accepted an unsupported format"
      end
    end

    test "the default is irc" do
      for {_kind, changeset} <- both() do
        assert Changeset.get_field(changeset, :content_format) == "irc"
      end
    end

    test "each supported format is accepted" do
      for format <- ~w(irc markdown plain),
          {kind, changeset} <- both(%{content_format: format}) do
        assert changeset.valid?, "#{kind} refused the #{format} format"
      end
    end
  end

  describe "plain_content" do
    test "is derived from the content rather than taken from the caller" do
      for {kind, changeset} <-
            both(%{
              content: "**bold**",
              content_format: "markdown",
              plain_content: "smuggled"
            }) do
        assert Changeset.get_field(changeset, :plain_content) == "bold",
               "#{kind} trusted a caller-supplied plain_content"
      end
    end

    test "is derived on an edit too" do
      edited =
        Message.edit_changeset(%Message{}, %{
          content: "**bold**",
          content_format: "markdown",
          edited_at: DateTime.utc_now()
        })

      pm_edited =
        PrivateMessage.edit_changeset(%PrivateMessage{}, %{
          content: "**bold**",
          content_format: "markdown",
          edited_at: DateTime.utc_now()
        })

      assert Changeset.get_field(edited, :plain_content) == "bold"
      assert Changeset.get_field(pm_edited, :plain_content) == "bold"
    end
  end

  describe "replies" do
    test "a reply must name what it quotes" do
      quoting = %{reply_to_id: 7}

      refute Message.reply_changeset(%Message{}, channel_attrs(quoting)).valid?
      refute PrivateMessage.reply_changeset(%PrivateMessage{}, private_attrs(quoting)).valid?
    end

    test "a reply naming what it quotes is valid" do
      quoting = %{reply_to_id: 7, reply_to_author: "Mario", reply_to_preview: "earlier"}

      assert Message.reply_changeset(%Message{}, channel_attrs(quoting)).valid?
      assert PrivateMessage.reply_changeset(%PrivateMessage{}, private_attrs(quoting)).valid?
    end

    test "a message quoting nothing needs no quote fields" do
      assert Message.reply_changeset(%Message{}, channel_attrs()).valid?
      assert PrivateMessage.reply_changeset(%PrivateMessage{}, private_attrs()).valid?
    end

    test "a plain write cannot smuggle a quote in" do
      quoting = %{reply_to_id: 7, reply_to_author: "Mario", reply_to_preview: "earlier"}

      for {kind, changeset} <- both(quoting) do
        assert Changeset.get_change(changeset, :reply_to_id) == nil,
               "#{kind} cast a reply field outside reply_changeset/2"
      end
    end
  end

  describe "deletion" do
    test "stamps a moment rather than requiring anything else" do
      at = DateTime.utc_now()

      assert Message.delete_changeset(%Message{}, %{deleted_at: at}).valid?
      assert PrivateMessage.delete_changeset(%PrivateMessage{}, %{deleted_at: at}).valid?
    end

    test "refuses to delete without stating when" do
      refute Message.delete_changeset(%Message{}, %{}).valid?
      refute PrivateMessage.delete_changeset(%PrivateMessage{}, %{}).valid?
    end
  end
end
