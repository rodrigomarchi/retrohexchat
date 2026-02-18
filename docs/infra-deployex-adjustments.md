# DeployEx Infrastructure Adjustments

These changes need to be made in the `retro_hex_chat_infra` repository to align the infrastructure with the application's deploy pipeline.

---

## 1. Environment Variables — Remove App Prefix

The DeployEx runtime config expects env vars **without** the `RETRO_HEX_CHAT_` prefix. The Ansible `vars.yml` currently sets prefixed variables.

**Change in `vars.yml` (or equivalent):**

```yaml
# BEFORE
RETRO_HEX_CHAT_PHX_HOST: "sun.retrohexchat.app"
RETRO_HEX_CHAT_PHX_SERVER: "true"
RETRO_HEX_CHAT_DATABASE_URL: "..."
RETRO_HEX_CHAT_SECRET_KEY_BASE: "..."

# AFTER
PHX_HOST: "sun.retrohexchat.app"
PHX_SERVER: "true"
DATABASE_URL: "..."
SECRET_KEY_BASE: "..."
```

**Why:** Phoenix `runtime.exs` reads `System.get_env("PHX_HOST")`, not `System.get_env("RETRO_HEX_CHAT_PHX_HOST")`. DeployEx passes env vars to the release as-is.

**Validation:** After deploy, check `bin/retro_hex_chat remote` and run `System.get_env("PHX_HOST")` — should return the expected hostname.

---

## 2. Fix Versions Directory — Align `account_name` with Filesystem

The DeployEx config uses `account_name: "local"` which means it looks for versions at:
```
~/releases/versions/retro_hex_chat/local/current.json
```

But Ansible may create the directory as `prod` instead of `local`. These must match.

**Option A (preferred):** Ensure Ansible creates the directory as `local`:
```yaml
versions_path: "/home/rodrigo/releases/versions/retro_hex_chat/local"
```

**Option B:** Change DeployEx config to use `account_name: "prod"` and update `deploy.sh` accordingly.

**Validation:** `ls ~/releases/versions/retro_hex_chat/local/` should exist and be writable.

---

## 3. Add Node.js via asdf

The build process needs `npm` to install 98.css and build assets. Add Node.js to the asdf setup in the `erlang_elixir` role (or a new `nodejs` role).

**Add to asdf plugins:**
```bash
asdf plugin add nodejs
asdf install nodejs 22.14.0  # or latest LTS
asdf global nodejs 22.14.0
```

**Or in Ansible:**
```yaml
asdf_plugins:
  - name: erlang
    version: "27.3.4.6"
  - name: elixir
    version: "1.18.4-otp-27"
  - name: nodejs
    version: "22.14.0"
```

**Validation:** `ssh -p 2222 rodrigo@<server-ip> "source ~/.asdf/asdf.sh && node --version && npm --version"`

---

## 4. Deploy Key for GitHub

The server needs SSH access to the GitHub repository to `git clone` and `git pull`.

**Steps:**
1. Generate a deploy key on each server:
   ```bash
   ssh-keygen -t ed25519 -f ~/.ssh/github_deploy -N ""
   ```
2. Add the public key as a deploy key in the GitHub repo settings:
   - Go to `Settings > Deploy keys > Add deploy key`
   - Title: `Sun (production)` or `Moon (staging)`
   - Paste the contents of `~/.ssh/github_deploy.pub`
   - Read-only access is sufficient
3. Configure SSH to use this key for GitHub:
   ```bash
   cat >> ~/.ssh/config <<EOF
   Host github.com
     IdentityFile ~/.ssh/github_deploy
     IdentitiesOnly yes
   EOF
   ```
4. Clone the repository:
   ```bash
   git clone git@github.com:rodrigomarchi/retro_hex_chat.git ~/retro_hex_chat
   ```

**Validation:** `ssh -p 2222 rodrigo@<server-ip> "cd ~/retro_hex_chat && git fetch --all"`

---

## 5. GitHub Actions Secrets

Add these secrets in the GitHub repo (`Settings > Secrets and variables > Actions`):

| Secret | Value |
|--------|-------|
| `SUN_IP` | `YOUR_PRODUCTION_SERVER_IP` |
| `MOON_IP` | `YOUR_STAGING_SERVER_IP` |
| `DEPLOY_USER` | `rodrigo` |
| `DEPLOY_SSH_KEY` | Private SSH key for deploy (ed25519) |
| `SSH_PORT` | `2222` |

The deploy key should have SSH access to both servers.

---

## Validation Checklist

- [ ] Env vars reach the app without prefix (`PHX_HOST`, `DATABASE_URL`, etc.)
- [ ] `~/releases/versions/retro_hex_chat/local/` directory exists
- [ ] `node --version` and `npm --version` work via asdf
- [ ] `git fetch` works from `~/retro_hex_chat` on both servers
- [ ] `make deploy-moon REF=main` completes successfully
- [ ] DeployEx dashboard shows the new version
- [ ] App is accessible at the expected URL
