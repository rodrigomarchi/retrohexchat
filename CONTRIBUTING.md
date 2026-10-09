# Contributing to Retro Hex Chat

Thanks for considering a contribution to Retro Hex Chat! This guide will help you get started.

## Reporting bugs

1. Check whether the bug has already been reported in [Issues](https://github.com/rodrigomarchi/retrohexchat/issues)
2. If you can't find it, open a new Issue with:
   - A clear description of the problem
   - Steps to reproduce
   - Expected vs. observed behaviour
   - Elixir/OTP version and operating system

## Suggesting features

Open an Issue with the `enhancement` label describing:
- The problem the feature solves
- How you picture the solution
- Usage examples

## Local development

### Setup

```bash
git clone https://github.com/rodrigomarchi/retrohexchat.git
cd retrohexchat
make setup
make server  # http://localhost:4000
```

### Requirements

- Elixir 1.17+
- OTP 27+
- PostgreSQL 16+
- Node.js 20+

### PR workflow

1. Fork the repository
2. Update your base before creating the branch:

```bash
git fetch origin
git checkout main
git pull --ff-only origin main
git status --short --branch
```

3. Create a branch from `main`: `git checkout -b my-feature`
4. Make your changes
5. Run the tests and linters:

```bash
mix compile --warnings-as-errors
mix format --check-formatted
mix credo --strict
mix test --include e2e
mix dialyzer
make lint.js
make lint.css
npm test --prefix apps/retro_hex_chat_web/assets
```

6. Commit with a descriptive message
7. Open a Pull Request

### Pushing directly to `main`

Before any commit or direct push to `main`, check the remote and pull with
fast-forward:

```bash
git fetch origin
git status --short --branch
git pull --ff-only origin main
```

If you have uncommitted local changes, use `git pull --ff-only --autostash origin main`.
Only run `git push origin main` after confirming your local branch is up to date.

### Code style

- **Elixir**: `mix format` (enforced). Every public function needs a `@spec`.
- **JavaScript**: ESLint + Prettier (`make lint.js`). Auto-fix with `make lint.js.fix`.
- **CSS**: No inline styles in templates (`make lint.css`).
- **Tests**: TDD. Tags: `@tag :unit`, `@tag :integration`, `@tag :liveview`, `@tag :e2e`.

### Project structure

```
apps/
├── retro_hex_chat/           # Domain (pure Elixir)
└── retro_hex_chat_web/       # Web (Phoenix + LiveView)
```

The domain (`retro_hex_chat`) has no web layer — no LiveView, controller, route or endpoint — though it uses Phoenix as a library (PubSub, Token, Presence). The web layer (`retro_hex_chat_web`) is thin and delegates to the domain contexts.

## Code of conduct

Be respectful. Constructive contributions are welcome regardless of experience, gender, orientation, ethnicity, or any other personal characteristic.
