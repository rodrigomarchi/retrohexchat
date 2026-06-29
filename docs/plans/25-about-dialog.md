# About Dialog Migration

## Objetivo

Remover estado server-side desnecessario do About dialog.

## Codigo atual

- Render: `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/app/chat_live.html.heex:516`
- Component: `apps/retro_hex_chat_web/lib/retro_hex_chat_web/components/ui/dialogs/about_dialog.ex`
- State atual: `show_about`.
- Abertura atual via `show_modal("about-dialog")` no logo: `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/app/chat_live.html.heex:34`.

## Tecnica

Preferir `Phoenix.LiveView.JS` e dialog function component sem stateful server se nao ha dados dinamicos. O parent nao precisa manter `show_about`.

## Tasks

- [x] Confirmar se About e puramente estatico — SIM (sem dados dinamicos; so a versao).
- [x] Remover `show_about` — `show_modal/1` JA era suficiente (logo `on_logo_click` e o item de menu `on_click` ja abriam via `show_modal("about-dialog")`). Removido: assign default, handler `show_about` (vestigial — ninguem na UI o disparava), e a referencia em `close_dialog`.
- [x] **NAO** criar componente wrapper — dialog sem estado nao vira LiveComponent (orientacao do plano). Fica function component renderizado com `show={false}`; o conteudo sempre existe no DOM, o JS controla visibilidade.
- [x] Garantir close via JS sem roundtrip — OK/X (`hide_modal`), Escape e click-away ja eram JS; inalterado.

## Validacao

- [x] Clicar logo abre About (`show_modal`, inalterado).
- [x] Fechar por botao/Escape/click externo funciona (JS `hide_modal`, inalterado).
- [x] Nenhum evento server e emitido para abrir/fechar About — handler `show_about` removido; ChatLive nao tem mais caminho server para About.
- [x] Parent nao tem assign `show_about` (removido do `assign_defaults`).

## Prompt de execucao

Dialog estatico deve ser client-side sempre que possivel. Nao transforme em LiveComponent se nao ha estado.


## Progress Log

- 2026-06-27: Planejado. Nenhuma implementacao iniciada ainda.
- 2026-06-28 — **COMPLETE (JS-only, sem LiveComponent).**
  - **Licao importante:** comecei extraindo um `AboutDialog` LiveComponent (recipe dos outros dialogs), mas a investigacao mostrou que About e **stateless e ja aberto 100% via JS** (`show_modal` no logo `chat_live.html.heex:34` e no item de menu `menu_bar_app.ex:278`). O `<.dialog>` renderiza o conteudo SEMPRE (so alterna a classe `hidden` + um `show-trigger` server). Logo, o assign `show_about` era **vestigial** (so o teste o disparava). Reverti o LiveComponent e fiz o correto: JS-only.
  - Arquivos: removido `components/about_dialog.ex` (LiveComponent) + seu teste. `menu_toolbar_events.ex` (removido handler `show_about` + moduledoc), `core_events.ex` (`close_dialog` nao mexe mais em about), `chat_live.ex` (removido default; mantido import do function component), `chat_live.html.heex` (`<.about_dialog show={false} />`). Reescrito `about_feature_test.exs` para a realidade JS-only (conteudo sempre presente; sem show-trigger server).
  - Validacao: `make ci` **9/9**; about_feature_test 2/2. Sem E2E dedicado (abertura/fecho sao JS; cobertos por logo/menu — sem spec Playwright proprio).
  - **Regra destilada para o playbook:** antes de criar um LiveComponent para um dialog, cheque se ele e stateless E ja aberto via `show_modal`/`hide_modal`. Se sim, NAO faca LiveComponent — so remova o assign server vestigial.
