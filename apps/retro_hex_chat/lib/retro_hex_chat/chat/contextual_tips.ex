defmodule RetroHexChat.Chat.ContextualTips do
  @moduledoc """
  Contextual tip state for registered users.

  The browser owns transient toast rendering and queueing. This module owns the
  durable read model: which tips were seen and whether tips are globally
  suppressed for the account.
  """

  alias RetroHexChat.Chat.Schemas.ContextualTipSetting
  alias RetroHexChat.Repo

  @type t :: %{
          seen_tips: [String.t()],
          suppressed: boolean()
        }

  @known_tip_ids ~w(first_message first_join first_pm first_highlight idle_help)

  @spec new() :: t()
  def new, do: %{seen_tips: [], suppressed: false}

  @spec known_tip_ids() :: [String.t()]
  def known_tip_ids, do: @known_tip_ids

  @spec seen_tips(map()) :: [String.t()]
  def seen_tips(%{seen_tips: seen_tips}), do: normalize_seen_tips(seen_tips)
  def seen_tips(_tips), do: []

  @spec seen?(map(), String.t()) :: boolean()
  def seen?(tips, tip_id), do: tip_id in seen_tips(tips)

  @spec mark_seen(map(), term()) :: t()
  def mark_seen(tips, tip_id) when is_binary(tip_id) and tip_id in @known_tip_ids do
    normalized = normalize(tips)
    %{normalized | seen_tips: append_unique(normalized.seen_tips, tip_id)}
  end

  def mark_seen(tips, _tip_id), do: normalize(tips)

  @spec mark_preempted(map(), term()) :: t()
  def mark_preempted(tips, "help_used"), do: mark_seen(tips, "idle_help")
  def mark_preempted(tips, _action_id), do: normalize(tips)

  @spec suppressed?(map()) :: boolean()
  def suppressed?(%{suppressed: true}), do: true
  def suppressed?(_tips), do: false

  @spec set_suppressed(map(), term()) :: map()
  def set_suppressed(tips, suppressed) when is_boolean(suppressed) do
    tips
    |> normalize()
    |> Map.put(:suppressed, suppressed)
  end

  def set_suppressed(tips, _suppressed), do: normalize(tips)

  @spec to_client_state(map()) :: map()
  def to_client_state(tips) do
    normalized = normalize(tips)

    %{
      seen_tips: normalized.seen_tips,
      suppressed: normalized.suppressed
    }
  end

  @spec save(String.t(), map()) :: :ok | {:error, term()}
  def save(owner, tips) do
    normalized = normalize(tips)

    attrs = %{
      owner_nickname: owner,
      seen_tips: normalized.seen_tips,
      suppressed: normalized.suppressed
    }

    case Repo.get(ContextualTipSetting, owner) do
      nil ->
        %ContextualTipSetting{}
        |> ContextualTipSetting.changeset(attrs)
        |> Repo.insert()

      existing ->
        existing
        |> ContextualTipSetting.changeset(attrs)
        |> Repo.update()
    end
    |> case do
      {:ok, _} -> :ok
      {:error, reason} -> {:error, reason}
    end
  end

  @spec load(String.t()) :: {:ok, t()} | {:error, :not_found}
  def load(owner) do
    case Repo.get(ContextualTipSetting, owner) do
      nil ->
        {:error, :not_found}

      db_entry ->
        {:ok,
         normalize(%{
           seen_tips: db_entry.seen_tips,
           suppressed: db_entry.suppressed
         })}
    end
  end

  defp normalize(tips) when is_map(tips) do
    %{
      seen_tips: seen_tips(tips),
      suppressed: suppressed?(tips)
    }
  end

  defp normalize(_tips), do: new()

  defp normalize_seen_tips(seen_tips) when is_list(seen_tips) do
    seen_tips
    |> Enum.filter(&(&1 in @known_tip_ids))
    |> dedupe()
  end

  defp normalize_seen_tips(_seen_tips), do: []

  defp append_unique(seen_tips, tip_id) do
    if tip_id in seen_tips, do: seen_tips, else: seen_tips ++ [tip_id]
  end

  defp dedupe(values) do
    values
    |> Enum.reduce({MapSet.new(), []}, fn value, {seen, acc} ->
      if MapSet.member?(seen, value) do
        {seen, acc}
      else
        {MapSet.put(seen, value), [value | acc]}
      end
    end)
    |> elem(1)
    |> Enum.reverse()
  end
end
