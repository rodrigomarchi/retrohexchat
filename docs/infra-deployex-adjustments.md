# Ajustes de Infra para Deploy Pipeline

> Prompt para agente de AI executar no repo `/Users/rodrigo/src/retro_hex_chat_infra`

## Contexto

O RetroHexChat tem um pipeline de deploy via DeployEx. Os servidores (Sun=produção, Moon=staging) já têm:
- Erlang 27, Elixir 1.18.4, Node.js 22.14 via asdf
- DeployEx rodando (systemd, `release_adapter: "local"`)
- Diretórios `~/releases/dist/retro_hex_chat/` e `~/releases/versions/retro_hex_chat/local/`
- Env vars corretas no `deployex.yaml` (PHX_HOST, TURN_RELAY_IP, etc.)
- Secrets no `/opt/deployex/.deployex-secrets` (DATABASE_URL, SECRET_KEY_BASE, etc.)

**O que falta**: o repo da app **não está clonado** nos servidores (`~/retro_hex_chat` não existe). A role `github_deploy_key` gera a chave SSH mas o acesso ao GitHub falha com `Permission denied` — a public key precisa ser adicionada como deploy key no GitHub.

## Tarefa 1: Registrar deploy keys no GitHub

A role `github_deploy_key` já gera as chaves em `/home/rodrigo/.ssh/github_deploy` nos servidores. As public keys precisam ser adicionadas manualmente no GitHub.

**Ação:**
1. Conectar em cada servidor e mostrar a public key:
   ```bash
   # Moon
   ssh -p 2222 rodrigo@YOUR_STAGING_SERVER_IP "cat /home/rodrigo/.ssh/github_deploy.pub"
   # Sun
   ssh -p 2222 rodrigo@YOUR_PRODUCTION_SERVER_IP "cat /home/rodrigo/.ssh/github_deploy.pub"
   ```
2. Instruir o usuário a adicionar cada key no GitHub:
   - Repo `rodrigomarchi/retro_hex_chat` → Settings → Deploy keys → Add deploy key
   - Títulos: `Moon (staging)` e `Sun (production)`
   - Read-only access é suficiente

**Validação:**
```bash
ssh -p 2222 rodrigo@YOUR_STAGING_SERVER_IP "ssh -T git@github.com 2>&1"
# Esperado: "Hi rodrigomarchi/retro_hex_chat! You've been granted access..."
```

## Tarefa 2: Criar role `app_clone` para clonar o repo da app

**Nova role**: `roles/app_clone/tasks/main.yml`

A role deve:
1. Clonar `git@github.com:rodrigomarchi/retro_hex_chat.git` em `/home/{{ deploy_user }}/retro_hex_chat`
2. Usar `ansible.builtin.git` (mesmo pattern da role `deployex` linhas 77-85)
3. Ser idempotente (se o repo já existe, só faz fetch)
4. Rodar como `become_user: "{{ deploy_user }}"`

**Referência** — pattern existente no repo:
```yaml
# roles/deployex/tasks/main.yml (linhas 77-85)
- name: Clone DeployEx repository
  ansible.builtin.git:
    repo: "{{ deployex_git_repo }}"
    dest: "{{ deployex_build_dir }}"
    version: "{{ deployex_git_ref }}"
    force: true
  become: true
  become_user: "{{ deploy_user }}"
```

**Variáveis a adicionar** em `inventory/group_vars/all/vars.yml`:
```yaml
app_git_repo: "git@github.com:rodrigomarchi/retro_hex_chat.git"
app_clone_dest: "/home/{{ deploy_user }}/retro_hex_chat"
app_git_ref: "main"
```

## Tarefa 3: Inserir role no playbook

Em `playbooks/site.yml`, adicionar `app_clone` **depois** de `github_deploy_key` e **antes** de `postgresql`:

```yaml
    - role: github_deploy_key      # posição 7 (já existe)
    - role: app_clone              # posição 8 (NOVA)
    - role: postgresql             # posição 9 (já existe, era 8)
```

## Tarefa 4: Executar e validar

```bash
make lint                    # Validar YAML/Ansible
make dry-run-moon            # Simular no staging
make provision-moon          # Aplicar no staging
```

**Validação pós-provision:**
```bash
ssh -p 2222 rodrigo@YOUR_STAGING_SERVER_IP "cd ~/retro_hex_chat && git log --oneline -1"
```

Depois repetir para Sun:
```bash
make provision-sun
ssh -p 2222 rodrigo@YOUR_PRODUCTION_SERVER_IP "cd ~/retro_hex_chat && git log --oneline -1"
```
