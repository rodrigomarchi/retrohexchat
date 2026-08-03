defmodule RetroHexChatWeb.ChatLive.TabOrder do
  @moduledoc """
  Pure helpers for the user-controlled conversation tab order.

  The session still owns membership (`session.channels`) and PM tab visibility
  (`open_pm_tabs`). This module only stores the user's visual ordering choices.
  """

  @type tab_type :: :channel | :pm
  @type key :: {tab_type(), String.t()}

  @spec touch([key()], tab_type() | String.t(), String.t()) :: [key()]
  def touch(order, type, label) do
    case normalize_key(type, label) do
      nil -> normalize_order(order)
      key -> [key | List.delete(normalize_order(order), key)]
    end
  end

  @spec drop([key()], tab_type() | String.t(), String.t()) :: [key()]
  def drop(order, type, label) do
    case normalize_key(type, label) do
      nil -> normalize_order(order)
      key -> List.delete(normalize_order(order), key)
    end
  end

  @spec rename_pm([key()], String.t(), String.t()) :: [key()]
  def rename_pm(order, old_nick, new_nick) when is_binary(old_nick) and is_binary(new_nick) do
    order
    |> normalize_order()
    |> Enum.map(fn
      {:pm, ^old_nick} -> {:pm, new_nick}
      key -> key
    end)
    |> Enum.uniq()
  end

  def rename_pm(order, _old_nick, _new_nick), do: normalize_order(order)

  @spec visible_order([String.t()], [String.t()], [key()]) :: [key()]
  def visible_order(channels, pm_tabs, order) do
    base = base_order(channels, pm_tabs)
    available = MapSet.new(base)

    ordered =
      order
      |> normalize_order()
      |> Enum.filter(&MapSet.member?(available, &1))
      |> Enum.uniq()

    ordered ++ (base -- ordered)
  end

  @spec serialize([key()]) :: [map()]
  def serialize(order) do
    order
    |> normalize_order()
    |> Enum.map(fn {type, label} -> %{type: Atom.to_string(type), label: label} end)
  end

  @spec deserialize(any()) :: [key()]
  def deserialize(order) when is_list(order) do
    order
    |> Enum.map(&normalize_order_key/1)
    |> Enum.reject(&is_nil/1)
    |> Enum.uniq()
  end

  def deserialize(_order), do: []

  defp base_order(channels, pm_tabs) do
    channel_keys = for channel <- channels || [], is_binary(channel), do: {:channel, channel}
    pm_keys = for pm <- pm_tabs || [], is_binary(pm), do: {:pm, pm}
    channel_keys ++ pm_keys
  end

  defp normalize_order(order) when is_list(order) do
    order
    |> Enum.map(&normalize_order_key/1)
    |> Enum.reject(&is_nil/1)
    |> Enum.uniq()
  end

  defp normalize_order(_order), do: []

  defp normalize_order_key({type, label}), do: normalize_key(type, label)
  defp normalize_order_key(%{type: type, label: label}), do: normalize_key(type, label)
  defp normalize_order_key(%{"type" => type, "label" => label}), do: normalize_key(type, label)
  defp normalize_order_key(_key), do: nil

  defp normalize_key(type, label) when is_binary(label) and label != "" do
    case normalize_type(type) do
      nil -> nil
      normalized_type -> {normalized_type, label}
    end
  end

  defp normalize_key(_type, _label), do: nil

  defp normalize_type(:channel), do: :channel
  defp normalize_type("channel"), do: :channel
  defp normalize_type(:pm), do: :pm
  defp normalize_type("pm"), do: :pm
  defp normalize_type(_type), do: nil
end
