defmodule RetroHexChatWeb.Router do
  use RetroHexChatWeb, :router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {RetroHexChatWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/", RetroHexChatWeb do
    pipe_through :browser

    live "/", ConnectLive
    live "/chat", ChatLive
    live "/channels", ChannelListLive
  end

  # Enable LiveDashboard in development
  if Application.compile_env(:retro_hex_chat_web, :dev_routes) do
    import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through :browser

      live_dashboard "/dashboard", metrics: RetroHexChatWeb.Telemetry
    end
  end
end
