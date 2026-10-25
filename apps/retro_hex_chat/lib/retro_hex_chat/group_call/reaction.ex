defmodule RetroHexChat.GroupCall.Reaction do
  @moduledoc """
  The reactions a group-call participant can send — heart, thumbs up, clap,
  laugh, wow — and what the room is told of one.
  """

  alias RetroHexChat.GroupCall.Schema.Participant

  @allowed_reactions ~w(heart thumbs_up clap laugh wow)

  @doc "Only the participant's own registered nick may react as them."
  @spec authorize(map(), Participant.t()) :: :ok | {:error, :not_allowed}
  def authorize(%{user_id: user_id}, %{registered_nick_id: user_id}), do: :ok

  def authorize(_actor, _participant), do: {:error, :not_allowed}

  @doc "The reaction, trimmed, when it is one of the allowed ones."
  @spec normalize(term()) :: {:ok, String.t()} | {:error, :invalid_reaction}
  def normalize(reaction) when is_binary(reaction) do
    reaction = String.trim(reaction)

    if reaction in @allowed_reactions do
      {:ok, reaction}
    else
      {:error, :invalid_reaction}
    end
  end

  def normalize(_reaction), do: {:error, :invalid_reaction}

  @doc "What the room is told of a reaction: who, which, its emoji and when."
  @spec payload(Participant.t(), String.t()) :: map()
  def payload(participant, reaction) do
    %{
      id: reaction_id(participant.id),
      participant_id: participant.id,
      nickname: participant.nickname,
      reaction: reaction,
      emoji: reaction_emoji(reaction),
      occurred_at_ms: System.os_time(:millisecond)
    }
  end

  defp reaction_id(participant_id) do
    unique = System.unique_integer([:positive])
    "#{participant_id}-#{System.os_time(:millisecond)}-#{unique}"
  end

  defp reaction_emoji("heart"), do: "❤️"

  defp reaction_emoji("thumbs_up"), do: "👍"

  defp reaction_emoji("clap"), do: "👏"

  defp reaction_emoji("laugh"), do: "😄"

  defp reaction_emoji("wow"), do: "✨"
end
