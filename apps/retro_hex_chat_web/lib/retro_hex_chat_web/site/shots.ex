defmodule RetroHexChatWeb.Site.Shots do
  @moduledoc """
  The pictures a public page shows from a capture (`make spaces.shots`,
  `make tools.shots`): each at full size with its copy halved to the pixel for
  narrow screens, and a share card, with the sizes the capture wrote to its
  `manifest.json`.

  A page reads its manifest at compile time and hands it here, so a picture
  it needs and the capture did not write fails the build, not a reader.
  """

  alias RetroHexChatWeb.Endpoint
  alias RetroHexChatWeb.SEO

  @typedoc "A picture as `UI.Landing.Screenshot` takes it."
  @type shot :: %{
          src: String.t(),
          width: pos_integer(),
          height: pos_integer(),
          srcset: String.t()
        }

  @doc """
  The pictures `names`, from the static folder `dir` (`"/images/spaces"`),
  sized by `manifest`.
  """
  @spec pictures(map(), String.t(), [String.t()]) :: %{String.t() => shot()}
  def pictures(manifest, dir, names) do
    Map.new(names, fn name ->
      full = Endpoint.static_path("#{dir}/#{name}.webp")
      half = Endpoint.static_path("#{dir}/#{name}-half.webp")
      %{"width" => width, "height" => height} = manifest[name]

      {name,
       %{
         src: full,
         width: width,
         height: height,
         srcset: "#{half} #{div(width, 2)}w, #{full} #{width}w"
       }}
    end)
  end

  @doc "The share card `og/<name>.jpg` in `dir`, described by `alt`, for a page's `og_image`."
  @spec card(map(), String.t(), String.t(), String.t()) :: map()
  def card(manifest, dir, name, alt) do
    %{
      url: card_url(dir, name),
      width: manifest["og/#{name}"]["width"],
      height: manifest["og/#{name}"]["height"],
      type: "image/jpeg",
      alt: alt
    }
  end

  @doc "The address of the share card `og/<name>.jpg` in `dir`."
  @spec card_url(String.t(), String.t()) :: String.t()
  def card_url(dir, name), do: SEO.site_url(Endpoint.static_path("#{dir}/og/#{name}.jpg"))
end
