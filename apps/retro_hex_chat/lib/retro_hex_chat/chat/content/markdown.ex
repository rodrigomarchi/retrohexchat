defmodule RetroHexChat.Chat.Content.Markdown do
  @moduledoc false

  @type safe_html :: {:safe, String.t()}

  @markdown_extension_options [
    autolink: true,
    strikethrough: true
  ]

  @link_rel "noopener noreferrer"

  @spec render_html(String.t(), keyword()) :: safe_html()
  def render_html(content, _opts) do
    html =
      content
      |> MDEx.to_html!(
        extension: @markdown_extension_options,
        sanitize: markdown_sanitize_options()
      )
      |> harden_links()
      |> harden_images()

    {:safe, html}
  end

  @spec plain_text(String.t()) :: String.t()
  def plain_text(content) do
    content
    |> MDEx.to_delta!(extension: @markdown_extension_options)
    |> Enum.flat_map(&delta_insert/1)
    |> Enum.join()
    |> String.trim_trailing("\n")
  end

  @spec extract_urls(String.t()) :: [String.t()]
  def extract_urls(content) do
    {:safe, html} = render_html(content, [])

    ~r/<a\b[^>]*\shref="([^"]+)"[^>]*>/i
    |> Regex.scan(html, capture: :all_but_first)
    |> List.flatten()
    |> Enum.map(&decode_html_attr/1)
    |> Enum.filter(&String.match?(&1, ~r/^https?:\/\//i))
  end

  @spec markdown_sanitize_options() :: keyword()
  defp markdown_sanitize_options do
    MDEx.Document.default_sanitize_options()
    |> Keyword.put(:link_rel, @link_rel)
  end

  @spec delta_insert(map()) :: [String.t()]
  defp delta_insert(%{"insert" => insert}) when is_binary(insert), do: [insert]
  defp delta_insert(_delta), do: []

  @spec harden_links(String.t()) :: String.t()
  defp harden_links(html) do
    Regex.replace(~r/<a\b([^>]*)>/i, html, fn _match, attrs ->
      attrs =
        attrs
        |> ensure_attr("target", "_blank")
        |> ensure_rel(@link_rel)
        |> ensure_class("chat-link")
        |> ensure_data_url()

      "<a#{attrs}>"
    end)
  end

  @spec harden_images(String.t()) :: String.t()
  defp harden_images(html) do
    Regex.replace(~r/<img\b([^>]*)>/i, html, fn _match, attrs ->
      if safe_image_src?(attrs) do
        attrs =
          attrs
          |> ensure_attr("loading", "lazy")
          |> ensure_attr("decoding", "async")
          |> ensure_attr("referrerpolicy", "no-referrer")
          |> ensure_class("chat-markdown-image")

        image_shell("<img#{attrs}>")
      else
        attrs
        |> attr_value("alt")
        |> decode_html_attr()
        |> html_escape()
      end
    end)
  end

  @spec image_shell(String.t()) :: String.t()
  defp image_shell(img_html) do
    ~s(<span class="chat-markdown-image-shell" data-image-state="loading">#{img_html}</span>)
  end

  @spec safe_image_src?(String.t()) :: boolean()
  defp safe_image_src?(attrs) do
    case attr_value(attrs, "src") do
      src when is_binary(src) -> String.match?(decode_html_attr(src), ~r/^https?:\/\//i)
      nil -> false
    end
  end

  @spec attr_value(String.t(), String.t()) :: String.t() | nil
  defp attr_value(attrs, name) do
    case Regex.run(~r/\s#{Regex.escape(name)}="([^"]*)"/i, attrs) do
      [_full_match, value] -> value
      nil -> nil
    end
  end

  @spec ensure_data_url(String.t()) :: String.t()
  defp ensure_data_url(attrs) do
    case attr_value(attrs, "href") do
      href when is_binary(href) -> ensure_attr(attrs, "data-url", href)
      nil -> attrs
    end
  end

  @spec ensure_attr(String.t(), String.t(), String.t()) :: String.t()
  defp ensure_attr(attrs, name, value) do
    if Regex.match?(~r/\s#{Regex.escape(name)}=/i, attrs) do
      attrs
    else
      attrs <> ~s( #{name}="#{value}")
    end
  end

  @spec ensure_rel(String.t(), String.t()) :: String.t()
  defp ensure_rel(attrs, required_rel) do
    case Regex.run(~r/\srel="([^"]*)"/i, attrs) do
      [full_match, existing_rel] ->
        rel =
          existing_rel
          |> String.split()
          |> Kernel.++(String.split(required_rel))
          |> Enum.uniq()
          |> Enum.join(" ")

        String.replace(attrs, full_match, ~s( rel="#{rel}"))

      nil ->
        attrs <> ~s( rel="#{required_rel}")
    end
  end

  @spec ensure_class(String.t(), String.t()) :: String.t()
  defp ensure_class(attrs, class_name) do
    case Regex.run(~r/\sclass="([^"]*)"/i, attrs) do
      [full_match, existing_class] ->
        classes =
          existing_class
          |> String.split()
          |> Kernel.++([class_name])
          |> Enum.uniq()
          |> Enum.join(" ")

        String.replace(attrs, full_match, ~s( class="#{classes}"))

      nil ->
        attrs <> ~s( class="#{class_name}")
    end
  end

  @spec decode_html_attr(String.t() | nil) :: String.t()
  defp decode_html_attr(nil), do: ""

  defp decode_html_attr(value) do
    value
    |> String.replace("&amp;", "&")
    |> String.replace("&quot;", "\"")
    |> String.replace("&#39;", "'")
    |> String.replace("&lt;", "<")
    |> String.replace("&gt;", ">")
  end

  @spec html_escape(String.t()) :: String.t()
  defp html_escape(value) do
    value
    |> String.replace("&", "&amp;")
    |> String.replace("<", "&lt;")
    |> String.replace(">", "&gt;")
    |> String.replace("\"", "&quot;")
    |> String.replace("'", "&#39;")
  end
end
