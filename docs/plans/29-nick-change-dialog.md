# Nick Change Dialog Migration

## Objetivo

Migrar dialog de troca de nick, incluindo senha de nick registrado e formulario hidden de sessao, para fluxo isolado.

## Codigo atual

- Hidden form: `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/app/chat_live.html.heex:3`
- Render dialog: `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/app/chat_live.html.heex:554`
- Component: `apps/retro_hex_chat_web/lib/retro_hex_chat_web/components/ui/dialogs/nick_change_dialog.ex`
- Events: `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/chat_live/account_events.ex`
- State atual: `nick_change_dialog`, `nick_change_target`, `nick_change_token`.

## Tecnica

Use LiveComponent stateful para password draft e validation. O fluxo que submete form de sessao pode permanecer global, mas deve ser encapsulado em componente/hidden hook proprio.

## Tasks

- [ ] Criar `NickChangeDialogComponent`.
- [ ] Mover password/password_error para o componente.
- [ ] Manter target/registered como payload de abertura.
- [ ] Encapsular hidden form e `NickChangeFormHook`.
- [ ] Emitir `{:confirm_nick_change, target, password}` ao parent.
- [ ] Parent retorna token/erro por update.

## Validacao

- [ ] Troca para nick livre funciona.
- [ ] Troca para nick registrado exige senha.
- [ ] Erro aparece sem limpar target.
- [ ] Sucesso atualiza sessao e canal ativo.
- [ ] Hidden form nao fica no template principal.

## Prompt de execucao

Este fluxo cruza LiveView e sessao HTTP. Isole UI, mas mantenha cuidado com token e redirect.


## Progress Log

- 2026-06-27: Planejado. Nenhuma implementacao iniciada ainda.
