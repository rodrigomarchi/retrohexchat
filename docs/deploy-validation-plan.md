# Plano de Validação — Deploy Pipeline RetroHexChat

## Estado Atual (verificado 2026-02-18)

| Item | Moon (staging) | Sun (produção) |
|------|:-:|:-:|
| SSH porta 2222 | OK | OK |
| Erlang 27 / Elixir 1.18.4 / Node 22.14 | OK | OK |
| DeployEx rodando (systemd) | OK | OK |
| `~/releases/dist/retro_hex_chat/` | OK (vazio) | OK (vazio) |
| `~/releases/versions/retro_hex_chat/local/` | OK (vazio) | OK (vazio) |
| Deploy key SSH → GitHub | FALHA | FALHA |
| `~/retro_hex_chat/` (git repo) | MISSING | MISSING |
| GitHub Actions Secrets | CONFIGURADO | CONFIGURADO |

---

## Fase 1 — Corrigir Infra (bloqueante)

> Executar via agente de AI no repo `retro_hex_chat_infra`.
> Instruções em `docs/infra-deployex-adjustments.md`.

### Tasks

- [ ] **1.1** Obter public keys dos servidores e registrar como deploy keys no GitHub
- [ ] **1.2** Validar: `ssh -T git@github.com` funciona em Moon
- [ ] **1.3** Validar: `ssh -T git@github.com` funciona em Sun
- [ ] **1.4** Criar role `app_clone` e adicionar ao playbook
- [ ] **1.5** Executar `make provision-moon`
- [ ] **1.6** Validar: `~/retro_hex_chat/.git` existe em Moon
- [ ] **1.7** Executar `make provision-sun`
- [ ] **1.8** Validar: `~/retro_hex_chat/.git` existe em Sun

**Critério de saída**: ambos servidores com repo clonado e acesso SSH ao GitHub.

---

## Fase 2 — Deploy Manual (Moon → Staging)

> Primeiro deploy real. Testa o fluxo completo: build no servidor + DeployEx.

### Tasks

- [ ] **2.1** Executar `make deploy-moon REF=main`
- [ ] **2.2** Validar: script terminou sem erros (exit code 0)
- [ ] **2.3** Validar via SSH: tarball existe em `~/releases/dist/retro_hex_chat/retro_hex_chat-0.1.0-*.tar.gz`
- [ ] **2.4** Validar via SSH: `current.json` tem versão, hash, e pre_commands corretos
- [ ] **2.5** Aguardar ~10s e validar: DeployEx fez deploy (checar dashboard ou logs)
- [ ] **2.6** Usuário testa: https://deployex.moon.retrohexchat.app — app aparece com versão nova
- [ ] **2.7** Usuário testa: https://moon.retrohexchat.app — login, canal, mensagem

**Critério de saída**: app rodando em Moon com a versão do commit atual.

---

## Fase 3 — Deploy Manual (Sun → Produção)

> Só executar se Fase 2 passou 100%.

### Tasks

- [ ] **3.1** Executar `make deploy-sun REF=main`
- [ ] **3.2** Validar: mesmos checks da Fase 2
- [ ] **3.3** Usuário testa: https://deployex.sun.retrohexchat.app
- [ ] **3.4** Usuário testa: https://sun.retrohexchat.app

**Critério de saída**: app rodando em Sun.

---

## Fase 4 — Deploy CI via Tag (Moon → Staging)

> Testa o workflow GitHub Actions → SSH → deploy.sh.

### Tasks

- [ ] **4.1** Criar e push tag: `git tag moon-2026-02-18.01 && git push origin moon-2026-02-18.01`
- [ ] **4.2** Validar: workflow "Deploy" aparece no GitHub Actions (`gh run list --workflow=deploy.yml`)
- [ ] **4.3** Validar: job terminou com sucesso (`gh run view <id>`)
- [ ] **4.4** Validar via SSH: `current.json` atualizado no servidor
- [ ] **4.5** Usuário testa: app funciona em https://moon.retrohexchat.app

**Critério de saída**: deploy automático via tag funciona para Moon.

---

## Fase 5 — Deploy CI via Tag (Sun → Produção)

> Só executar se Fase 4 passou.

### Tasks

- [ ] **5.1** Criar e push tag: `git tag sun-2026-02-18.01 && git push origin sun-2026-02-18.01`
- [ ] **5.2** Validar: workflow terminou com sucesso
- [ ] **5.3** Usuário testa: app funciona em https://sun.retrohexchat.app

**Critério de saída**: deploy automático via tag funciona para Sun.

---

## Fase 6 — Edge Cases

### Tasks

- [ ] **6.1** Deploy de commit SHA: `make deploy-moon REF=<sha-anterior>`
- [ ] **6.2** Validar: versão no `current.json` reflete o SHA correto
- [ ] **6.3** Segundo deploy seguido (mesmo REF): `make deploy-moon REF=main` 2x
- [ ] **6.4** Validar: segundo deploy funciona sem erros (idempotente)

---

## Comandos de Validação (referência rápida)

```bash
# SSH para verificar estado nos servidores
SSH_MOON="ssh -p 2222 -i ~/.ssh/id_ed25519_pessoal rodrigo@YOUR_STAGING_SERVER_IP"
SSH_SUN="ssh -p 2222 -i ~/.ssh/id_ed25519_pessoal rodrigo@YOUR_PRODUCTION_SERVER_IP"

# Verificar tarball
$SSH_MOON "ls -la ~/releases/dist/retro_hex_chat/"

# Verificar current.json
$SSH_MOON "cat ~/releases/versions/retro_hex_chat/local/current.json"

# Verificar logs do DeployEx
$SSH_MOON "sudo journalctl -u deployex --since '5 minutes ago' --no-pager | tail -30"

# Verificar se a app está rodando (DeployEx service dir)
$SSH_MOON "ls /var/lib/deployex/service/retro_hex_chat/ 2>/dev/null || ls /tmp/deployex/varlib/service/retro_hex_chat/ 2>/dev/null"

# GitHub Actions
gh run list --workflow=deploy.yml --limit=5
gh run view <run-id> --log
```
