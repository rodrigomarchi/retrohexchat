defmodule RetroHexChat.Moderation.TimedRestrictionTest do
  use ExUnit.Case, async: true

  @moduletag :unit

  alias RetroHexChat.Admin.GlobalMute
  alias RetroHexChat.Channels.ChannelMute
  alias RetroHexChat.Jobs.ChannelMuteExpiryWorker
  alias RetroHexChat.Moderation.TimedRestriction

  defp channel_opts(overrides \\ []) do
    Keyword.merge(
      [
        schema: ChannelMute,
        worker: ChannelMuteExpiryWorker,
        queue: :maintenance,
        job_args_key: :mute_id,
        subject_attr: :target_nickname,
        subject_field: :normalized_target,
        scope_fields: [:channel_name]
      ],
      overrides
    )
  end

  describe "new!/1" do
    test "accepts a declaration whose columns all exist" do
      assert %TimedRestriction{schema: ChannelMute} = TimedRestriction.new!(channel_opts())
    end

    test "accepts a server-wide restriction with no scope" do
      assert %TimedRestriction{scope_fields: []} =
               TimedRestriction.new!(
                 channel_opts(
                   schema: GlobalMute,
                   subject_attr: :nickname,
                   subject_field: :normalized_nickname,
                   scope_fields: []
                 )
               )
    end

    test "refuses a subject column the schema does not have" do
      assert_raise ArgumentError, ~r/no field\(s\) \[:nickname\]/, fn ->
        TimedRestriction.new!(channel_opts(subject_attr: :nickname))
      end
    end

    test "refuses a scope column the schema does not have" do
      assert_raise ArgumentError, ~r/no field\(s\) \[:room\]/, fn ->
        TimedRestriction.new!(channel_opts(scope_fields: [:room]))
      end
    end

    test "refuses a schema without the columns the lifecycle writes" do
      assert_raise ArgumentError, ~r/revoked_at/, fn ->
        TimedRestriction.new!(
          channel_opts(
            schema: RetroHexChat.Chat.Message,
            subject_attr: :author_nickname,
            subject_field: :author_nickname,
            scope_fields: [:channel_name]
          )
        )
      end
    end

    test "refuses a declaration missing a required key" do
      assert_raise ArgumentError, fn ->
        TimedRestriction.new!(Keyword.delete(channel_opts(), :worker))
      end
    end
  end
end
