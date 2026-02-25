defmodule RetroHexChatWeb.Components.BotFormDialog do
  @moduledoc """
  Sub-dialogs for bot management: New Bot and Add Command.
  """
  use Phoenix.Component

  alias RetroHexChatWeb.Icons

  # ── New Bot Dialog ──

  attr :visible, :boolean, default: false

  @spec new_bot_dialog(map()) :: Phoenix.LiveView.Rendered.t()
  def new_bot_dialog(assigns) do
    ~H"""
    <div
      :if={@visible}
      class="dialog-overlay bot-form-overlay"
      id="new-bot-dialog"
      data-testid="new-bot-dialog"
    >
      <div class="window bot-new-dialog">
        <div class="title-bar">
          <Icons.icon_dialog_bot_management class="title-bar-icon" />
          <div class="title-bar-text">New Bot</div>
          <div class="title-bar-controls">
            <button type="button" aria-label="Close" phx-click="close_new_bot_dialog"></button>
          </div>
        </div>
        <div class="window-body">
          <form phx-submit="create_bot" class="bot-form">
            <fieldset>
              <legend>Identity</legend>
              <div class="bot-form-field">
                <label for="bot-name">Bot Name:</label>
                <input
                  type="text"
                  id="bot-name"
                  name="name"
                  required
                  minlength="2"
                  maxlength="16"
                  pattern="[a-zA-Z0-9_-]+"
                  class="bot-form-input"
                  data-testid="new-bot-name"
                />
              </div>
              <div class="bot-form-field">
                <label for="bot-nick">Nickname:</label>
                <input
                  type="text"
                  id="bot-nick"
                  name="nickname"
                  minlength="2"
                  maxlength="16"
                  pattern="[a-zA-Z][a-zA-Z0-9_-]*"
                  class="bot-form-input"
                  placeholder="(same as name)"
                  data-testid="new-bot-nickname"
                />
              </div>
              <div class="bot-form-field">
                <label for="bot-desc">Description:</label>
                <input
                  type="text"
                  id="bot-desc"
                  name="description"
                  maxlength="200"
                  class="bot-form-input bot-form-input--wide"
                  data-testid="new-bot-description"
                />
              </div>
            </fieldset>

            <fieldset>
              <legend>Behavior</legend>
              <div class="bot-form-row">
                <div class="bot-form-field">
                  <label for="bot-prefix">Command Prefix:</label>
                  <input
                    type="text"
                    id="bot-prefix"
                    name="prefix"
                    value="!"
                    maxlength="3"
                    class="bot-form-input bot-form-input--short"
                    data-testid="new-bot-prefix"
                  />
                </div>
                <div class="bot-form-field">
                  <label for="bot-cooldown">Cooldown (ms):</label>
                  <input
                    type="number"
                    id="bot-cooldown"
                    name="cooldown"
                    value="2000"
                    min="500"
                    class="bot-form-input bot-form-input--short"
                    data-testid="new-bot-cooldown"
                  />
                </div>
              </div>
            </fieldset>

            <fieldset>
              <legend>Capabilities</legend>
              <div class="bot-form-caps">
                <label class="bot-form-cap">
                  <input type="checkbox" name="cap_mention" value="true" checked />
                  Respond to mentions
                </label>
                <label class="bot-form-cap">
                  <input type="checkbox" name="cap_greeter" value="true" checked /> Greet new users
                </label>
                <label class="bot-form-cap">
                  <input type="checkbox" name="cap_custom_commands" value="true" checked />
                  Custom commands
                </label>
                <label class="bot-form-cap">
                  <input type="checkbox" name="cap_help" value="true" checked /> Built-in !help
                </label>
                <hr class="bot-form-divider" />
                <label class="bot-form-cap">
                  <input type="checkbox" name="cap_dice" value="true" /> Dice/RNG
                </label>
                <label class="bot-form-cap">
                  <input type="checkbox" name="cap_moderation" value="true" /> Auto-Moderation
                </label>
                <label class="bot-form-cap">
                  <input type="checkbox" name="cap_trivia" value="true" /> Trivia/Quiz
                </label>
                <label class="bot-form-cap">
                  <input type="checkbox" name="cap_scheduler" value="true" /> Scheduler
                </label>
                <label class="bot-form-cap">
                  <input type="checkbox" name="cap_rss" value="true" /> RSS Reader
                </label>
                <hr class="bot-form-divider" />
                <label class="bot-form-cap bot-form-cap--coming-soon">
                  <input type="checkbox" disabled /> LLM Responses
                  <span class="coming-soon-badge">Coming soon</span>
                </label>
                <label class="bot-form-cap bot-form-cap--coming-soon">
                  <input type="checkbox" disabled /> Script Engine
                  <span class="coming-soon-badge">Coming soon</span>
                </label>
                <label class="bot-form-cap bot-form-cap--coming-soon">
                  <input type="checkbox" disabled /> Game AI
                  <span class="coming-soon-badge">Coming soon</span>
                </label>
              </div>
            </fieldset>

            <div class="bot-form-actions">
              <button type="submit" class="btn-icon bot-form-btn" data-testid="create-bot-submit">
                <Icons.icon_btn_ok class="btn-icon__svg" /> Create
              </button>
              <button type="button" class="btn-icon bot-form-btn" phx-click="close_new_bot_dialog">
                <Icons.icon_btn_cancel class="btn-icon__svg" /> Cancel
              </button>
            </div>
          </form>
        </div>
      </div>
    </div>
    """
  end

  # ── Add Command Dialog ──

  attr :visible, :boolean, default: false
  attr :bot_name, :string, default: ""

  @spec add_command_dialog(map()) :: Phoenix.LiveView.Rendered.t()
  def add_command_dialog(assigns) do
    ~H"""
    <div
      :if={@visible}
      class="dialog-overlay bot-form-overlay"
      id="add-command-dialog"
      data-testid="add-command-dialog"
    >
      <div class="window bot-addcmd-dialog">
        <div class="title-bar">
          <Icons.icon_dialog_bot_management class="title-bar-icon" />
          <div class="title-bar-text">Add Command</div>
          <div class="title-bar-controls">
            <button type="button" aria-label="Close" phx-click="close_add_command_dialog"></button>
          </div>
        </div>
        <div class="window-body">
          <form phx-submit="bot_add_command" class="bot-form">
            <input type="hidden" name="bot_name" value={@bot_name} />
            <div class="bot-form-field">
              <label for="cmd-trigger">Trigger:</label>
              <input
                type="text"
                id="cmd-trigger"
                name="trigger"
                required
                pattern="[a-zA-Z0-9_-]+"
                class="bot-form-input"
                placeholder="e.g. rules"
                data-testid="cmd-trigger"
              />
              <small>(without prefix)</small>
            </div>
            <div class="bot-form-field">
              <label for="cmd-response">Response:</label>
              <textarea
                id="cmd-response"
                name="response"
                required
                rows="3"
                class="bot-form-input bot-form-input--wide"
                data-testid="cmd-response"
              ></textarea>
            </div>
            <div class="bot-form-field">
              <label for="cmd-desc">Description:</label>
              <input
                type="text"
                id="cmd-desc"
                name="description"
                class="bot-form-input bot-form-input--wide"
                placeholder="(shown in !help listing)"
                data-testid="cmd-description"
              />
            </div>
            <div class="bot-form-actions">
              <button type="submit" class="btn-icon bot-form-btn" data-testid="add-cmd-submit">
                <Icons.icon_btn_ok class="btn-icon__svg" /> Add
              </button>
              <button type="button" class="btn-icon bot-form-btn" phx-click="close_add_command_dialog">
                <Icons.icon_btn_cancel class="btn-icon__svg" /> Cancel
              </button>
            </div>
          </form>
        </div>
      </div>
    </div>
    """
  end
end
