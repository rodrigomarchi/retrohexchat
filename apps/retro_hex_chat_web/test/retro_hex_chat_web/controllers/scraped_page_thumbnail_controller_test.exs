defmodule RetroHexChatWeb.ScrapedPageThumbnailControllerTest do
  @moduledoc """
  Public thumbnail responses for scraped page cards.
  """

  use RetroHexChatWeb.ConnCase, async: true

  alias RetroHexChat.Scraper.Store

  @moduletag :integration

  test "redirects ready thumbnails to Garage", %{conn: conn} do
    {:ok, page} =
      Store.record_success("https://example.com/story", %{
        title: "Story",
        image_url: "https://cdn.example.com/story.jpg"
      })

    {:ok, page} =
      Store.record_image_thumbnail_success(page, %{
        source_url: "https://cdn.example.com/story.jpg",
        storage_bucket: "retrohexchat-uploads",
        storage_key: "scraper/images/story.jpg",
        content_type: "image/jpeg",
        byte_size: 42,
        width: 640,
        height: 360
      })

    conn = get(conn, ~p"/chat/scraped-pages/#{page.url_hash}/thumbnail")

    assert redirected_to(conn) ==
             "http://storage.test/retrohexchat-uploads/scraper/images/story.jpg"
  end

  test "returns 404 when thumbnail generation has not been attempted", %{conn: conn} do
    {:ok, page} =
      Store.record_success("https://example.com/story", %{
        title: "Story",
        image_url: "https://cdn.example.com/story.jpg"
      })

    conn = get(conn, ~p"/chat/scraped-pages/#{page.url_hash}/thumbnail")

    assert response(conn, 404) == ""
  end

  test "serves a lightweight placeholder while the thumbnail is pending", %{conn: conn} do
    {:ok, page} =
      Store.record_success("https://example.com/story", %{
        title: "Story",
        image_url: "https://cdn.example.com/story.jpg"
      })

    {:ok, page} =
      Store.record_image_thumbnail_pending(page, "https://cdn.example.com/story.jpg")

    conn = get(conn, ~p"/chat/scraped-pages/#{page.url_hash}/thumbnail")
    body = response(conn, 200)

    assert [content_type] = get_resp_header(conn, "content-type")
    assert content_type =~ "image/svg+xml"
    assert body =~ "Image unavailable"
    assert body =~ "Thumbnail is being prepared"
  end

  test "serves a failure placeholder when thumbnail generation failed", %{conn: conn} do
    {:ok, page} =
      Store.record_success("https://example.com/story", %{
        title: "Story",
        image_url: "https://cdn.example.com/story.jpg"
      })

    {:ok, page} =
      Store.record_image_thumbnail_failure(
        page,
        "https://cdn.example.com/story.jpg",
        :unsupported_image_type,
        status: "failed"
      )

    conn = get(conn, ~p"/chat/scraped-pages/#{page.url_hash}/thumbnail")
    body = response(conn, 200)

    assert [content_type] = get_resp_header(conn, "content-type")
    assert content_type =~ "image/svg+xml"
    assert body =~ "Image unavailable"
    assert body =~ "Thumbnail could not be loaded"
  end
end
