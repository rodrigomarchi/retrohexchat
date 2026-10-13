defmodule RetroHexChat.VirtualSpace.CharacterCatalog do
  @moduledoc """
  What the Space's character creator offers: the bodies, the outfits each body
  can wear, the hairstyles, hats and face items, and how many colours each
  palette holds.

  The art behind it is built offline (`virtual.space/tools/build_creator.py`),
  which writes this catalog beside the web one it draws from, so the server
  knows exactly the pieces the client can compose — no more, no fewer. It is
  read at compile time: a build that adds a hat is a deploy, not a query.
  """

  @path Path.expand("../../../priv/virtual_space/character_catalog.json", __DIR__)
  @external_resource @path
  @catalog @path |> File.read!() |> JSON.decode!()

  @bases @catalog["bases"] |> Enum.map(&List.to_tuple(String.split(&1, "/"))) |> MapSet.new()

  @doc "The catalog's body ids, in the order the creator lists them."
  @spec bodies() :: [String.t()]
  def bodies, do: @catalog["bodies"]

  @doc "Outfit ids and how many dyeable colours each has."
  @spec outfits() :: %{String.t() => non_neg_integer()}
  def outfits, do: @catalog["outfits"]

  @doc "Whether the art has `outfit` drawn on `body`."
  @spec base?(String.t(), String.t()) :: boolean()
  def base?(body, outfit), do: MapSet.member?(@bases, {body, outfit})

  @doc "The outfits `body` can wear, in catalog order."
  @spec outfits_for(String.t()) :: [String.t()]
  def outfits_for(body) do
    for {b, o} <- Enum.map(@catalog["bases"], &List.to_tuple(String.split(&1, "/"))),
        b == body,
        do: o
  end

  @doc "Hairstyle ids."
  @spec hair() :: [String.t()]
  def hair, do: @catalog["hair"]

  @doc "Headwear ids and how many dyeable colours each has."
  @spec headwear() :: %{String.t() => non_neg_integer()}
  def headwear, do: @catalog["headwear"]

  @doc "Face item ids."
  @spec face() :: [String.t()]
  def face, do: @catalog["face"]

  @doc ~s{How many colours a palette ("skin", "hair" or "fabric") holds.}
  @spec palette_size(String.t()) :: pos_integer()
  def palette_size(name), do: Map.fetch!(@catalog["palettes"], name)

  @doc "The recipe a character starts from."
  @spec default() :: String.t()
  def default, do: @catalog["default"]

  @doc "Changes whenever the art does: portraits are cached under it."
  @spec version() :: String.t()
  def version, do: @catalog["portrait_version"]
end
