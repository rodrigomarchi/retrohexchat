#!/usr/bin/env python3
"""Apply curated translations for strings that should not fall back to English."""

from __future__ import annotations

import argparse
import ast
import re
from pathlib import Path

from i18n_js_catalogs import LOCALE_EXPORTS, read_catalogs, write_catalogs
from i18n.locales import codes as enabled_locale_codes

PLACEHOLDER_RE = re.compile(r"%\{[A-Za-z0-9_]+\}")

DEFAULT_LOCALES = enabled_locale_codes()


def t(
    de: str,
    es: str,
    fr: str,
    id: str,
    ja: str,
    zh_hans: str,
    pt_BR: str | None = None,
    pt_PT: str | None = None,
    it: str | None = None,
    pl: str | None = None,
    nl: str | None = None,
    ru: str | None = None,
    zh_hant: str | None = None,
) -> dict[str, str]:
    translations = {
        "de": de,
        "es": es,
        "fr": fr,
        "id": id,
        "ja": ja,
        "zh_hans": zh_hans,
    }

    if pt_BR is not None:
        translations["pt_BR"] = pt_BR

    if pt_PT is not None:
        translations["pt_PT"] = pt_PT

    if it is not None:
        translations["it"] = it

    if pl is not None:
        translations["pl"] = pl

    if nl is not None:
        translations["nl"] = nl

    for locale, translated in {
        "ru": ru,
        "zh_hant": zh_hant,
    }.items():
        if translated is not None:
            translations[locale] = translated

    return translations


PO_OVERRIDES = {
    "Menu": t(
        "Menü",
        "Menú",
        "Menu",
        "Menu",
        "メニュー",
        "菜单",
        pt_BR="Menu",
        pt_PT="Menu",
        it="Menu",
        pl="Menu",
        nl="Menu",
        ru="Меню",
        zh_hant="選單",
    ),
    "Windows": t(
        "Fenster",
        "Ventanas",
        "Fenêtres",
        "Jendela",
        "ウィンドウ",
        "窗口",
        pt_BR="Janelas",
        pt_PT="Janelas",
        it="Finestre",
        pl="Okna",
        nl="Vensters",
        ru="Окна",
        zh_hant="視窗",
    ),
    "POPULAR CHANNELS": t(
        "BELIEBTE KANÄLE",
        "CANALES POPULARES",
        "CANAUX POPULAIRES",
        "KANAL POPULER",
        "人気チャンネル",
        "热门频道",
        pt_BR="CANAIS POPULARES",
        pt_PT="CANAIS POPULARES",
        it="CANALI POPOLARI",
        pl="POPULARNE KANAŁY",
        nl="POPULAIRE KANALEN",
        ru="ПОПУЛЯРНЫЕ КАНАЛЫ",
        zh_hant="熱門頻道",
    ),
    "Popular Channels": t(
        "Beliebte Kanäle",
        "Canales populares",
        "Canaux populaires",
        "Kanal populer",
        "人気チャンネル",
        "热门频道",
        pt_BR="Canais populares",
        pt_PT="Canais populares",
        it="Canali popolari",
        pl="Popularne kanały",
        nl="Populaire kanalen",
        ru="Популярные каналы",
        zh_hant="熱門頻道",
    ),
    "Mute user: %{nick}": t(
        "Benutzer stummschalten: %{nick}",
        "Silenciar usuario: %{nick}",
        "Mettre l'utilisateur en sourdine : %{nick}",
        "Bisukan pengguna: %{nick}",
        "ユーザーをミュート: %{nick}",
        "将用户静音：%{nick}",
        pt_BR="Silenciar usuário: %{nick}",
        pt_PT="Silenciar utilizador: %{nick}",
        it="Silenzia utente: %{nick}",
        pl="Wycisz użytkownika: %{nick}",
        nl="Gebruiker dempen: %{nick}",
        ru="Отключить звук пользователя: %{nick}",
        zh_hant="將使用者靜音：%{nick}",
    ),
    "User '%{nickname}' is offline.": t(
        "Benutzer '%{nickname}' ist offline.",
        "El usuario '%{nickname}' está desconectado.",
        "L'utilisateur '%{nickname}' est hors ligne.",
        "Pengguna '%{nickname}' sedang offline.",
        "ユーザー '%{nickname}' はオフラインです。",
        "用户 '%{nickname}' 已离线。",
        pt_BR="O usuário '%{nickname}' está offline.",
        pt_PT="O utilizador '%{nickname}' está offline.",
        it="L'utente '%{nickname}' è offline.",
        pl="Użytkownik '%{nickname}' jest offline.",
        nl="Gebruiker '%{nickname}' is offline.",
        ru="Пользователь '%{nickname}' не в сети.",
        zh_hant="使用者 '%{nickname}' 已離線。",
    ),
    "Join throttle set to %{seconds} seconds.": t(
        "Beitrittsdrossel auf %{seconds} Sekunden gesetzt.",
        "Límite de entrada configurado en %{seconds} segundos.",
        "Limitation d'entrée réglée à %{seconds} secondes.",
        "Pembatasan bergabung diatur ke %{seconds} detik.",
        "参加制限を%{seconds}秒に設定しました。",
        "加入限流已设置为 %{seconds} 秒。",
        pt_BR="Limite de entrada definido para %{seconds} segundos.",
        pt_PT="Limite de entrada definido para %{seconds} segundos.",
        it="Limite di accesso impostato a %{seconds} secondi.",
        pl="Limit dołączania ustawiono na %{seconds} sekund.",
        nl="Deelnamelimiet ingesteld op %{seconds} seconden.",
        ru="Ограничение входа установлено на %{seconds} секунд.",
        zh_hant="加入限流已設定為 %{seconds} 秒。",
    ),
    "Last Seen: %{target}": t(
        "Zuletzt gesehen: %{target}",
        "Visto por última vez: %{target}",
        "Dernière vue : %{target}",
        "Terakhir terlihat: %{target}",
        "最終確認: %{target}",
        "最后在线：%{target}",
        pt_BR="Visto por último: %{target}",
        pt_PT="Visto pela última vez: %{target}",
        it="Ultima visualizzazione: %{target}",
        pl="Ostatnio widziany: %{target}",
        nl="Laatst gezien: %{target}",
        ru="Последний визит: %{target}",
        zh_hant="最後上線：%{target}",
    ),
    "Loading %{channel}...": t(
        "%{channel} wird geladen...",
        "Cargando %{channel}...",
        "Chargement de %{channel}...",
        "Memuat %{channel}...",
        "%{channel}を読み込み中...",
        "正在加载 %{channel}...",
        pt_BR="Carregando %{channel}...",
        pt_PT="A carregar %{channel}...",
        it="Caricamento di %{channel}...",
        pl="Wczytywanie %{channel}...",
        nl="%{channel} laden...",
        ru="Загрузка %{channel}...",
        zh_hant="正在載入 %{channel}...",
    ),
    "Lobby invite sent to %{target}. Waiting for response...": t(
        "Lobby-Einladung an %{target} gesendet. Warte auf Antwort...",
        "Invitación al lobby enviada a %{target}. Esperando respuesta...",
        "Invitation au lobby envoyée à %{target}. En attente de réponse...",
        "Undangan lobi dikirim ke %{target}. Menunggu respons...",
        "ロビー招待を%{target}に送信しました。応答を待っています...",
        "大厅邀请已发送给 %{target}。正在等待回应...",
        pt_BR="Convite para o lobby enviado para %{target}. Aguardando resposta...",
        pt_PT="Convite para o lobby enviado a %{target}. A aguardar resposta...",
        it="Invito alla lobby inviato a %{target}. In attesa di risposta...",
        pl="Zaproszenie do lobby wysłano do %{target}. Oczekiwanie na odpowiedź...",
        nl="Lobby-uitnodiging verzonden naar %{target}. Wachten op antwoord...",
        ru="Приглашение в лобби отправлено %{target}. Ожидание ответа...",
        zh_hant="大廳邀請已傳送給 %{target}。正在等待回應...",
    ),
    "Notice to %{target}:": t(
        "Hinweis an %{target}:",
        "Aviso para %{target}:",
        "Avis à %{target} :",
        "Pemberitahuan untuk %{target}:",
        "%{target}への通知:",
        "通知 %{target}：",
        pt_BR="Aviso para %{target}:",
        pt_PT="Aviso para %{target}:",
        it="Avviso a %{target}:",
        pl="Powiadomienie dla %{target}:",
        nl="Melding aan %{target}:",
        ru="Уведомление для %{target}:",
        zh_hant="通知 %{target}：",
    ),
    "P2P lobby invite from %{from} — /lobby/%{token}": t(
        "P2P-Lobby-Einladung von %{from} — /lobby/%{token}",
        "Invitación al lobby P2P de %{from} — /lobby/%{token}",
        "Invitation au lobby P2P de %{from} — /lobby/%{token}",
        "Undangan lobi P2P dari %{from} — /lobby/%{token}",
        "%{from}からのP2Pロビー招待 — /lobby/%{token}",
        "来自 %{from} 的 P2P 大厅邀请 — /lobby/%{token}",
        pt_BR="Convite para lobby P2P de %{from} — /lobby/%{token}",
        pt_PT="Convite para lobby P2P de %{from} — /lobby/%{token}",
        it="Invito alla lobby P2P da %{from} — /lobby/%{token}",
        pl="Zaproszenie do lobby P2P od %{from} — /lobby/%{token}",
        nl="P2P-lobbyuitnodiging van %{from} — /lobby/%{token}",
        ru="Приглашение в P2P-лобби от %{from} — /lobby/%{token}",
        zh_hant="來自 %{from} 的 P2P 大廳邀請 — /lobby/%{token}",
    ),
    "P2P lobby ready. Join the lobby: /lobby/%{token}": t(
        "P2P-Lobby bereit. Lobby beitreten: /lobby/%{token}",
        "Lobby P2P listo. Únete al lobby: /lobby/%{token}",
        "Lobby P2P prêt. Rejoignez le lobby : /lobby/%{token}",
        "Lobi P2P siap. Gabung lobi: /lobby/%{token}",
        "P2Pロビーの準備ができました。ロビーに参加: /lobby/%{token}",
        "P2P 大厅已就绪。加入大厅：/lobby/%{token}",
        pt_BR="Lobby P2P pronto. Entrar no lobby: /lobby/%{token}",
        pt_PT="Lobby P2P pronto. Entrar no lobby: /lobby/%{token}",
        it="Lobby P2P pronta. Entra nella lobby: /lobby/%{token}",
        pl="Lobby P2P gotowe. Dołącz do lobby: /lobby/%{token}",
        nl="P2P-lobby klaar. Neem deel aan de lobby: /lobby/%{token}",
        ru="P2P-лобби готово. Присоединиться к лобби: /lobby/%{token}",
        zh_hant="P2P 大廳已就緒。加入大廳：/lobby/%{token}",
    ),
    "Throttle error: %{message}": t(
        "Drosselungsfehler: %{message}",
        "Error de limitación: %{message}",
        "Erreur de limitation : %{message}",
        "Kesalahan pembatasan: %{message}",
        "制限エラー: %{message}",
        "限流错误：%{message}",
        pt_BR="Erro de limitação: %{message}",
        pt_PT="Erro de limitação: %{message}",
        it="Errore di limitazione: %{message}",
        pl="Błąd limitu: %{message}",
        nl="Limietfout: %{message}",
        ru="Ошибка ограничения: %{message}",
        zh_hant="限流錯誤：%{message}",
    ),
    "Welcome error: %{message}": t(
        "Willkommensfehler: %{message}",
        "Error de bienvenida: %{message}",
        "Erreur de bienvenue : %{message}",
        "Kesalahan sambutan: %{message}",
        "ウェルカムエラー: %{message}",
        "欢迎消息错误：%{message}",
        pt_BR="Erro de boas-vindas: %{message}",
        pt_PT="Erro de boas-vindas: %{message}",
        it="Errore di benvenuto: %{message}",
        pl="Błąd powitania: %{message}",
        nl="Welkomstfout: %{message}",
        ru="Ошибка приветствия: %{message}",
        zh_hant="歡迎訊息錯誤：%{message}",
    ),
    "Whois: %{target}": t(
        "Whois für %{target}",
        "Whois de %{target}",
        "Whois de %{target}",
        "Whois untuk %{target}",
        "%{target}のWhois",
        "%{target} 的 Whois",
        pt_BR="Whois de %{target}",
        pt_PT="Whois de %{target}",
        it="Whois di %{target}",
        pl="Whois dla %{target}",
        nl="Whois voor %{target}",
        ru="Whois для %{target}",
        zh_hant="%{target} 的 Whois",
    ),
    "by %{creator}": t(
        "von %{creator}",
        "por %{creator}",
        "par %{creator}",
        "oleh %{creator}",
        "%{creator}作成",
        "由 %{creator} 创建",
        pt_BR="por %{creator}",
        pt_PT="por %{creator}",
        it="di %{creator}",
        pl="przez %{creator}",
        nl="door %{creator}",
        ru="от %{creator}",
        zh_hant="由 %{creator} 建立",
    ),
    "by %{creator} · with %{peer}": t(
        "von %{creator} · mit %{peer}",
        "por %{creator} · con %{peer}",
        "par %{creator} · avec %{peer}",
        "oleh %{creator} · dengan %{peer}",
        "%{creator}作成 · %{peer}と",
        "由 %{creator} 创建 · 与 %{peer}",
        pt_BR="por %{creator} · com %{peer}",
        pt_PT="por %{creator} · com %{peer}",
        it="di %{creator} · con %{peer}",
        pl="przez %{creator} · z %{peer}",
        nl="door %{creator} · met %{peer}",
        ru="от %{creator} · с %{peer}",
        zh_hant="由 %{creator} 建立 · 與 %{peer}",
    ),
    "Call: %{channel}": t(
        "Anruf: %{channel}",
        "Llamada: %{channel}",
        "Appel : %{channel}",
        "Panggilan: %{channel}",
        "通話: %{channel}",
        "通话：%{channel}",
        pt_BR="Chamada: %{channel}",
        pt_PT="Chamada: %{channel}",
        it="Chiamata: %{channel}",
        pl="Połączenie: %{channel}",
        nl="Oproep: %{channel}",
        ru="Звонок: %{channel}",
        zh_hant="通話：%{channel}",
    ),
    "Call: %{channel} (%{count})": t(
        "Anruf: %{channel} (%{count})",
        "Llamada: %{channel} (%{count})",
        "Appel : %{channel} (%{count})",
        "Panggilan: %{channel} (%{count})",
        "通話: %{channel} (%{count})",
        "通话：%{channel}（%{count}）",
        pt_BR="Chamada: %{channel} (%{count})",
        pt_PT="Chamada: %{channel} (%{count})",
        it="Chiamata: %{channel} (%{count})",
        pl="Połączenie: %{channel} (%{count})",
        nl="Oproep: %{channel} (%{count})",
        ru="Звонок: %{channel} (%{count})",
        zh_hant="通話：%{channel}（%{count}）",
    ),
    "Call: error in %{channel}": t(
        "Anruffehler in %{channel}",
        "Error de llamada en %{channel}",
        "Erreur d'appel dans %{channel}",
        "Kesalahan panggilan di %{channel}",
        "%{channel} で通話エラー",
        "%{channel} 中的通话错误",
        pt_BR="Erro na chamada em %{channel}",
        pt_PT="Erro na chamada em %{channel}",
        it="Errore di chiamata in %{channel}",
        pl="Błąd połączenia w %{channel}",
        nl="Oproepfout in %{channel}",
        ru="Ошибка звонка в %{channel}",
        zh_hant="%{channel} 中的通話錯誤",
    ),
    "  Relay ports: %{used_ports}/%{total_ports} in use\n": t(
        "  Relay-Ports in Verwendung: %{used_ports}/%{total_ports}\n",
        "  Puertos relay en uso: %{used_ports}/%{total_ports}\n",
        "  Ports relais utilisés : %{used_ports}/%{total_ports}\n",
        "  Port relay digunakan: %{used_ports}/%{total_ports}\n",
        "  リレー ポート使用中: %{used_ports}/%{total_ports}\n",
        "  中继端口使用中：%{used_ports}/%{total_ports}\n",
    ),
    "%{prefix}\nRound over! %{scores}": t(
        "%{prefix}\nRunde beendet! %{scores}",
        "%{prefix}\n¡Ronda terminada! %{scores}",
        "%{prefix}\nManche terminée ! %{scores}",
        "%{prefix}\nRonde selesai! %{scores}",
        "%{prefix}\nラウンド終了！ %{scores}",
        "%{prefix}\n回合结束！%{scores}",
        pt_PT="%{prefix}\nRonda terminada! %{scores}",
    ),
    "Round over! %{scores}": t(
        "Runde beendet! %{scores}",
        "¡Ronda terminada! %{scores}",
        "Manche terminée ! %{scores}",
        "Ronde selesai! %{scores}",
        "ラウンド終了！ %{scores}",
        "回合结束！%{scores}",
        pt_PT="%{prefix}\nRonda terminada! %{scores}",
    ),
    "Trivia started! (%{category}, %{count} questions)\n%{question}": t(
        "Trivia gestartet! (%{category}, %{count} Fragen)\n%{question}",
        "¡Trivia iniciada! (%{category}, %{count} preguntas)\n%{question}",
        "Quiz lancé ! (%{category}, %{count} questions)\n%{question}",
        "Trivia dimulai! (%{category}, %{count} pertanyaan)\n%{question}",
        "トリビア開始！（%{category}、%{count}問）\n%{question}",
        "问答开始！（%{category}，%{count} 个问题）\n%{question}",
    ),
    "Trivia stopped! %{scores}": t(
        "Trivia gestoppt! %{scores}",
        "¡Trivia detenida! %{scores}",
        "Quiz arrêté ! %{scores}",
        "Trivia dihentikan! %{scores}",
        "トリビアを停止しました！ %{scores}",
        "问答已停止！%{scores}",
    ),
    "Scores (Q%{number}/%{total}): No scores yet.": t(
        "Punkte (F%{number}/%{total}): noch keine Punkte.",
        "Puntuaciones (P%{number}/%{total}): aún no hay puntuaciones.",
        "Scores (Q%{number}/%{total}) : aucun score pour le moment.",
        "Skor (P%{number}/%{total}): belum ada skor.",
        "スコア（Q%{number}/%{total}）: まだスコアはありません。",
        "得分（第 %{number}/%{total} 题）：暂无得分。",
    ),
    "Scores (Q%{number}/%{total}): %{ranked}": t(
        "Punkte (F%{number}/%{total}): %{ranked}",
        "Puntuaciones (P%{number}/%{total}): %{ranked}",
        "Scores (Q%{number}/%{total}) : %{ranked}",
        "Skor (P%{number}/%{total}): %{ranked}",
        "スコア（Q%{number}/%{total}）: %{ranked}",
        "得分（第 %{number}/%{total} 题）：%{ranked}",
    ),
    "Q%{number}/%{total}: %{question}": t(
        "F%{number}/%{total}: %{question}",
        "P%{number}/%{total}: %{question}",
        "Q%{number}/%{total} : %{question}",
        "P%{number}/%{total}: %{question}",
        "問題%{number}/%{total}: %{question}",
        "第 %{number}/%{total} 题：%{question}",
        pt_BR="P%{number}/%{total}: %{question}",
        pt_PT="P%{number}/%{total}: %{question}",
        zh_hant="第 %{number}/%{total} 題：%{question}",
    ),
    "Correct, %{author}! (+%{points} points)": t(
        "Richtig, %{author}! (+%{points} Punkte)",
        "¡Correcto, %{author}! (+%{points} puntos)",
        "Correct, %{author} ! (+%{points} points)",
        "Benar, %{author}! (+%{points} poin)",
        "正解です、%{author}！ (+%{points} ポイント)",
        "回答正确，%{author}！（+%{points} 分）",
    ),
    "%{author}: You must be identified to play. Use /ns identify <password> first.": t(
        "%{author}: Du musst identifiziert sein, um zu spielen. Verwende zuerst /ns identify <password>.",
        "%{author}: debes identificarte para jugar. Usa /ns identify <password> primero.",
        "%{author} : vous devez être identifié pour jouer. Utilisez d'abord /ns identify <password>.",
        "%{author}: Anda harus teridentifikasi untuk bermain. Gunakan /ns identify <password> terlebih dahulu.",
        "%{author}: プレイするには本人確認が必要です。先に /ns identify <password> を使用してください。",
        "%{author}：你必须先完成身份验证才能游戏。请先使用 /ns identify <password>。",
    ),
    "%{author}: You must be registered to play. Use /ns register <password> first.": t(
        "%{author}: Du musst registriert sein, um zu spielen. Verwende zuerst /ns register <password>.",
        "%{author}: debes registrarte para jugar. Usa /ns register <password> primero.",
        "%{author} : vous devez être inscrit pour jouer. Utilisez d'abord /ns register <password>.",
        "%{author}: Anda harus terdaftar untuk bermain. Gunakan /ns register <password> terlebih dahulu.",
        "%{author}: プレイするには登録が必要です。先に /ns register <password> を使用してください。",
        "%{author}：你必须先注册才能游戏。请先使用 /ns register <password>。",
    ),
    "%{bot}: Arcade session ready!": t(
        "%{bot}: Arcade-Sitzung bereit!",
        "%{bot}: ¡sesión arcade lista!",
        "%{bot} : session arcade prête !",
        "%{bot}: sesi arcade siap!",
        "%{bot}: アーケードセッションの準備ができました！",
        "%{bot}：街机会话已就绪！",
    ),
    "[NickServ] %{nickname}: registered %{registered_at}, identified: %{identified}": t(
        "[NickServ] %{nickname}: registriert %{registered_at}, identifiziert: %{identified}",
        "[NickServ] %{nickname}: registrado %{registered_at}, identificado: %{identified}",
        "[NickServ] %{nickname} : inscrit %{registered_at}, identifié : %{identified}",
        "[NickServ] %{nickname}: terdaftar %{registered_at}, teridentifikasi: %{identified}",
        "[NickServ] %{nickname}: 登録 %{registered_at}、認証済み: %{identified}",
        "[NickServ] %{nickname}：注册于 %{registered_at}，已验证：%{identified}",
    ),
    "%{target_nick} added to %{level} list of %{channel_name}": t(
        "%{target_nick} zur Liste %{level} von %{channel_name} hinzugefügt",
        "%{target_nick} agregado a la lista %{level} de %{channel_name}",
        "%{target_nick} ajouté à la liste %{level} de %{channel_name}",
        "%{target_nick} ditambahkan ke daftar %{level} %{channel_name}",
        "%{target_nick} を %{channel_name} の %{level} リストに追加しました",
        "%{target_nick} 已添加到 %{channel_name} 的 %{level} 列表",
    ),
    "Failed to add %{target_nick} to %{level} list": t(
        "%{target_nick} konnte nicht zur Liste %{level} hinzugefügt werden",
        "No se pudo agregar %{target_nick} a la lista %{level}",
        "Impossible d'ajouter %{target_nick} à la liste %{level}",
        "Gagal menambahkan %{target_nick} ke daftar %{level}",
        "%{target_nick} を %{level} リストに追加できませんでした",
        "无法将 %{target_nick} 添加到 %{level} 列表",
    ),
    "Failed to reset password for %{nickname}": t(
        "Passwort für %{nickname} konnte nicht zurückgesetzt werden",
        "No se pudo restablecer la contraseña de %{nickname}",
        "Impossible de réinitialiser le mot de passe de %{nickname}",
        "Gagal mereset kata sandi untuk %{nickname}",
        "%{nickname} のパスワードをリセットできませんでした",
        "无法重置 %{nickname} 的密码",
    ),
    "Audio call started. Join the lobby: /p2p/%{token}": t(
        "Audioanruf gestartet. Lobby beitreten: /p2p/%{token}",
        "Llamada de audio iniciada. Entra a la sala: /p2p/%{token}",
        "Appel audio démarré. Rejoindre le salon : /p2p/%{token}",
        "Panggilan audio dimulai. Masuk ke lobi: /p2p/%{token}",
        "音声通話を開始しました。ロビーに参加: /p2p/%{token}",
        "音频通话已开始。加入大厅：/p2p/%{token}",
    ),
    "File transfer started. Join the lobby: /p2p/%{token}": t(
        "Dateiübertragung gestartet. Lobby beitreten: /p2p/%{token}",
        "Transferencia de archivo iniciada. Entra a la sala: /p2p/%{token}",
        "Transfert de fichier démarré. Rejoindre le salon : /p2p/%{token}",
        "Transfer file dimulai. Masuk ke lobi: /p2p/%{token}",
        "ファイル転送を開始しました。ロビーに参加: /p2p/%{token}",
        "文件传输已开始。加入大厅：/p2p/%{token}",
    ),
    "Game session started! Join the lobby: /game/%{token}": t(
        "Spielsitzung gestartet! Lobby beitreten: /game/%{token}",
        "¡Sesión de juego iniciada! Entra a la sala: /game/%{token}",
        "Session de jeu démarrée ! Rejoindre le salon : /game/%{token}",
        "Sesi game dimulai! Masuk ke lobi: /game/%{token}",
        "ゲームセッションを開始しました！ロビーに参加: /game/%{token}",
        "游戏会话已开始！加入大厅：/game/%{token}",
    ),
    "P2P session started. Join the lobby: /p2p/%{token}": t(
        "P2P-Sitzung gestartet. Lobby beitreten: /p2p/%{token}",
        "Sesión P2P iniciada. Entra a la sala: /p2p/%{token}",
        "Session P2P démarrée. Rejoindre le salon : /p2p/%{token}",
        "Sesi P2P dimulai. Masuk ke lobi: /p2p/%{token}",
        "P2P セッションを開始しました。ロビーに参加: /p2p/%{token}",
        "P2P 会话已开始。加入大厅：/p2p/%{token}",
    ),
    "Video call started. Join the lobby: /p2p/%{token}": t(
        "Videoanruf gestartet. Lobby beitreten: /p2p/%{token}",
        "Videollamada iniciada. Entra a la sala: /p2p/%{token}",
        "Appel vidéo démarré. Rejoindre le salon : /p2p/%{token}",
        "Panggilan video dimulai. Masuk ke lobi: /p2p/%{token}",
        "ビデオ通話を開始しました。ロビーに参加: /p2p/%{token}",
        "视频通话已开始。加入大厅：/p2p/%{token}",
    ),
    "Game invite from %{from} — /game/%{token}": t(
        "Spieleinladung von %{from} — /game/%{token}",
        "Invitación de juego de %{from} — /game/%{token}",
        "Invitation de jeu de %{from} — /game/%{token}",
        "Undangan game dari %{from} — /game/%{token}",
        "%{from} からのゲーム招待 — /game/%{token}",
        "来自 %{from} 的游戏邀请 — /game/%{token}",
    ),
    "Alias /%{name} already exists": t(
        "Alias /%{name} existiert bereits",
        "El alias /%{name} ya existe",
        "L'alias /%{name} existe déjà",
        "Alias /%{name} sudah ada",
        "エイリアス /%{name} はすでに存在します",
        "别名 /%{name} 已存在",
    ),
    "Alias /%{name} not found": t(
        "Alias /%{name} nicht gefunden",
        "Alias /%{name} no encontrado",
        "Alias /%{name} introuvable",
        "Alias /%{name} tidak ditemukan",
        "エイリアス /%{name} が見つかりません",
        "未找到别名 /%{name}",
    ),
    "* Alias /%{name} created%{warning}": t(
        "* Alias /%{name} erstellt%{warning}",
        "* Alias /%{name} creado%{warning}",
        "* Alias /%{name} créé%{warning}",
        "* Alias /%{name} dibuat%{warning}",
        "* エイリアス /%{name} を作成しました%{warning}",
        "* 已创建别名 /%{name}%{warning}",
    ),
    "* Alias /%{name} removed": t(
        "* Alias /%{name} entfernt",
        "* Alias /%{name} eliminado",
        "* Alias /%{name} supprimé",
        "* Alias /%{name} dihapus",
        "* エイリアス /%{name} を削除しました",
        "* 已移除别名 /%{name}",
    ),
    "shadows built-in /%{name}": t(
        "verdeckt den eingebauten Befehl /%{name}",
        "oculta el comando integrado /%{name}",
        "masque la commande intégrée /%{name}",
        "menimpa perintah bawaan /%{name}",
        "組み込みコマンド /%{name} を上書きします",
        "会覆盖内置命令 /%{name}",
    ),
    "User mode +%{flag} enabled.": t(
        "Benutzermodus +%{flag} aktiviert.",
        "Modo de usuario +%{flag} activado.",
        "Mode utilisateur +%{flag} activé.",
        "Mode pengguna +%{flag} diaktifkan.",
        "ユーザーモード +%{flag} を有効にしました。",
        "用户模式 +%{flag} 已启用。",
    ),
    "* Accepted invite to %{channel} from %{inviter}": t(
        "* Einladung zu %{channel} von %{inviter} angenommen",
        "* Invitación aceptada a %{channel} de %{inviter}",
        "* Invitation acceptée vers %{channel} de %{inviter}",
        "* Undangan ke %{channel} dari %{inviter} diterima",
        "* %{inviter} から %{channel} への招待を承諾しました",
        "* 已接受 %{inviter} 发往 %{channel} 的邀请",
    ),
    "* Inviting %{target} to %{channel}": t(
        "* Lade %{target} zu %{channel} ein",
        "* Invitando a %{target} a %{channel}",
        "* Invitation de %{target} vers %{channel}",
        "* Mengundang %{target} ke %{channel}",
        "* %{target} を %{channel} に招待中",
        "* 正在邀请 %{target} 加入 %{channel}",
    ),
    "* Removed %{channel} from auto-join list": t(
        "* %{channel} aus der Auto-Join-Liste entfernt",
        "* %{channel} eliminado de la lista de autoentrada",
        "* %{channel} supprimé de la liste de connexion automatique",
        "* %{channel} dihapus dari daftar auto-join",
        "* %{channel} を自動参加リストから削除しました",
        "* 已从自动加入列表移除 %{channel}",
    ),
    "* Timer '%{name}' set: %{type}, %{interval}s → %{command}": t(
        "* Timer '%{name}' gesetzt: %{type}, %{interval}s → %{command}",
        "* Temporizador '%{name}' configurado: %{type}, %{interval}s → %{command}",
        "* Minuteur '%{name}' défini : %{type}, %{interval}s → %{command}",
        "* Timer '%{name}' diatur: %{type}, %{interval}s → %{command}",
        "* タイマー '%{name}' を設定しました: %{type}, %{interval}s → %{command}",
        "* 计时器 '%{name}' 已设置：%{type}, %{interval}s → %{command}",
    ),
    "* Performing: %{command}": t(
        "* Ausführen: %{command}",
        "* Ejecutando: %{command}",
        "* Exécution : %{command}",
        "* Menjalankan: %{command}",
        "* 実行中: %{command}",
        "* 正在执行：%{command}",
    ),
    "Failed to send game invite to %{target}.": t(
        "Spieleinladung an %{target} konnte nicht gesendet werden.",
        "No se pudo enviar la invitación de juego a %{target}.",
        "Impossible d'envoyer l'invitation de jeu à %{target}.",
        "Gagal mengirim undangan game ke %{target}.",
        "%{target} にゲーム招待を送信できませんでした。",
        "无法向 %{target} 发送游戏邀请。",
    ),
    "Failed to add auto-join channel: %{reason}": t(
        "Auto-Join-Kanal konnte nicht hinzugefügt werden: %{reason}",
        "No se pudo agregar el canal de autoentrada: %{reason}",
        "Impossible d'ajouter le canal de connexion automatique : %{reason}",
        "Gagal menambahkan kanal auto-join: %{reason}",
        "自動参加チャンネルを追加できませんでした: %{reason}",
        "无法添加自动加入频道：%{reason}",
    ),
    "Failed to add ignore: %{reason}": t(
        "Ignore konnte nicht hinzugefügt werden: %{reason}",
        "No se pudo agregar ignore: %{reason}",
        "Impossible d'ajouter l'ignore : %{reason}",
        "Gagal menambahkan ignore: %{reason}",
        "ignore を追加できませんでした: %{reason}",
        "无法添加忽略项：%{reason}",
    ),
    "Failed to add perform command: %{reason}": t(
        "Perform-Befehl konnte nicht hinzugefügt werden: %{reason}",
        "No se pudo agregar el comando perform: %{reason}",
        "Impossible d'ajouter la commande perform : %{reason}",
        "Gagal menambahkan perintah perform: %{reason}",
        "perform コマンドを追加できませんでした: %{reason}",
        "无法添加 perform 命令：%{reason}",
    ),
    "Topic error: %{message}": t(
        "Topic-Fehler: %{message}",
        "Error de tema: %{message}",
        "Erreur de sujet : %{message}",
        "Kesalahan topik: %{message}",
        "トピックエラー: %{message}",
        "主题错误：%{message}",
    ),
    "Mode error: %{message}": t(
        "Modusfehler: %{message}",
        "Error de modo: %{message}",
        "Erreur de mode : %{message}",
        "Kesalahan mode: %{message}",
        "モードエラー: %{message}",
        "模式错误：%{message}",
    ),
    "Quit message: %{message}": t(
        "Quit-Nachricht: %{message}",
        "Mensaje de salida: %{message}",
        "Message de départ : %{message}",
        "Pesan keluar: %{message}",
        "終了メッセージ: %{message}",
        "退出消息：%{message}",
    ),
    "Away: %{message}": t(
        "Abwesend: %{message}",
        "Ausente: %{message}",
        "Absent : %{message}",
        "Tidak hadir: %{message}",
        "離席中: %{message}",
        "离开：%{message}",
        pt_BR="Ausente: %{message}",
    ),
    "Bio: %{bio}": t(
        "Bio: %{bio}",
        "Biografía: %{bio}",
        "Bio : %{bio}",
        "Bio: %{bio}",
        "プロフィール: %{bio}",
        "简介：%{bio}",
    ),
    "Error: %{message}": t(
        "Fehler: %{message}",
        "Error: %{message}",
        "Erreur : %{message}",
        "Kesalahan: %{message}",
        "エラー: %{message}",
        "错误：%{message}",
    ),
    "Hint: %{hint}": t(
        "Hinweis: %{hint}",
        "Pista: %{hint}",
        "Indice : %{hint}",
        "Petunjuk: %{hint}",
        "ヒント: %{hint}",
        "提示：%{hint}",
    ),
    "Idle for: %{duration}": t(
        "Inaktiv seit: %{duration}",
        "Inactivo durante: %{duration}",
        "Inactif depuis : %{duration}",
        "Diam selama: %{duration}",
        "アイドル時間: %{duration}",
        "空闲时间：%{duration}",
    ),
    "Edited at %{timestamp}": t(
        "Bearbeitet um %{timestamp}",
        "Editado a las %{timestamp}",
        "Modifié à %{timestamp}",
        "Diedit pada %{timestamp}",
        "%{timestamp} に編集",
        "编辑时间：%{timestamp}",
    ),
    "Color %{index}: %{name}": t(
        "Farbe %{index}: %{name}",
        "Color %{index}: %{name}",
        "Couleur %{index} : %{name}",
        "Warna %{index}: %{name}",
        "色 %{index}: %{name}",
        "颜色 %{index}：%{name}",
    ),
    "Color %{index}": t(
        "Farbe %{index}",
        "Color n.º %{index}",
        "Couleur %{index}",
        "Warna %{index}",
        "色 %{index}",
        "颜色 %{index}",
        pt_BR="Cor %{index}",
        pt_PT="Cor %{index}",
        it="Colore %{index}",
        pl="Kolor %{index}",
        nl="Kleur %{index}",
        ru="Цвет %{index}",
        zh_hant="顏色 %{index}",
    ),
    "Version %{version}": t(
        "Version %{version}",
        "Versión %{version}",
        "Version %{version}",
        "Versi %{version}",
        "バージョン %{version}",
        "版本 %{version}",
    ),
    "Client: %{client}": t(
        "Klient: %{client}",
        "Cliente: %{client}",
        "Client : %{client}",
        "Klien: %{client}",
        "クライアント: %{client}",
        "客户端：%{client}",
        pt_BR="Cliente: %{client}",
    ),
    "Nickname: %{nickname}": t(
        "Nickname: %{nickname}",
        "Apodo: %{nickname}",
        "Pseudo : %{nickname}",
        "Nama panggilan: %{nickname}",
        "ニックネーム: %{nickname}",
        "昵称：%{nickname}",
        pt_BR="Apelido: %{nickname}",
    ),
    "  Nickname: %{nickname}": t(
        "  Spitzname: %{nickname}",
        "  Apodo: %{nickname}",
        "  Pseudo : %{nickname}",
        "  Nama panggilan: %{nickname}",
        "  ニックネーム: %{nickname}",
        "  昵称：%{nickname}",
        pt_BR="  Apelido: %{nickname}",
    ),
    "Channel Central: %{channel}": t(
        "Kanalzentrale: %{channel}",
        "Central del canal: %{channel}",
        "Centre du canal : %{channel}",
        "Pusat Kanal: %{channel}",
        "チャンネル セントラル: %{channel}",
        "频道中心：%{channel}",
    ),
    "Set by %{nick}": t(
        "Gesetzt von %{nick}",
        "Definido por %{nick}",
        "Défini par %{nick}",
        "Diatur oleh %{nick}",
        "%{nick} が設定",
        "由 %{nick} 设置",
    ),
    "on %{date}": t(
        "am %{date}",
        "el %{date}",
        "le %{date}",
        "pada %{date}",
        "%{date}",
        "于 %{date}",
    ),
    "Add Command — %{bot}": t(
        "Befehl hinzufügen — %{bot}",
        "Agregar comando — %{bot}",
        "Ajouter une commande — %{bot}",
        "Tambah Perintah — %{bot}",
        "コマンドを追加 — %{bot}",
        "添加命令 — %{bot}",
    ),
    "Arcade — %{nickname}": t(
        "Arcade — %{nickname}",
        "Arcade — %{nickname}",
        "Arcade — %{nickname}",
        "Arcade — %{nickname}",
        "アーケード — %{nickname}",
        "街机 — %{nickname}",
    ),
    "Game Lobby — %{nickname} vs %{peer}": t(
        "Spiel-Lobby — %{nickname} gegen %{peer}",
        "Sala de juego — %{nickname} vs %{peer}",
        "Salon de jeu — %{nickname} contre %{peer}",
        "Lobi Game — %{nickname} vs %{peer}",
        "ゲームロビー — %{nickname} vs %{peer}",
        "游戏大厅 — %{nickname} 对 %{peer}",
    ),
    "%{game} — %{nickname} vs %{peer}": t(
        "%{game} — %{nickname} gegen %{peer}",
        "%{game} — %{nickname} vs %{peer}",
        "%{game} — %{nickname} contre %{peer}",
        "%{game} — %{nickname} vs %{peer}",
        "%{game} — %{nickname} vs %{peer}",
        "%{game} — %{nickname} 对 %{peer}",
    ),
    "Reconnecting (%{attempt}/3)": t(
        "Verbindung wird wiederhergestellt (%{attempt}/3)",
        "Reconectando (%{attempt}/3)",
        "Reconnexion (%{attempt}/3)",
        "Menghubungkan ulang (%{attempt}/3)",
        "再接続中 (%{attempt}/3)",
        "正在重新连接（%{attempt}/3）",
    ),
    "Max: %{size} MB": t(
        "Max.: %{size} MB",
        "Máx.: %{size} MB",
        "Max. : %{size} MB",
        "Maks: %{size} MB",
        "最大: %{size} MB",
        "最大：%{size} MB",
    ),
    "Max %{size} MB": t(
        "Max. %{size} MB",
        "Máx. %{size} MB",
        "Max. %{size} MB",
        "Maks. %{size} MB",
        "最大 %{size} MB",
        "最大 %{size} MB",
        pt_BR="Máx. %{size} MB",
        pt_PT="Máx. %{size} MB",
        it="Massimo %{size} MB",
        pl="Maks. %{size} MB",
        nl="Max. %{size} MB",
        ru="Макс. %{size} MB",
        zh_hant="最大 %{size} MB",
    ),
    "Peer %{peer}": t(
        "Gegenstelle %{peer}",
        "Par %{peer}",
        "Pair %{peer}",
        "Rekan %{peer}",
        "ピア %{peer}",
        "对端 %{peer}",
        pt_BR="Par %{peer}",
        pt_PT="Par %{peer}",
        it="Contatto %{peer}",
        pl="Partner %{peer}",
        nl="Contact %{peer}",
        ru="Пир %{peer}",
        zh_hant="對端 %{peer}",
    ),
    "P2P Session with %{peer}": t(
        "P2P-Sitzung mit %{peer}",
        "Sesión P2P con %{peer}",
        "Session P2P avec %{peer}",
        "Sesi P2P dengan %{peer}",
        "%{peer} との P2P セッション",
        "与 %{peer} 的 P2P 会话",
        pt_BR="Sessão P2P com %{peer}",
        pt_PT="Sessão P2P com %{peer}",
        it="Sessione P2P con %{peer}",
        pl="Sesja P2P z %{peer}",
        nl="P2P-sessie met %{peer}",
        ru="P2P-сеанс с %{peer}",
        zh_hant="與 %{peer} 的 P2P 工作階段",
    ),
    "P2P session with %{peer} - %{facets}": t(
        "P2P-Sitzung mit %{peer} - %{facets}",
        "Sesión P2P con %{peer} - %{facets}",
        "Session P2P avec %{peer} - %{facets}",
        "Sesi P2P dengan %{peer} - %{facets}",
        "%{peer} との P2P セッション - %{facets}",
        "与 %{peer} 的 P2P 会话 - %{facets}",
        pt_BR="Sessão P2P com %{peer} - %{facets}",
        pt_PT="Sessão P2P com %{peer} - %{facets}",
        it="Sessione P2P con %{peer} - %{facets}",
        pl="Sesja P2P z %{peer} - %{facets}",
        nl="P2P-sessie met %{peer} - %{facets}",
        ru="P2P-сеанс с %{peer} - %{facets}",
        zh_hant="與 %{peer} 的 P2P 工作階段 - %{facets}",
    ),
    "%{count} games": t(
        "%{count} Spiele",
        "%{count} juegos",
        "%{count} jeux",
        "%{count} game",
        "%{count} ゲーム",
        "%{count} 个游戏",
        pt_BR="%{count} jogos",
        pt_PT="%{count} jogos",
        it="%{count} giochi",
        pl="%{count} gry",
        nl="%{count} spellen",
        ru="%{count} игр",
        zh_hant="%{count} 個遊戲",
    ),
    "%{count} peers": t(
        "%{count} Peers",
        "%{count} pares",
        "%{count} pairs",
        "%{count} peer",
        "%{count} ピア",
        "%{count} 个对端",
        pt_BR="%{count} pares",
        pt_PT="%{count} pares",
        it="%{count} peer",
        pl="%{count} peerów",
        nl="%{count} contacten",
        ru="%{count} пиров",
        zh_hant="%{count} 個對端",
    ),
    "%{peer} wants to play": t(
        "%{peer} moechte spielen",
        "%{peer} quiere jugar",
        "%{peer} veut jouer",
        "%{peer} ingin bermain",
        "%{peer} がプレイしたがっています",
        "%{peer} 想玩",
        pt_BR="%{peer} quer jogar",
        pt_PT="%{peer} quer jogar",
        it="%{peer} vuole giocare",
        pl="%{peer} chce zagrać",
        nl="%{peer} wil spelen",
        ru="%{peer} хочет играть",
        zh_hant="%{peer} 想玩",
    ),
    "Retrying the peer connection, attempt %{attempt} of 3.": t(
        "Peer-Verbindung wird erneut versucht, Versuch %{attempt} von 3.",
        "Reintentando la conexión con el par, intento %{attempt} de 3.",
        "Nouvelle tentative de connexion au pair, essai %{attempt} sur 3.",
        "Mencoba ulang koneksi peer, percobaan %{attempt} dari 3.",
        "ピア接続を再試行中、3 回中 %{attempt} 回目です。",
        "正在重试对端连接，第 %{attempt}/3 次。",
        pt_BR="Tentando novamente a conexão com o par, tentativa %{attempt} de 3.",
        pt_PT="A tentar novamente a ligação ao par, tentativa %{attempt} de 3.",
        it="Nuovo tentativo di connessione al peer, tentativo %{attempt} di 3.",
        pl="Ponawianie połączenia z peerem, próba %{attempt} z 3.",
        nl="Peerverbinding opnieuw proberen, poging %{attempt} van 3.",
        ru="Повторное подключение к пиру, попытка %{attempt} из 3.",
        zh_hant="正在重試對端連線，第 %{attempt}/3 次。",
    ),
    "Call and game stay active with %{peer}.": t(
        "Anruf und Spiel bleiben mit %{peer} aktiv.",
        "La llamada y el juego permanecen activos con %{peer}.",
        "L'appel et le jeu restent actifs avec %{peer}.",
        "Panggilan dan game tetap aktif dengan %{peer}.",
        "通話とゲームは %{peer} と引き続き有効です。",
        "通话和游戏会与 %{peer} 保持活动。",
        pt_BR="Chamada e jogo continuam ativos com %{peer}.",
        pt_PT="A chamada e o jogo continuam ativos com %{peer}.",
        it="Chiamata e gioco restano attivi con %{peer}.",
        pl="Rozmowa i gra pozostają aktywne z %{peer}.",
        nl="Gesprek en spel blijven actief met %{peer}.",
        ru="Звонок и игра остаются активными с %{peer}.",
        zh_hant="通話和遊戲會與 %{peer} 保持啟用。",
    ),
    "WebRTC: %{state}": t(
        "WebRTC: %{state}",
        "WebRTC: %{state}",
        "WebRTC : %{state}",
        "WebRTC: %{state}",
        "WebRTC: %{state}",
        "WebRTC：%{state}",
    ),
    "Rolling %{notation}: %{rolls} %{sign} %{modifier} = %{total}": t(
        "Würfle %{notation}: %{rolls} %{sign} %{modifier} = %{total}",
        "Lanzando %{notation}: %{rolls} %{sign} %{modifier} = %{total}",
        "Lancer %{notation} : %{rolls} %{sign} %{modifier} = %{total}",
        "Melempar %{notation}: %{rolls} %{sign} %{modifier} = %{total}",
        "%{notation} をロール: %{rolls} %{sign} %{modifier} = %{total}",
        "掷骰 %{notation}：%{rolls} %{sign} %{modifier} = %{total}",
    ),
    "Rolling %{notation}: %{rolls} = %{sum}": t(
        "Würfle %{notation}: %{rolls} = %{sum}",
        "Lanzando %{notation}: %{rolls} = %{sum}",
        "Lancer %{notation} : %{rolls} = %{sum}",
        "Melempar %{notation}: %{rolls} = %{sum}",
        "%{notation} をロール: %{rolls} = %{sum}",
        "掷骰 %{notation}：%{rolls} = %{sum}",
    ),
    "%{count} item": t(
        "%{count} Element",
        "%{count} elemento",
        "%{count} élément",
        "%{count} item",
        "%{count} 件",
        "%{count} 项",
    ),
    "%{count} items": t(
        "%{count} Elemente",
        "%{count} elementos",
        "%{count} éléments",
        "%{count} item",
        "%{count} 件",
        "%{count} 项",
    ),
    "%{engine} Engine": t(
        "%{engine}-Engine",
        "Motor %{engine}",
        "Moteur %{engine}",
        "Mesin %{engine}",
        "%{engine} エンジン",
        "%{engine} 引擎",
    ),
    "%{topic} — RetroHexChat Help": t(
        "%{topic} — RetroHexChat-Hilfe",
        "%{topic} — Ayuda de RetroHexChat",
        "%{topic} — Aide RetroHexChat",
        "%{topic} — Bantuan RetroHexChat",
        "%{topic} — RetroHexChat ヘルプ",
        "%{topic} — RetroHexChat 帮助",
    ),
    "Farewell set to '%{farewell}'.": t(
        "Abschied auf '%{farewell}' gesetzt.",
        "Despedida definida como '%{farewell}'.",
        "Message d'adieu défini sur '%{farewell}'.",
        "Pesan perpisahan diatur ke '%{farewell}'.",
        "別れのメッセージを '%{farewell}' に設定しました。",
        "告别消息已设置为 '%{farewell}'。",
    ),
    "BEAM uptime: %{uptime_days}d %{remaining_hours}h": t(
        "BEAM-Laufzeit: %{uptime_days}d %{remaining_hours}h",
        "Tiempo activo de BEAM: %{uptime_days}d %{remaining_hours}h",
        "Disponibilité BEAM : %{uptime_days}j %{remaining_hours}h",
        "Uptime BEAM: %{uptime_days} hari %{remaining_hours} jam",
        "BEAM 稼働時間: %{uptime_days}日 %{remaining_hours}時間",
        "BEAM 运行时间：%{uptime_days}天 %{remaining_hours}小时",
    ),
    "*** Active Channel Processes (%{channels_count}) ***": t(
        "*** Aktive Kanalprozesse (%{channels_count}) ***",
        "*** Procesos de canal activos (%{channels_count}) ***",
        "*** Processus de canal actifs (%{channels_count}) ***",
        "*** Proses kanal aktif (%{channels_count}) ***",
        "*** アクティブなチャンネルプロセス (%{channels_count}) ***",
        "*** 活跃频道进程（%{channels_count}）***",
    ),
    "*** Ban List for %{channel} (%{bans_count}) ***": t(
        "*** Ban-Liste für %{channel} (%{bans_count}) ***",
        "*** Lista de baneos de %{channel} (%{bans_count}) ***",
        "*** Liste des bannissements pour %{channel} (%{bans_count}) ***",
        "*** Daftar ban untuk %{channel} (%{bans_count}) ***",
        "*** %{channel} の BAN リスト (%{bans_count}) ***",
        "*** %{channel} 的封禁列表（%{bans_count}）***",
    ),
    "*** NUKE PREVIEW — %{total} records will be destroyed ***": t(
        "*** NUKE-VORSCHAU — %{total} Datensätze werden zerstört ***",
        "*** VISTA PREVIA DE NUKE — se destruirán %{total} registros ***",
        "*** APERÇU NUKE — %{total} enregistrements seront détruits ***",
        "*** PRATINJAU NUKE — %{total} catatan akan dihancurkan ***",
        "*** NUKE プレビュー — %{total} 件のレコードが破棄されます ***",
        "*** NUKE 预览 — 将销毁 %{total} 条记录 ***",
    ),
    "*** SYSTEM NUKED — %{total} records destroyed ***": t(
        "*** SYSTEM GENUKED — %{total} Datensätze zerstört ***",
        "*** SISTEMA NUKEADO — %{total} registros destruidos ***",
        "*** SYSTÈME NUKE — %{total} enregistrements détruits ***",
        "*** SISTEM DI-NUKE — %{total} catatan dihancurkan ***",
        "*** システムを NUKE しました — %{total} 件のレコードを破棄しました ***",
        "*** 系统已 NUKE — 已销毁 %{total} 条记录 ***",
    ),
    "*** Server Ban List (%{filtered_count}) ***": t(
        "*** Server-Ban-Liste (%{filtered_count}) ***",
        "*** Lista de baneos del servidor (%{filtered_count}) ***",
        "*** Liste des bannissements serveur (%{filtered_count}) ***",
        "*** Daftar ban server (%{filtered_count}) ***",
        "*** サーバー BAN リスト (%{filtered_count}) ***",
        "*** 服务器封禁列表（%{filtered_count}）***",
    ),
    "[BotService] Bot Info: %{name}": t(
        "[BotService] Bot-Info: %{name}",
        "[BotService] Información del bot: %{name}",
        "[BotService] Infos du bot : %{name}",
        "[BotService] Info bot: %{name}",
        "[BotService] Bot 情報: %{name}",
        "[BotService] 机器人信息：%{name}",
        pt_BR="[BotService] Informações do bot: %{name}",
        pt_PT="[BotService] Informação do bot: %{name}",
    ),
    "[BotService] Failed to add command '%{trigger}': %{message}": t(
        "[BotService] Befehl '%{trigger}' konnte nicht hinzugefügt werden: %{message}",
        "[BotService] No se pudo agregar el comando '%{trigger}': %{message}",
        "[BotService] Impossible d'ajouter la commande '%{trigger}' : %{message}",
        "[BotService] Gagal menambahkan perintah '%{trigger}': %{message}",
        "[BotService] コマンド '%{trigger}' を追加できませんでした: %{message}",
        "[BotService] 无法添加命令 '%{trigger}'：%{message}",
    ),
    "[BotService] Failed to create bot '%{name}': %{message}": t(
        "[BotService] Bot '%{name}' konnte nicht erstellt werden: %{message}",
        "[BotService] No se pudo crear el bot '%{name}': %{message}",
        "[BotService] Impossible de créer le bot '%{name}' : %{message}",
        "[BotService] Gagal membuat bot '%{name}': %{message}",
        "[BotService] Bot '%{name}' を作成できませんでした: %{message}",
        "[BotService] 无法创建机器人 '%{name}'：%{message}",
    ),
    "[BotService] Failed to create bot: %{message}": t(
        "[BotService] Bot konnte nicht erstellt werden: %{message}",
        "[BotService] No se pudo crear el bot: %{message}",
        "[BotService] Impossible de créer le bot : %{message}",
        "[BotService] Gagal membuat bot: %{message}",
        "[BotService] Bot を作成できませんでした: %{message}",
        "[BotService] 无法创建机器人：%{message}",
    ),
    "[BotService] Capability '%{capability}' %{action}.": t(
        "[BotService] Fähigkeit '%{capability}' %{action}.",
        "[BotService] Capacidad '%{capability}' %{action}.",
        "[BotService] Capacité '%{capability}' %{action}.",
        "[BotService] Kapabilitas '%{capability}' %{action}.",
        "[BotService] 機能 '%{capability}' %{action}。",
        "[BotService] 能力 '%{capability}' %{action}。",
        pt_BR="[BotService] Recurso '%{capability}' %{action}.",
    ),
    "  %{nickname} [registered] [%{online}]": t(
        "  %{nickname} [registriert] [%{online}]",
        "  %{nickname} [registrado] [%{online}]",
        "  %{nickname} [inscrit] [%{online}]",
        "  %{nickname} [terdaftar] [%{online}]",
        "  %{nickname} [登録済み] [%{online}]",
        "  %{nickname} [已注册] [%{online}]",
    ),
}

PO_WAVE2_OVERRIDES = {
    "  Admin: %{is_admin}\n": {
    },
    "  Binary: %{binary}\n": {
    },
    "  Modes: %{modes}\n": {
    },
    " for %{duration_seconds}": {
    },
    "for %{duration}": {
    },
    "  Prefix: %{command_prefix}": {
    },
    "Hint: %{hint}": {
    },
    "Q%{number}/%{total}: %{question}": {
        "ru": "В%{number}/%{total}: %{question}",
    },
    "%{prefix}\nRound over! %{scores}": {
    },
    "[BotService] Bot Info: %{name}": {
    },
    "[ChanServ] %{name}: founder=%{founder}, registered=%{registered_at}": {
        "pt_PT": "[ChanServ] %{name}: fundador=%{founder}, registado=%{registered_at}",
    },
    "* Rejoining %{channel}...": {
        "pt_PT": "* A voltar a entrar em %{channel}...",
    },
    "[BotService] %{capability} config updated.": {
        "pt_PT": "[BotService] Configuração de %{capability} atualizada.",
    },
    "* No whowas information available for %{target}.": {
    },
    "* Sent away auto-reply to %{sender}": {
    },
    "Away: %{message}": {
    },
    "Edited at %{timestamp}": {
    },
    "Idle for: %{duration}": {
    },
    "Invalid ignore type: %{type}": {
    },
    "Mode set: %{mode}": {
    },
    "P2P invite from %{from}": {
    },
    "Topic for %{channel}: %{topic}": {
    },
    "[Welcome] %{message}": {
    },
    "%{action} request accepted.": {
        "ru": "Запрос %{action} принят.",
    },
    "%{action} request declined.": {
        "ru": "Запрос %{action} отклонен.",
    },
    "%{count} cores": {
        "ru": "%{count} ядер",
    },
    "%{peer} wants to add video": {
        "ru": "%{peer} хочет добавить видео",
    },
    "Action Request: %{action}": {
        "ru": "Запрос действия: %{action}",
    },
    "Call ended: %{reason}": {
        "ru": "Звонок завершен: %{reason}",
    },
    "Cancelled by %{nickname}": {
        "ru": "Отменено %{nickname}",
    },
    "Duration: %{duration}": {
        "ru": "Длительность: %{duration}",
    },
    "Max: %{size} MB": {
        "ru": "Макс.: %{size} МБ",
    },
    "Permission denied for %{type}. Please try again.": {
        "ru": "Доступ к %{type} запрещен. Попробуйте снова.",
    },
    "Quality: %{quality}": {
        "ru": "Качество: %{quality}",
    },
    "Reconnecting (%{attempt}/3)": {
        "ru": "Повторное подключение (%{attempt}/3)",
    },
    "* Bio set: %{text}": {
    },
    "* Performing: %{command}": {
    },
    "* Timer '%{name}' set: %{type}, %{interval}s → %{command}": {
    },
    "Online for: %{duration}": {
    },
    "Timezone: %{timezone}": {
    },
    "Topic set: %{topic}": {
    },
    "You are now known as %{nickname}": {
    },
    "You are setting: %{flag} (%{label})": {
    },
    "[BotService] Failed to create bot '%{name}': %{message}": {
    },
    "%{count} line": {
    },
    "[BotService] %{bot} %{action} in %{channel}.": {
    },
}

for source, translations in PO_WAVE2_OVERRIDES.items():
    PO_OVERRIDES.setdefault(source, {}).update(translations)

PO_WAVE3_OVERRIDES = {
    "  Admin: %{is_admin}\n": {
        "it": "  Amministratore: %{is_admin}\n",
        "pl": "  Administrator: %{is_admin}\n",
    },
    "  Bans: %{state_bans_count}\n": {
        "it": "  Ban: %{state_bans_count}\n",
    },
    "  Binary: %{binary}\n": {
        "it": "  Binario: %{binary}\n",
        "pl": "  Plik binarny: %{binary}\n",
    },
    "Q%{number}/%{total}: %{question}": {
        "it": "D%{number}/%{total}: %{question}",
        "pl": "P%{number}/%{total}: %{question}",
        "nl": "V%{number}/%{total}: %{question}",
    },
    "Rolling %{notation}: %{rolls} %{sign} %{modifier} = %{total}": {
        "it": "Lancio %{notation}: %{rolls} %{sign} %{modifier} = %{total}",
    },
    "Rolling %{notation}: %{rolls} = %{sum}": {
        "it": "Lancio %{notation}: %{rolls} = %{sum}",
    },
    "  Nickname: %{nickname}": {
        "it": "  Soprannome: %{nickname}",
        "pl": "  Pseudonim: %{nickname}",
    },
    "%{cap_name}.%{field} set to %{display}.": {
        "it": "%{cap_name}.%{field} impostato su %{display}.",
    },
    "[BotService] Bot Info: %{name}": {
        "it": "[BotService] Info bot: %{name}",
        "pl": "[BotService] Informacje o bocie: %{name}",
    },
    "Timezone: %{timezone}": {
        "it": "Fuso orario: %{timezone}",
    },
    "[BotService] %{bot} %{action} in %{channel}.": {
        "it": "[BotService] %{bot} %{action} su %{channel}.",
        "nl": "[BotService] %{bot} %{action} op %{channel}.",
    },
    "Set by %{nick}": {
        "it": "Impostato da %{nick}",
    },
    "Max: %{size} MB": {
        "it": "Massimo: %{size} MB",
        "pl": "Maks.: %{size} MB",
        "nl": "Max.: %{size} MB",
    },
    "Hint: %{hint}": {
        "nl": "Tip: %{hint}",
    },
    "Scores (Q%{number}/%{total}): %{ranked}": {
        "nl": "Puntenstand (V%{number}/%{total}): %{ranked}",
    },
    "Client: %{client}": {
        "nl": "Client-app: %{client}",
    },
    "— Bot requests the user be kicked (requires channel operator)": {
        "nl": "— Bot vraagt om de gebruiker te kicken (vereist kanaaloperator)",
    },
    "— Bot requests the user be muted (requires channel operator)": {
        "nl": "— Bot vraagt om de gebruiker te dempen (vereist kanaaloperator)",
    },
    "— Detects messages that are mostly uppercase (potential shouting).": {
        "nl": "— Detecteert berichten die grotendeels uit hoofdletters bestaan (mogelijk schreeuwen).",
    },
    "— Maximum items posted per poll (default: 3)": {
        "nl": "— Maximaal aantal items per poll (standaard: 3)",
    },
    "— Seconds per question (default: 30)": {
        "nl": "— Seconden per vraag (standaard: 30)",
    },
    "— add modifier (e.g.,": {
        "nl": "— modifier toevoegen (bijv.,",
    },
    "— subtract modifier (e.g.,": {
        "nl": "— modifier aftrekken (bijv.,",
    },
    "— welcomes users when they join a channel, optionally says goodbye on part": {
        "nl": "— verwelkomt gebruikers wanneer ze een kanaal betreden en zegt optioneel gedag bij vertrek",
    },
    "— Display name of the server (shown in welcome message and server info)": {
        "nl": "— Weergavenaam van de server (getoond in welkomstbericht en serverinformatie)",
    },
    "— Force-drop a channel registration (bypasses founder check)": {
        "nl": "— Forceer het verwijderen van een kanaalregistratie (omzeilt de oprichtercontrole)",
    },
    "— Manage Auto Voice (get voice on join).": {
        "nl": "— Auto Voice beheren (voice bij binnenkomst).",
    },
    "— Show notices in the sender's PM window (opens one if needed).": {
        "nl": "— Toon notices in het PM-venster van de afzender (opent er een indien nodig).",
    },
    "— View registration info about a nickname (defaults to your own).": {
        "nl": "— Bekijk registratie-info over een nickname (standaard die van jezelf).",
    },
    "— Positional arguments (words typed after the alias).": {
        "nl": "— Positionele argumenten (woorden getypt na de alias).",
    },
    "— Show next entry, or restore your draft when past the newest entry.": {
        "nl": "— Toon het volgende item of herstel je concept na het nieuwste item.",
    },
    "— Activate turbo boost": {
        "nl": "— Activeer turboboost",
    },
    "— Configure anti-flood and auto-ignore settings.": {
        "nl": "— Configureer anti-flood- en auto-ignore-instellingen.",
    },
    "— Configure words that trigger message highlighting.": {
        "nl": "— Configureer woorden die berichtmarkering activeren.",
    },
    "  Status: %{status}": {
        "pl": "  Stan: %{status}",
    },
    "* Alias /%{name} created%{warning}": {
        "pl": "* Alias /%{name} utworzony%{warning}",
    },
    "* Bio set: %{text}": {
        "pl": "* Bio ustawione: %{text}",
    },
    "* Your bio: %{bio}": {
        "pl": "* Twoje bio: %{bio}",
    },
    "Edited at %{timestamp}": {
        "pl": "Edytowano o %{timestamp}",
    },
    "Idle for: %{duration}": {
        "pl": "Bezczynny przez: %{duration}",
    },
}

for source, translations in PO_WAVE3_OVERRIDES.items():
    PO_OVERRIDES.setdefault(source, {}).update(translations)

PO_RESIDUAL_OVERRIDES = {
    "%{actor} allowed %{count} conference camera.": {
        "nl": "%{actor} heeft %{count} conferentiecamera toegestaan.",
    },
    "%{actor} allowed %{count} conference cameras.": {
        "nl": "%{actor} heeft %{count} conferentiecamera's toegestaan.",
    },
    "%{actor} allowed %{count} conference microphone.": {
        "nl": "%{actor} heeft %{count} conferentiemicrofoon toegestaan.",
    },
    "%{actor} allowed %{count} conference microphones.": {
        "nl": "%{actor} heeft %{count} conferentiemicrofoons toegestaan.",
        "zh_hans": "%{actor} 已允许 %{count} 个会议麦克风。",
        "zh_hant": "%{actor} 已允許 %{count} 個會議麥克風。",
    },
    "%{actor} allowed %{target} to speak.": {
        "ja": "%{actor}が%{target}の発言を許可しました。",
        "nl": "%{actor} heeft %{target} toestemming gegeven om te spreken.",
    },
    "%{actor} allowed %{target}'s conference camera.": {
        "nl": "%{actor} heeft de conferentiecamera van %{target} toegestaan.",
    },
    "%{actor} allowed %{target}'s conference microphone.": {
        "nl": "%{actor} heeft de conferentiemicrofoon van %{target} toegestaan.",
    },
    "%{actor} turned off %{count} conference cameras.": {
        "ja": "%{actor}が%{count}台の会議カメラをオフにしました。",
        "nl": "%{actor} heeft %{count} conferentiecamera's uitgeschakeld.",
    },
    "%{actor} turned off %{target}'s conference camera.": {
        "fr": "%{actor} a désactivé la caméra de conférence de %{target}.",
        "nl": "%{actor} heeft de conferentiecamera van %{target} uitgeschakeld.",
    },
    "%{count} buddies online": {
        "de": "%{count} Freunde online",
    },
    "%{count} topics": {
        "nl": "%{count} onderwerpen",
    },
    "%{level} quality: RTT %{rtt} ms, loss %{loss}%, %{bitrate} kbps, %{fps} fps, freezes %{freezes}": {
    },
    "%{nick} cancelled the P2P invite.": {
        "ja": "%{nick}がP2P招待をキャンセルしました。",
    },
    "%{nick} declined the P2P invite.": {
        "nl": "%{nick} heeft de P2P-uitnodiging geweigerd.",
    },
    "%{peer} declined the P2P invite.": {
        "nl": "%{peer} heeft de P2P-uitnodiging geweigerd.",
    },
    "%{peer} wants to play %{game}": {
        "ja": "%{peer}が%{game}をプレイしたがっています",
        "nl": "%{peer} wil %{game} spelen",
    },
    "%{peer}'s camera is off": {
        "pt_BR": "A câmera de %{peer} está desligada",
        "pt_PT": "A câmara de %{peer} está desligada",
    },
    "%{state} conference in %{channel}: %{count}/%{max} participants, %{duration}": {
        "ja": "%{channel}の%{state}会議: %{count}/%{max}人、%{duration}",
        "nl": "%{state} conferentie in %{channel}: %{count}/%{max} deelnemers, %{duration}",
    },
    "%{target} started sharing a screen.": {
        "zh_hans": "%{target} 开始共享屏幕。",
        "zh_hant": "%{target} 開始共享螢幕。",
    },
    "Allow %{nickname} to speak": {
        "nl": "%{nickname} toestaan om te spreken",
    },
    "Are you sure you want to drop %{channel}? This cannot be undone.": {
        "zh_hans": "确定要放弃 %{channel} 吗？此操作无法撤销。",
        "zh_hant": "確定要放棄 %{channel} 嗎？此操作無法復原。",
    },
    "Call %{duration}": {
        "es": "Llamada %{duration}",
        "id": "Panggilan %{duration}",
        "pl": "Połączenie %{duration}",
    },
    "Game over — %{game}: %{p1} × %{p2}": {
        "it": "Partita finita — %{game}: %{p1} × %{p2}",
        "nl": "Spel afgelopen — %{game}: %{p1} × %{p2}",
    },
    "Mute all lower-ranked participants in %{channel}? They cannot unmute until a moderator allows their microphone again.": {
        "zh_hans": "要将 %{channel} 中所有较低权限的参与者静音吗？在主持人重新允许其麦克风之前，他们无法取消静音。",
        "zh_hant": "要將 %{channel} 中所有較低權限的參與者靜音嗎？在主持人重新允許其麥克風之前，他們無法取消靜音。",
    },
    "P2P session with %{peer}": {
    },
    "P2P session with %{peer} ended.": {
        "nl": "P2P-sessie met %{peer} is beëindigd.",
    },
    "P2P session with %{peer} — %{facets}. Click to focus": {
        "nl": "P2P-sessie met %{peer} — %{facets}. Klik om te focussen",
    },
    "P2P: waiting for %{peer}...": {
    },
    "Remove %{target} from %{channel}? This will ban them from the channel, disconnect them from the conference, and prevent them from rejoining until a channel operator unbans them.": {
        "zh_hans": "要将 %{target} 从 %{channel} 移除吗？这会将其从频道封禁、断开其会议连接，并阻止其重新加入，直到频道操作员解除封禁。",
        "zh_hant": "要將 %{target} 從 %{channel} 移除嗎？這會將其從頻道封禁、斷開其會議連線，並阻止其重新加入，直到頻道操作員解除封禁。",
    },
    "Screen %{duration}": {
        "zh_hans": "屏幕共享 %{duration}",
        "zh_hant": "螢幕分享 %{duration}",
    },
    "Transfer ownership of %{channel} to:": {
        "zh_hans": "将 %{channel} 的所有权转给：",
        "zh_hant": "將 %{channel} 的所有權轉給：",
    },
}

for source, translations in PO_RESIDUAL_OVERRIDES.items():
    PO_OVERRIDES.setdefault(source, {}).update(translations)

PO_CHAT_SIDEBAR_OVERRIDES = {
    "Auto": t(
        "Auto",
        "Auto",
        "Auto",
        "Auto",
        "自動",
        "自动",
        pt_BR="Auto",
        pt_PT="Auto",
        it="Auto",
        pl="Auto",
        nl="Auto",
        ru="Авто",
        zh_hant="自動",
    ),
    "PMs": t(
        "PNs",
        "MPs",
        "MPs",
        "PM",
        "PM",
        "私信",
        pt_BR="PMs",
        pt_PT="MPs",
        it="PM",
        pl="PW",
        nl="PBs",
        ru="ЛС",
        zh_hant="私訊",
    ),
    "PM": t(
        "PN",
        "MP",
        "MP",
        "PM",
        "PM",
        "私信",
        pt_BR="PM",
        pt_PT="MP",
        it="PM",
        pl="PW",
        nl="PB",
        ru="ЛС",
        zh_hant="私訊",
    ),
    "Bold row": t(
        "Fette Zeile",
        "Fila en negrita",
        "Ligne en gras",
        "Baris tebal",
        "太字の行",
        "粗体行",
        pt_BR="Linha em negrito",
        pt_PT="Linha em negrito",
        it="Riga in grassetto",
        pl="Wiersz pogrubiony",
        nl="Vetgedrukte rij",
        ru="Строка жирным",
        zh_hant="粗體列",
    ),
    "Left signal rail": t(
        "Linke Signalleiste",
        "Carril de señal izquierdo",
        "Rail de signal à gauche",
        "Rel sinyal kiri",
        "左の信号レール",
        "左侧信号栏",
        pt_BR="Trilho de sinal à esquerda",
        pt_PT="Faixa de sinal à esquerda",
        it="Barra segnale sinistra",
        pl="Lewy pasek sygnału",
        nl="Linker signaalstrook",
        ru="Левая сигнальная полоса",
        zh_hant="左側信號欄",
    ),
    "Warning icon": t(
        "Warnsymbol",
        "Icono de advertencia",
        "Icône d'avertissement",
        "Ikon peringatan",
        "警告アイコン",
        "警告图标",
        pt_BR="Ícone de aviso",
        pt_PT="Ícone de aviso",
        it="Icona di avviso",
        pl="Ikona ostrzeżenia",
        nl="Waarschuwingspictogram",
        ru="Значок предупреждения",
        zh_hant="警告圖示",
    ),
    "— channel or PM has unread user messages": t(
        "— Kanal oder PM hat ungelesene Benutzernachrichten",
        "— el canal o PM tiene mensajes de usuario sin leer",
        "— le canal ou le MP contient des messages utilisateur non lus",
        "— kanal atau PM memiliki pesan pengguna yang belum dibaca",
        "— チャンネルまたはPMに未読のユーザーメッセージがあります",
        "— 频道或私信有未读用户消息",
        pt_BR="— canal ou PM tem mensagens de usuário não lidas",
        pt_PT="— canal ou PM tem mensagens de utilizador não lidas",
        it="— canale o PM con messaggi utente non letti",
        pl="— kanał lub PM ma nieprzeczytane wiadomości użytkowników",
        nl="— kanaal of PM heeft ongelezen gebruikersberichten",
        ru="— в канале или PM есть непрочитанные сообщения пользователей",
        zh_hant="— 頻道或私訊有未讀使用者訊息",
    ),
    "— channel or PM is muted": t(
        "— Kanal oder PM ist stummgeschaltet",
        "— el canal o PM está silenciado",
        "— le canal ou le MP est mis en sourdine",
        "— kanal atau PM dibisukan",
        "— チャンネルまたはPMはミュートされています",
        "— 频道或私信已静音",
        pt_BR="— canal ou PM está silenciado",
        pt_PT="— canal ou PM está silenciado",
        it="— canale o PM silenziato",
        pl="— kanał lub PM jest wyciszony",
        nl="— kanaal of PM is gedempt",
        ru="— канал или PM отключен",
        zh_hant="— 頻道或私訊已靜音",
    ),
    "— marks unread activity, highlights, the active row, and saved auto-join state": t(
        "— markiert ungelesene Aktivität, Highlights, die aktive Zeile und gespeicherten Auto-Join-Status",
        "— marca actividad sin leer, destacados, la fila activa y el estado de auto-join guardado",
        "— marque l'activité non lue, les surbrillances, la ligne active et l'état auto-join enregistré",
        "— menandai aktivitas belum dibaca, sorotan, baris aktif, dan status auto-join tersimpan",
        "— 未読アクティビティ、ハイライト、アクティブ行、保存済みauto-join状態を示します",
        "— 标记未读活动、高亮、当前行和已保存的 auto-join 状态",
        pt_BR="— marca atividade não lida, highlights, a linha ativa e o estado de auto-join salvo",
        pt_PT="— marca atividade não lida, destaques, a linha ativa e o estado de auto-join guardado",
        it="— indica attività non letta, evidenziazioni, riga attiva e stato auto-join salvato",
        pl="— oznacza nieprzeczytaną aktywność, wyróżnienia, aktywny wiersz i zapisany stan auto-join",
        nl="— markeert ongelezen activiteit, highlights, de actieve rij en opgeslagen auto-joinstatus",
        ru="— отмечает непрочитанную активность, выделения, активную строку и сохраненный статус auto-join",
        zh_hant="— 標記未讀活動、醒目提示、目前列和已儲存的 auto-join 狀態",
    ),
    "The Conversations sidebar is the left IRC navigation pane: activity, joined channels, recent PMs, auto-join channels, and popular channel suggestions.": t(
        "Die Seitenleiste Conversations ist die linke IRC-Navigation: Aktivität, beigetretene Kanäle, aktuelle PMs, Auto-Join-Kanäle und beliebte Kanalvorschläge.",
        "La barra lateral Conversaciones es la navegación IRC izquierda: actividad, canales unidos, PM recientes, canales auto-join y sugerencias de canales populares.",
        "La barre latérale Conversations est la navigation IRC de gauche : activité, canaux rejoints, MP récents, canaux auto-join et suggestions de canaux populaires.",
        "Sidebar Percakapan adalah navigasi IRC kiri: aktivitas, kanal yang diikuti, PM terbaru, kanal auto-join, dan saran kanal populer.",
        "Conversationsサイドバーは左側のIRCナビゲーションです: アクティビティ、参加中チャンネル、最近のPM、auto-joinチャンネル、人気チャンネル候補。",
        "Conversations 侧边栏是左侧 IRC 导航：活动、已加入频道、最近私信、auto-join 频道和热门频道建议。",
        pt_BR="A sidebar Conversas é a navegação IRC à esquerda: atividade, canais abertos, PMs recentes, canais de auto-join e sugestões de canais populares.",
        pt_PT="A barra lateral Conversas é a navegação IRC à esquerda: atividade, canais abertos, PMs recentes, canais de auto-join e sugestões de canais populares.",
        it="La barra laterale Conversazioni è la navigazione IRC a sinistra: attività, canali aperti, PM recenti, canali auto-join e suggerimenti di canali popolari.",
        pl="Pasek boczny Conversations to lewa nawigacja IRC: aktywność, otwarte kanały, ostatnie PM-y, kanały auto-join i sugestie popularnych kanałów.",
        nl="De zijbalk Conversations is de linker IRC-navigatie: activiteit, geopende kanalen, recente PM's, auto-joinkanalen en populaire kanaalsuggesties.",
        ru="Боковая панель Conversations — левая IRC-навигация: активность, открытые каналы, недавние PM, auto-join-каналы и предложения популярных каналов.",
        zh_hant="Conversations 側邊欄是左側 IRC 導覽：活動、已加入頻道、最近私訊、auto-join 頻道和熱門頻道建議。",
    ),
    "IRC-native conversations sidebar with activity, joined channels, recent PMs, auto-join entries, and popular channel suggestions.": t(
        "IRC-native Conversations-Seitenleiste mit Aktivität, beigetretenen Kanälen, aktuellen PMs, Auto-Join-Einträgen und beliebten Kanalvorschlägen.",
        "Barra lateral de conversaciones nativa de IRC con actividad, canales unidos, PM recientes, entradas auto-join y sugerencias de canales populares.",
        "Barre latérale de conversations native IRC avec activité, canaux rejoints, MP récents, entrées auto-join et suggestions de canaux populaires.",
        "Sidebar percakapan native IRC dengan aktivitas, kanal yang diikuti, PM terbaru, entri auto-join, dan saran kanal populer.",
        "アクティビティ、参加中チャンネル、最近のPM、auto-join項目、人気チャンネル候補を備えたIRCネイティブの会話サイドバー。",
        "IRC 原生会话侧边栏，包含活动、已加入频道、最近私信、auto-join 条目和热门频道建议。",
        pt_BR="Sidebar de conversas nativa de IRC com atividade, canais abertos, PMs recentes, entradas de auto-join e sugestões de canais populares.",
        pt_PT="Barra lateral de conversas nativa de IRC com atividade, canais abertos, PMs recentes, entradas de auto-join e sugestões de canais populares.",
        it="Barra laterale conversazioni nativa IRC con attività, canali aperti, PM recenti, voci auto-join e suggerimenti di canali popolari.",
        pl="Natywny dla IRC pasek boczny rozmów z aktywnością, otwartymi kanałami, ostatnimi PM-ami, wpisami auto-join i sugestiami popularnych kanałów.",
        nl="IRC-native gesprekkenzijbalk met activiteit, geopende kanalen, recente PM's, auto-joinitems en populaire kanaalsuggesties.",
        ru="IRC-нативная боковая панель разговоров с активностью, открытыми каналами, недавними PM, записями auto-join и предложениями популярных каналов.",
        zh_hant="IRC 原生對話側邊欄，包含活動、已加入頻道、最近私訊、auto-join 項目和熱門頻道建議。",
    ),
    "The header shows the title, a close button, and compact counters for open channels, recent PMs, and auto-join entries. You can also toggle the panel via the toolbar.": t(
        "Der Header zeigt Titel, Schließen-Schaltfläche und kompakte Zähler für offene Kanäle, aktuelle PMs und Auto-Join-Einträge. Das Panel kann auch über die Toolbar umgeschaltet werden.",
        "El encabezado muestra el título, el botón de cierre y contadores compactos para canales abiertos, PM recientes y entradas auto-join. También puedes alternar el panel desde la barra de herramientas.",
        "L'en-tête affiche le titre, le bouton de fermeture et des compteurs compacts pour les canaux ouverts, les MP récents et les entrées auto-join. Vous pouvez aussi basculer le panneau depuis la barre d'outils.",
        "Header menampilkan judul, tombol tutup, dan penghitung ringkas untuk kanal terbuka, PM terbaru, dan entri auto-join. Panel juga dapat ditoggle dari toolbar.",
        "ヘッダーにはタイトル、閉じるボタン、開いているチャンネル、最近のPM、auto-join項目の小さなカウンターが表示されます。ツールバーからもパネルを切り替えられます。",
        "页眉显示标题、关闭按钮，以及打开频道、最近私信和 auto-join 条目的紧凑计数器。也可以通过工具栏切换面板。",
        pt_BR="O cabeçalho mostra o título, o botão de fechar e contadores compactos de canais abertos, PMs recentes e entradas de auto-join. Você também pode alternar o painel pela toolbar.",
        pt_PT="O cabeçalho mostra o título, o botão de fechar e contadores compactos de canais abertos, PMs recentes e entradas de auto-join. Também pode alternar o painel pela toolbar.",
        it="L'intestazione mostra titolo, pulsante di chiusura e contatori compatti per canali aperti, PM recenti e voci auto-join. Puoi anche alternare il pannello dalla toolbar.",
        pl="Nagłówek pokazuje tytuł, przycisk zamknięcia oraz zwarte liczniki otwartych kanałów, ostatnich PM-ów i wpisów auto-join. Panel można też przełączać z paska narzędzi.",
        nl="De kop toont de titel, sluitknop en compacte tellers voor open kanalen, recente PM's en auto-joinitems. Je kunt het paneel ook via de toolbar wisselen.",
        ru="Заголовок показывает название, кнопку закрытия и компактные счетчики открытых каналов, недавних PM и записей auto-join. Панель также можно переключать через toolbar.",
        zh_hant="標頭顯示標題、關閉按鈕，以及開啟頻道、最近私訊和 auto-join 項目的精簡計數器。也可從工具列切換面板。",
    ),
    "- Active public channels you have not joined yet, plus a button that opens the full channel list": t(
        "- Aktive öffentliche Kanäle, denen du noch nicht beigetreten bist, plus eine Schaltfläche für die vollständige Kanalliste",
        "- Canales públicos activos a los que aún no te has unido, más un botón que abre la lista completa de canales",
        "- Canaux publics actifs que vous n'avez pas encore rejoints, plus un bouton qui ouvre la liste complète des canaux",
        "- Kanal publik aktif yang belum Anda ikuti, ditambah tombol yang membuka daftar kanal lengkap",
        "- まだ参加していないアクティブな公開チャンネルと、完全なチャンネルリストを開くボタン",
        "- 你尚未加入的活跃公开频道，以及打开完整频道列表的按钮",
        pt_BR="- Canais públicos ativos em que você ainda não entrou, mais um botão que abre a lista completa de canais",
        pt_PT="- Canais públicos ativos em que ainda não entrou, mais um botão que abre a lista completa de canais",
        it="- Canali pubblici attivi a cui non ti sei ancora unito, più un pulsante che apre l'elenco completo dei canali",
        pl="- Aktywne publiczne kanały, do których jeszcze nie dołączono, oraz przycisk otwierający pełną listę kanałów",
        nl="- Actieve openbare kanalen waaraan je nog niet deelneemt, plus een knop die de volledige kanaallijst opent",
        ru="- Активные публичные каналы, к которым вы еще не присоединились, и кнопка для открытия полного списка каналов",
        zh_hant="- 尚未加入的活躍公開頻道，以及開啟完整頻道清單的按鈕",
    ),
    "Click a channel or PM to switch to it. Activity rows use an alert surface, unread rows appear": t(
        "Klicke auf einen Kanal oder eine PM, um dorthin zu wechseln. Aktivitätszeilen nutzen eine Warnfläche, ungelesene Zeilen erscheinen",
        "Haz clic en un canal o PM para cambiar a él. Las filas de actividad usan una superficie de alerta y las filas sin leer aparecen",
        "Cliquez sur un canal ou un MP pour y basculer. Les lignes d'activité utilisent une surface d'alerte, les lignes non lues apparaissent",
        "Klik kanal atau PM untuk beralih. Baris aktivitas memakai permukaan peringatan, baris belum dibaca tampil",
        "チャンネルまたはPMをクリックして切り替えます。アクティビティ行は警告サーフェスを使い、未読行は",
        "点击频道或私信即可切换。活动行使用提醒表面，未读行显示为",
        pt_BR="Clique em um canal ou PM para alternar. Linhas de atividade usam uma superfície de alerta, linhas não lidas aparecem",
        pt_PT="Clique num canal ou PM para alternar. Linhas de atividade usam uma superfície de alerta, linhas não lidas aparecem",
        it="Fai clic su un canale o PM per passare a esso. Le righe attività usano una superficie di avviso, le righe non lette appaiono",
        pl="Kliknij kanał lub PM, aby się przełączyć. Wiersze aktywności używają powierzchni alertu, a nieprzeczytane wiersze są",
        nl="Klik op een kanaal of PM om ernaartoe te wisselen. Activiteitsrijen gebruiken een waarschuwingsvlak, ongelezen rijen verschijnen",
        ru="Нажмите канал или PM, чтобы переключиться. Строки активности используют поверхность предупреждения, непрочитанные строки отображаются",
        zh_hant="點擊頻道或私訊即可切換。活動列使用提醒表面，未讀列顯示為",
    ),
    "Shows active public channels you have not joined yet when the server has rooms to suggest. Click [+] to join a suggestion, or click \"Browse All Channels...\" to open the full channel list dialog.": t(
        "Zeigt aktive öffentliche Kanäle, denen du noch nicht beigetreten bist, wenn der Server Räume vorschlagen kann. Klicke auf [+], um einem Vorschlag beizutreten, oder auf \"Alle Kanäle durchsuchen...\", um die vollständige Kanalliste zu öffnen.",
        "Muestra canales públicos activos a los que aún no te has unido cuando el servidor tiene salas que sugerir. Haz clic en [+] para unirte a una sugerencia, o en \"Examinar todos los canales...\" para abrir la lista completa de canales.",
        "Affiche les canaux publics actifs que vous n'avez pas encore rejoints lorsque le serveur a des salons à suggérer. Cliquez sur [+] pour rejoindre une suggestion, ou sur \"Parcourir tous les canaux...\" pour ouvrir la liste complète des canaux.",
        "Menampilkan kanal publik aktif yang belum Anda ikuti saat server memiliki ruang untuk disarankan. Klik [+] untuk bergabung ke saran, atau klik \"Ramban Semua Kanal...\" untuk membuka dialog daftar kanal lengkap.",
        "サーバーに提案できる部屋がある場合、まだ参加していないアクティブな公開チャンネルを表示します。[+]で候補に参加するか、「すべてのチャネルをブラウズ...」で完全なチャンネルリストを開きます。",
        "当服务器有可建议的房间时，显示你尚未加入的活跃公开频道。点击 [+] 加入建议，或点击“浏览所有频道...”打开完整频道列表对话框。",
        pt_BR="Mostra canais públicos ativos em que você ainda não entrou quando o servidor tem salas para sugerir. Clique em [+] para entrar em uma sugestão, ou em \"Ver todos os canais...\" para abrir a lista completa de canais.",
        pt_PT="Mostra canais públicos ativos em que ainda não entrou quando o servidor tem salas para sugerir. Clique em [+] para entrar numa sugestão, ou em \"Navegar em Todos os Canais...\" para abrir a lista completa de canais.",
        it="Mostra canali pubblici attivi a cui non ti sei ancora unito quando il server ha stanze da suggerire. Fai clic su [+] per unirti a un suggerimento, oppure su \"Sfoglia tutti i canali...\" per aprire l'elenco completo.",
        pl="Pokazuje aktywne publiczne kanały, do których jeszcze nie dołączono, gdy serwer ma pokoje do zasugerowania. Kliknij [+], aby dołączyć do sugestii, albo \"Przeglądaj wszystkie kanały...\", aby otworzyć pełną listę kanałów.",
        nl="Toont actieve openbare kanalen waaraan je nog niet deelneemt wanneer de server kamers kan voorstellen. Klik op [+] om een suggestie te openen, of op \"Alle kanalen doorbladeren...\" om de volledige kanaallijst te openen.",
        ru="Показывает активные публичные каналы, к которым вы еще не присоединились, если сервер может предложить комнаты. Нажмите [+], чтобы присоединиться к предложению, или \"Просмотр всех каналов...\", чтобы открыть полный список каналов.",
        zh_hant="當伺服器有可建議的房間時，顯示尚未加入的活躍公開頻道。點擊 [+] 加入建議，或點擊「瀏覽所有頻道...」開啟完整頻道清單對話框。",
    ),
}

for source, translations in PO_CHAT_SIDEBAR_OVERRIDES.items():
    PO_OVERRIDES.setdefault(source, {}).update(translations)

PO_SHORT_HELP_LABEL_OVERRIDES = {
    "Channels Tab": t(
        "Kanal-Tab",
        "Pestaña Canales",
        "Onglet Canaux",
        "Tab Kanal",
        "チャンネルタブ",
        "频道标签",
        pt_BR="Aba Canais",
        pt_PT="Separador Canais",
        it="Scheda Canali",
        pl="Karta kanałów",
        nl="Kanalen-tab",
        ru="Вкладка каналов",
        zh_hant="頻道分頁",
    ),
    "Choose": t(
        "Auswählen",
        "Elegir",
        "Choisir",
        "Pilih",
        "選択",
        "选择",
        pt_BR="Escolher",
        pt_PT="Escolher",
        it="Scegli",
        pl="Wybierz",
        nl="Kiezen",
        ru="Выбрать",
        zh_hant="選擇",
    ),
    "Copy Feedback": t(
        "Kopierfeedback",
        "Confirmación de copia",
        "Retour de copie",
        "Umpan balik salin",
        "コピー確認",
        "复制反馈",
        pt_BR="Feedback de cópia",
        pt_PT="Feedback de cópia",
        it="Feedback di copia",
        pl="Potwierdzenie kopiowania",
        nl="Kopieerfeedback",
        ru="Подтверждение копирования",
        zh_hant="複製回饋",
    ),
    "Enter": t(
        "Eingabe",
        "Entrar",
        "Entrée",
        "Enter",
        "Enter",
        "回车",
        pt_BR="Enter",
        pt_PT="Enter",
        it="Invio",
        pl="Enter",
        nl="Enter",
        ru="Enter",
        zh_hant="Enter",
    ),
    "Every": t(
        "Alle",
        "Cada",
        "Chaque",
        "Setiap",
        "毎",
        "每",
        pt_BR="Cada",
        pt_PT="Cada",
        it="Ogni",
        pl="Każde",
        nl="Elke",
        ru="Каждый",
        zh_hant="每",
    ),
    "Go to": t(
        "Gehe zu",
        "Ir a",
        "Aller à",
        "Buka",
        "移動",
        "转到",
        pt_BR="Ir para",
        pt_PT="Ir para",
        it="Vai a",
        pl="Przejdź do",
        nl="Ga naar",
        ru="Перейти к",
        zh_hant="前往",
    ),
    "Kick": t(
        "Kick",
        "Expulsar",
        "Expulser",
        "Kick",
        "Kick",
        "踢出",
        pt_BR="Expulsar",
        pt_PT="Expulsar",
        it="Espelli",
        pl="Wyrzuć",
        nl="Kick",
        ru="Kick",
        zh_hant="踢出",
    ),
    "Limit": t(
        "Limit",
        "Límite",
        "Limite",
        "Batas",
        "制限",
        "限制",
        pt_BR="Limite",
        pt_PT="Limite",
        it="Limite",
        pl="Limit",
        nl="Limiet",
        ru="Лимит",
        zh_hant="限制",
    ),
    "Nicklist": t(
        "Nickliste",
        "Lista de nicks",
        "Liste des nicks",
        "Daftar nick",
        "ニックリスト",
        "昵称列表",
        pt_BR="Lista de nicks",
        pt_PT="Lista de nicks",
        it="Lista nick",
        pl="Lista nicków",
        nl="Nicklijst",
        ru="Список ников",
        zh_hant="暱稱列表",
    ),
    "See Also": t(
        "Siehe auch",
        "Ver también",
        "Voir aussi",
        "Lihat juga",
        "関連項目",
        "另请参阅",
        pt_BR="Veja também",
        pt_PT="Ver também",
        it="Vedi anche",
        pl="Zobacz też",
        nl="Zie ook",
        ru="См. также",
        zh_hant="另請參閱",
    ),
    "Tab Bar": t(
        "Tab-Leiste",
        "Barra de pestañas",
        "Barre d'onglets",
        "Bilah tab",
        "タブバー",
        "标签栏",
        pt_BR="Barra de abas",
        pt_PT="Barra de separadores",
        it="Barra schede",
        pl="Pasek kart",
        nl="Tabbalk",
        ru="Панель вкладок",
        zh_hant="分頁列",
    ),
    "URL Catcher": t(
        "URL-Fänger",
        "Capturador de URL",
        "Collecteur d'URL",
        "Penangkap URL",
        "URLキャッチャー",
        "URL 捕捉器",
        pt_BR="Capturador de URLs",
        pt_PT="Capturador de URLs",
        it="Cattura URL",
        pl="Przechwytywacz URL",
        nl="URL-vanger",
        ru="Перехватчик URL",
        zh_hant="URL 捕捉器",
    ),
    "URL Menu": t(
        "URL-Menü",
        "Menú de URL",
        "Menu URL",
        "Menu URL",
        "URLメニュー",
        "URL 菜单",
        pt_BR="Menu de URL",
        pt_PT="Menu de URL",
        it="Menu URL",
        pl="Menu URL",
        nl="URL-menu",
        ru="Меню URL",
        zh_hant="URL 選單",
    ),
}

for source, translations in PO_SHORT_HELP_LABEL_OVERRIDES.items():
    PO_OVERRIDES.setdefault(source, {}).update(translations)

PO_CURRENT_RESIDUAL_OVERRIDES = {
    "#%{id} %{label} | %{browser} / %{os} | active %{sessions} | last %{last_seen}": {
        "pt_BR": "#%{id} %{label} | %{browser} / %{os} | sessões ativas %{sessions} | último %{last_seen}",
        "pt_PT": "#%{id} %{label} | %{browser} / %{os} | sessões ativas %{sessions} | último %{last_seen}",
        "es": "#%{id} %{label} | %{browser} / %{os} | sesiones activas %{sessions} | último %{last_seen}",
        "fr": "#%{id} %{label} | %{browser} / %{os} | sessions actives %{sessions} | dernier %{last_seen}",
        "de": "#%{id} %{label} | %{browser} / %{os} | aktive Sitzungen %{sessions} | zuletzt %{last_seen}",
        "it": "#%{id} %{label} | %{browser} / %{os} | sessioni attive %{sessions} | ultimo %{last_seen}",
        "nl": "#%{id} %{label} | %{browser} / %{os} | actieve sessies %{sessions} | laatst %{last_seen}",
        "pl": "#%{id} %{label} | %{browser} / %{os} | aktywne sesje %{sessions} | ostatnio %{last_seen}",
        "ru": "#%{id} %{label} | %{browser} / %{os} | активные сеансы %{sessions} | последний %{last_seen}",
        "id": "#%{id} %{label} | %{browser} / %{os} | sesi aktif %{sessions} | terakhir %{last_seen}",
        "ja": "#%{id} %{label} | %{browser} / %{os} | アクティブセッション %{sessions} | 最終 %{last_seen}",
        "zh_hans": "#%{id} %{label} | %{browser} / %{os} | 活动会话 %{sessions} | 上次 %{last_seen}",
        "zh_hant": "#%{id} %{label} | %{browser} / %{os} | 作用中工作階段 %{sessions} | 上次 %{last_seen}",
    },
    "#%{id} %{label} | %{browser} / %{os} | last %{last_seen}": {
        "pt_BR": "#%{id} %{label} | %{browser} / %{os} | último %{last_seen}",
        "pt_PT": "#%{id} %{label} | %{browser} / %{os} | último %{last_seen}",
        "es": "#%{id} %{label} | %{browser} / %{os} | último %{last_seen}",
        "fr": "#%{id} %{label} | %{browser} / %{os} | dernier %{last_seen}",
        "de": "#%{id} %{label} | %{browser} / %{os} | zuletzt %{last_seen}",
        "it": "#%{id} %{label} | %{browser} / %{os} | ultimo %{last_seen}",
        "nl": "#%{id} %{label} | %{browser} / %{os} | laatst %{last_seen}",
        "pl": "#%{id} %{label} | %{browser} / %{os} | ostatnio %{last_seen}",
        "ru": "#%{id} %{label} | %{browser} / %{os} | последний %{last_seen}",
        "id": "#%{id} %{label} | %{browser} / %{os} | terakhir %{last_seen}",
        "ja": "#%{id} %{label} | %{browser} / %{os} | 最終 %{last_seen}",
        "zh_hans": "#%{id} %{label} | %{browser} / %{os} | 上次 %{last_seen}",
        "zh_hant": "#%{id} %{label} | %{browser} / %{os} | 上次 %{last_seen}",
    },
    "  %{id} | %{channel} | %{url} | last checked: %{when}": {
        "pt_BR": "  %{id} | %{channel} | %{url} | última verificação: %{when}",
        "pt_PT": "  %{id} | %{channel} | %{url} | última verificação: %{when}",
        "es": "  %{id} | %{channel} | %{url} | última comprobación: %{when}",
        "fr": "  %{id} | %{channel} | %{url} | dernière vérification : %{when}",
        "de": "  %{id} | %{channel} | %{url} | zuletzt geprüft: %{when}",
        "it": "  %{id} | %{channel} | %{url} | ultimo controllo: %{when}",
        "nl": "  %{id} | %{channel} | %{url} | laatst gecontroleerd: %{when}",
        "pl": "  %{id} | %{channel} | %{url} | ostatnio sprawdzono: %{when}",
        "ru": "  %{id} | %{channel} | %{url} | последняя проверка: %{when}",
        "id": "  %{id} | %{channel} | %{url} | terakhir diperiksa: %{when}",
        "ja": "  %{id} | %{channel} | %{url} | 最終確認: %{when}",
        "zh_hans": "  %{id} | %{channel} | %{url} | 上次检查：%{when}",
        "zh_hant": "  %{id} | %{channel} | %{url} | 上次檢查：%{when}",
    },
    "Active sessions:\n%{lines}": {
        "pt_BR": "Sessões ativas:\n%{lines}",
        "pt_PT": "Sessões ativas:\n%{lines}",
        "es": "Sesiones activas:\n%{lines}",
        "fr": "Sessions actives :\n%{lines}",
        "de": "Aktive Sitzungen:\n%{lines}",
        "it": "Sessioni attive:\n%{lines}",
        "nl": "Actieve sessies:\n%{lines}",
        "pl": "Aktywne sesje:\n%{lines}",
        "ru": "Активные сеансы:\n%{lines}",
        "id": "Sesi aktif:\n%{lines}",
        "ja": "アクティブなセッション:\n%{lines}",
        "zh_hans": "活动会话：\n%{lines}",
        "zh_hant": "作用中工作階段：\n%{lines}",
    },
    "Trusted terminals:\n%{lines}": {
        "pt_BR": "Terminais confiáveis:\n%{lines}",
        "pt_PT": "Terminais confiáveis:\n%{lines}",
        "es": "Terminales de confianza:\n%{lines}",
        "fr": "Terminaux de confiance :\n%{lines}",
        "de": "Vertrauenswürdige Terminals:\n%{lines}",
        "it": "Terminali attendibili:\n%{lines}",
        "nl": "Vertrouwde terminals:\n%{lines}",
        "pl": "Zaufane terminale:\n%{lines}",
        "ru": "Доверенные терминалы:\n%{lines}",
        "id": "Terminal tepercaya:\n%{lines}",
        "ja": "信頼済み端末:\n%{lines}",
        "zh_hans": "可信终端：\n%{lines}",
        "zh_hant": "受信任的終端：\n%{lines}",
    },
    "Refusing %{url}: %{reason}": {
        "pt_BR": "Recusando %{url}: %{reason}",
        "pt_PT": "A recusar %{url}: %{reason}",
        "es": "Rechazando %{url}: %{reason}",
        "fr": "Refus de %{url} : %{reason}",
        "de": "Verweigere %{url}: %{reason}",
        "it": "Rifiuto di %{url}: %{reason}",
        "nl": "%{url} geweigerd: %{reason}",
        "pl": "Odmowa %{url}: %{reason}",
        "ru": "Отказано для %{url}: %{reason}",
        "id": "Menolak %{url}: %{reason}",
        "ja": "%{url}を拒否: %{reason}",
        "zh_hans": "拒绝 %{url}：%{reason}",
        "zh_hant": "拒絕 %{url}：%{reason}",
    },
    "[BotService] Feed added to %{name}: %{url} → %{channel}": {
        "pt_BR": "[BotService] Feed adicionado a %{name}: %{url} → %{channel}",
        "pt_PT": "[BotService] Feed adicionado a %{name}: %{url} → %{channel}",
        "es": "[BotService] Feed añadido a %{name}: %{url} → %{channel}",
        "fr": "[BotService] Flux ajouté à %{name} : %{url} → %{channel}",
        "de": "[BotService] Feed zu %{name} hinzugefügt: %{url} → %{channel}",
        "it": "[BotService] Feed aggiunto a %{name}: %{url} → %{channel}",
        "nl": "[BotService] Feed toegevoegd aan %{name}: %{url} → %{channel}",
        "pl": "[BotService] Feed dodany do %{name}: %{url} → %{channel}",
        "ru": "[BotService] Лента добавлена в %{name}: %{url} → %{channel}",
        "id": "[BotService] Feed ditambahkan ke %{name}: %{url} → %{channel}",
        "ja": "[BotService] %{name}にフィードを追加: %{url} → %{channel}",
        "zh_hans": "[BotService] 已将订阅源添加到 %{name}: %{url} → %{channel}",
        "zh_hant": "[BotService] 已將訂閱源新增到 %{name}: %{url} → %{channel}",
    },
    "%{count} cores": {
        "pt_BR": "%{count} núcleos",
        "pt_PT": "%{count} núcleos",
        "es": "%{count} núcleos",
        "fr": "%{count} cœurs",
        "de": "%{count} Kerne",
        "it": "%{count} nuclei",
        "nl": "%{count} kernen",
        "pl": "%{count} rdzeni",
        "ru": "%{count} ядер",
        "id": "%{count} inti",
        "ja": "%{count} コア",
        "zh_hans": "%{count} 个核心",
        "zh_hant": "%{count} 個核心",
    },
    "Epoch %{epoch}": {
        "pt_BR": "Época %{epoch}",
        "pt_PT": "Época %{epoch}",
        "es": "Época %{epoch}",
        "fr": "Époque %{epoch}",
        "de": "Epoche %{epoch}",
        "it": "Epoca %{epoch}",
        "nl": "Epoche %{epoch}",
        "pl": "Epoka %{epoch}",
        "ru": "Эпоха %{epoch}",
        "id": "Era %{epoch}",
        "ja": "エポック %{epoch}",
        "zh_hans": "纪元 %{epoch}",
        "zh_hant": "紀元 %{epoch}",
    },
    "Event ID: #%{id}": {
        "pt_BR": "ID do evento: #%{id}",
        "pt_PT": "ID do evento: #%{id}",
        "es": "ID del evento: #%{id}",
        "fr": "ID de l'événement : #%{id}",
        "de": "Ereignis-ID: #%{id}",
        "it": "ID evento: #%{id}",
        "nl": "Gebeurtenis-ID: #%{id}",
        "pl": "ID zdarzenia: #%{id}",
        "ru": "ID события: #%{id}",
        "id": "ID peristiwa: #%{id}",
        "ja": "イベントID: #%{id}",
        "zh_hans": "事件 ID：#%{id}",
        "zh_hant": "事件 ID：#%{id}",
    },
    "Session ID: #%{id}": {
        "pt_BR": "ID da sessão: #%{id}",
        "pt_PT": "ID da sessão: #%{id}",
        "es": "ID de la sesión: #%{id}",
        "fr": "ID de session : #%{id}",
        "de": "Sitzungs-ID: #%{id}",
        "it": "ID sessione: #%{id}",
        "nl": "Sessie-ID: #%{id}",
        "pl": "ID sesji: #%{id}",
        "ru": "ID сеанса: #%{id}",
        "id": "ID sesi: #%{id}",
        "ja": "セッションID: #%{id}",
        "zh_hans": "会话 ID：#%{id}",
        "zh_hant": "工作階段 ID：#%{id}",
    },
    "Terminal ID: #%{id}": {
        "pt_BR": "ID do terminal: #%{id}",
        "pt_PT": "ID do terminal: #%{id}",
        "es": "ID del terminal: #%{id}",
        "fr": "ID du terminal : #%{id}",
        "de": "Terminal-ID: #%{id}",
        "it": "ID terminale: #%{id}",
        "nl": "Terminal-ID: #%{id}",
        "pl": "ID terminala: #%{id}",
        "ru": "ID терминала: #%{id}",
        "id": "ID terminal: #%{id}",
        "ja": "端末ID: #%{id}",
        "zh_hans": "终端 ID：#%{id}",
        "zh_hant": "終端 ID：#%{id}",
    },
}

for source, translations in PO_CURRENT_RESIDUAL_OVERRIDES.items():
    PO_OVERRIDES.setdefault(source, {}).update(translations)

JS_OVERRIDES = {
    "%{0}  Wv:%{1}": {
    },
    "FROSTBITE  %{0}": t(
        "ERFRIERUNG  %{0}",
        "CONGELACIÓN  %{0}",
        "ENGELURE  %{0}",
        "RADANG DINGIN  %{0}",
        "凍傷  %{0}",
        "冻伤  %{0}",
        pt_BR="CONGELAMENTO  %{0}",
    ),
    "%{0} WINS!": t(
        "%{0} GEWINNT!",
        "¡%{0} GANA!",
        "%{0} GAGNE !",
        "%{0} MENANG!",
        "%{0} の勝利！",
        "%{0} 获胜！",
        pt_BR="%{0} VENCE!",
        pt_PT="%{0} VENCE!",
        ru="%{0} побеждает!",
        zh_hant="%{0} 獲勝！",
    ),
    "Day %{0}/%{1}": t(
        "Tag %{0}/%{1}",
        "Día %{0}/%{1}",
        "Jour %{0}/%{1}",
        "Hari %{0}/%{1}",
        "%{0}/%{1}日目",
        "第 %{0}/%{1} 天",
        ru="День %{0}/%{1}",
    ),
    "Day %{0} Complete": t(
        "Tag %{0} abgeschlossen",
        "Día %{0} completo",
        "Jour %{0} terminé",
        "Hari %{0} selesai",
        "%{0}日目完了",
        "第 %{0} 天完成",
        ru="День %{0} завершен",
    ),
    "END OF PERIOD %{0}": t(
        "ENDE VON PERIODE %{0}",
        "FIN DEL PERÍODO %{0}",
        "FIN DE LA PÉRIODE %{0}",
        "AKHIR PERIODE %{0}",
        "ピリオド %{0} 終了",
        "第 %{0} 节结束",
        ru="КОНЕЦ ПЕРИОДА %{0}",
    ),
    "FIRST TO %{0}": {
    },
    "P1 WINS ROUND": {
        "pt_PT": "P1 VENCE A RONDA",
    },
    "P1 WINS!": {
        "pt_PT": "P1 VENCE!",
    },
    "P2 WINS ROUND": {
        "pt_PT": "P2 VENCE A RONDA",
    },
    "P2 WINS!": {
        "pt_PT": "P2 VENCE!",
    },
    "ROUND %{0}": t(
        "RUNDE %{0}",
        "RONDA %{0}",
        "MANCHE %{0}",
        "RONDE %{0}",
        "ラウンド %{0}",
        "第 %{0} 回合",
        ru="РАУНД %{0}",
        pt_PT="RONDA %{0}",
        zh_hant="第 %{0} 回合",
    ),
    "ROUND %{0} COMPLETE": t(
        "RUNDE %{0} ABGESCHLOSSEN",
        "RONDA %{0} COMPLETA",
        "MANCHE %{0} TERMINÉE",
        "RONDE %{0} SELESAI",
        "ラウンド %{0} 完了",
        "第 %{0} 回合完成",
        ru="РАУНД %{0} ЗАВЕРШЕН",
        pt_PT="RONDA %{0} CONCLUÍDA",
    ),
    "Round %{0}": t(
        "Runde %{0}",
        "Ronda %{0}",
        "Manche %{0}",
        "Ronde %{0}",
        "ラウンド %{0}",
        "第 %{0} 回合",
        ru="Раунд %{0}",
        zh_hant="第 %{0} 回合",
    ),
    "WAVE %{0}": t(
        "WELLE %{0}",
        "OLEADA %{0}",
        "VAGUE %{0}",
        "GELOMBANG %{0}",
        "ウェーブ %{0}",
        "第 %{0} 波",
        ru="ВОЛНА %{0}",
        pt_PT="ONDA %{0}",
        zh_hant="第 %{0} 波",
    ),
    "WAVE %{0} CLEARED": t(
        "WELLE %{0} GESCHAFFT",
        "OLEADA %{0} SUPERADA",
        "VAGUE %{0} TERMINÉE",
        "GELOMBANG %{0} SELESAI",
        "ウェーブ %{0} クリア",
        "第 %{0} 波已清除",
        ru="ВОЛНА %{0} ПРОЙДЕНА",
        zh_hant="第 %{0} 波已清除",
    ),
    "P%{0} SCORES!": t(
        "P%{0} PUNKTET!",
        "¡P%{0} ANOTA!",
        "P%{0} MARQUE !",
        "P%{0} MENCETAK SKOR!",
        "P%{0} 得点！",
        "P%{0} 得分！",
        ru="И%{0} набирает очки!",
        pt_PT="P%{0} MARCA!",
    ),
    "PLAYER %{0} SCORES!": t(
        "SPIELER %{0} PUNKTET!",
        "¡JUGADOR %{0} ANOTA!",
        "JOUEUR %{0} MARQUE !",
        "PEMAIN %{0} MENCETAK SKOR!",
        "プレイヤー %{0} 得点！",
        "玩家 %{0} 得分！",
        ru="ИГРОК %{0} НАБИРАЕТ ОЧКИ!",
        pt_PT="JOGADOR %{0} MARCA!",
        zh_hant="玩家 %{0} 得分！",
    ),
    "PLAYER %{0} WINS": t(
        "SPIELER %{0} GEWINNT",
        "JUGADOR %{0} GANA",
        "JOUEUR %{0} GAGNE",
        "PEMAIN %{0} MENANG",
        "プレイヤー %{0} の勝利",
        "玩家 %{0} 获胜",
        ru="ИГРОК %{0} ПОБЕЖДАЕТ",
        pt_PT="JOGADOR %{0} VENCE",
    ),
    "PLAYER %{0} WINS!": t(
        "SPIELER %{0} GEWINNT!",
        "¡JUGADOR %{0} GANA!",
        "JOUEUR %{0} GAGNE !",
        "PEMAIN %{0} MENANG!",
        "プレイヤー %{0} の勝利！",
        "玩家 %{0} 获胜！",
        ru="ИГРОК %{0} ПОБЕЖДАЕТ!",
        pt_PT="JOGADOR %{0} VENCE!",
        zh_hant="玩家 %{0} 獲勝！",
    ),
    "PLAYER %{0} WINS THE ROUND!": t(
        "SPIELER %{0} GEWINNT DIE RUNDE!",
        "¡JUGADOR %{0} GANA LA RONDA!",
        "JOUEUR %{0} GAGNE LA MANCHE !",
        "PEMAIN %{0} MEMENANGI RONDE!",
        "プレイヤー %{0} がラウンド勝利！",
        "玩家 %{0} 赢得本回合！",
        ru="ИГРОК %{0} ВЫИГРЫВАЕТ РАУНД!",
        pt_PT="JOGADOR %{0} VENCE A RONDA!",
    ),
    "ROUNDS: %{0} - %{1}": t(
        "RUNDEN: %{0} - %{1}",
        "RONDAS: %{0} - %{1}",
        "MANCHES : %{0} - %{1}",
        "RONDE: %{0} - %{1}",
        "ラウンド: %{0} - %{1}",
        "回合：%{0} - %{1}",
        ru="РАУНДЫ: %{0} - %{1}",
        pt_PT="RONDAS: %{0} - %{1}",
        zh_hant="回合：%{0} - %{1}",
    ),
    "WAITING FOR OPPONENT%{0}": t(
        "WARTE AUF GEGNER%{0}",
        "ESPERANDO AL OPONENTE%{0}",
        "EN ATTENTE DE L'ADVERSAIRE%{0}",
        "MENUNGGU LAWAN%{0}",
        "対戦相手を待機中%{0}",
        "正在等待对手%{0}",
        ru="ОЖИДАНИЕ СОПЕРНИКА%{0}",
    ),
    "WAITING FOR PARTNER%{0}": t(
        "WARTE AUF PARTNER%{0}",
        "ESPERANDO AL COMPAÑERO%{0}",
        "EN ATTENTE DU PARTENAIRE%{0}",
        "MENUNGGU PARTNER%{0}",
        "パートナーを待機中%{0}",
        "正在等待伙伴%{0}",
        ru="ОЖИДАНИЕ ПАРТНЕРА%{0}",
    ),
    "Blocked file type: %{0}": {
        "ru": "Заблокированный тип файла: %{0}",
    },
    "Error accessing media: %{0}": {
        "ru": "Ошибка доступа к медиа: %{0}",
    },
    "File exceeds the %{0} MB limit (%{1})": {
        "ru": "Файл превышает лимит %{0} МБ (%{1})",
    },
    "First to %{0}": {
        "ru": "Первый до %{0}",
    },
    "Reconnecting in %{0}s...": {
        "pt_PT": "A religar em %{0}s...",
        "zh_hant": "%{0}s 後重新連線...",
    },
    "Reconnection attempt %{0} of %{1}": {
        "ru": "Попытка переподключения %{0} из %{1}",
    },
    "Role: %{0}": {
    },
    "Score: %{0} - %{1}": {
    },
    "Waiting for opponent%{0}": {
        "ru": "Ожидание соперника%{0}",
        "zh_hant": "正在等待對手%{0}",
    },
    "PLAYER 1 WINS!": {
        "pt_PT": "JOGADOR 1 VENCE!",
    },
    "PLAYER 2 WINS!": {
        "pt_PT": "JOGADOR 2 VENCE!",
    },
    "ROUND DRAW!": {
        "pt_PT": "RONDA EMPATADA!",
    },
    "ROUND OVER": {
        "pt_PT": "RONDA TERMINADA",
    },
    "WAITING FOR OPPONENT": {
        "pt_PT": "À ESPERA DO OPONENTE",
    },
    "WAITING FOR OPPONENT%{0}": {
        "pt_PT": "À ESPERA DO OPONENTE%{0}",
    },
    "WAITING FOR OPPONENT...": {
        "pt_PT": "À espera do oponente...",
    },
    "WAITING FOR PARTNER%{0}": {
        "pt_PT": "À ESPERA DO PARCEIRO%{0}",
    },
    "WAVE %{0} CLEARED": {
        "pt_PT": "ONDA %{0} CONCLUÍDA",
    },
    "⚠️ Disconnected — Reconnecting...": {
        "pt_PT": "⚠️ Desligado — A religar...",
    },
    "Rounds: %{0} - %{1}  |  Score: %{2} - %{3}": {
        "ru": "Раунды: %{0} - %{1}  |  Счет: %{2} - %{3}",
        "pt_PT": "Rondas: %{0} - %{1}  |  Pontuação: %{2} - %{3}",
    },
    "P1: %{0} pieces": t(
        "P1: %{0} Teile",
        "P1: %{0} piezas",
        "P1 : %{0} pièces",
        "P1: %{0} bidak",
        "P1: %{0} 個",
        "P1：%{0} 个棋子",
    ),
    "P2: %{0} pieces": t(
        "P2: %{0} Teile",
        "P2: %{0} piezas",
        "P2 : %{0} pièces",
        "P2: %{0} bidak",
        "P2: %{0} 個",
        "P2：%{0} 个棋子",
    ),
}

JS_WAVE3_OVERRIDES = {
    "%{0}  Wv:%{1}": {
        "it": "%{0}  Ond:%{1}",
        "pl": "%{0}  Fala:%{1}",
    },
    "%{0} WINS!": {
        "it": "%{0} VINCE!",
        "pl": "%{0} WYGRYWA!",
        "nl": "%{0} WINT!",
    },
    "Blocked file type: %{0}": {
        "it": "Tipo di file bloccato: %{0}",
        "pl": "Zablokowany typ pliku: %{0}",
    },
    "Day %{0} Complete": {
        "it": "Giorno %{0} completato",
        "pl": "Dzień %{0} ukończony",
    },
    "Day %{0}/%{1}": {
        "it": "Giorno %{0}/%{1}",
        "pl": "Dzień %{0}/%{1}",
    },
    "END OF PERIOD %{0}": {
        "it": "FINE PERIODO %{0}",
        "pl": "KONIEC OKRESU %{0}",
    },
    "Error accessing media: %{0}": {
        "it": "Errore di accesso ai media: %{0}",
        "pl": "Błąd dostępu do mediów: %{0}",
    },
    "FIRST TO %{0}": {
        "it": "PRIMO A %{0}",
        "pl": "PIERWSZY DO %{0}",
    },
    "FROSTBITE  %{0}": {
        "it": "ASSIDERAMENTO  %{0}",
        "pl": "ODMROŻENIE  %{0}",
    },
    "File exceeds the %{0} MB limit (%{1})": {
        "it": "Il file supera il limite di %{0} MB (%{1})",
        "pl": "Plik przekracza limit %{0} MB (%{1})",
    },
    "First to %{0}": {
        "it": "Primo a %{0}",
        "pl": "Pierwszy do %{0}",
    },
    "P%{0} SCORES!": {
        "it": "P%{0} SEGNA!",
        "pl": "P%{0} ZDOBYWA PUNKT!",
        "nl": "P%{0} SCOORT!",
    },
    "PLAYER %{0} SCORES!": {
        "it": "GIOCATORE %{0} SEGNA!",
        "pl": "GRACZ %{0} ZDOBYWA PUNKT!",
        "nl": "SPELER %{0} SCOORT!",
    },
    "PLAYER %{0} WINS": {
        "it": "GIOCATORE %{0} VINCE",
        "pl": "GRACZ %{0} WYGRYWA",
        "nl": "SPELER %{0} WINT",
    },
    "PLAYER %{0} WINS THE ROUND!": {
        "it": "GIOCATORE %{0} VINCE IL TURNO!",
        "pl": "GRACZ %{0} WYGRYWA RUNDĘ!",
    },
    "PLAYER %{0} WINS!": {
        "it": "GIOCATORE %{0} VINCE!",
        "pl": "GRACZ %{0} WYGRYWA!",
        "nl": "SPELER %{0} WINT!",
    },
    "ROUND %{0}": {
        "it": "TURNO %{0}",
        "pl": "RUNDA %{0}",
    },
    "ROUND %{0} COMPLETE": {
        "it": "TURNO %{0} COMPLETATO",
        "pl": "RUNDA %{0} UKOŃCZONA",
    },
    "ROUNDS: %{0} - %{1}": {
        "it": "TURNI: %{0} - %{1}",
        "pl": "RUNDY: %{0} - %{1}",
        "nl": "RONDEN: %{0} - %{1}",
    },
    "Reconnecting in %{0}s...": {
        "it": "Riconnessione tra %{0}s...",
        "pl": "Ponowne połączenie za %{0}s...",
    },
    "Reconnection attempt %{0} of %{1}": {
        "it": "Tentativo di riconnessione %{0} di %{1}",
        "pl": "Próba ponownego połączenia %{0} z %{1}",
    },
    "Role: %{0}": {
        "it": "Ruolo: %{0}",
        "pl": "Rola: %{0}",
    },
    "Round %{0}": {
        "it": "Turno %{0}",
        "pl": "Runda %{0}",
    },
    "Rounds: %{0} - %{1}  |  Score: %{2} - %{3}": {
        "it": "Turni: %{0} - %{1}  |  Punteggio: %{2} - %{3}",
        "pl": "Rundy: %{0} - %{1}  |  Wynik: %{2} - %{3}",
    },
    "Score: %{0} - %{1}": {
        "it": "Punteggio: %{0} - %{1}",
        "pl": "Wynik: %{0} - %{1}",
        "nl": "Stand: %{0} - %{1}",
    },
    "WAITING FOR OPPONENT%{0}": {
        "it": "IN ATTESA DELL'AVVERSARIO%{0}",
        "pl": "OCZEKIWANIE NA PRZECIWNIKA%{0}",
    },
    "WAITING FOR PARTNER%{0}": {
        "it": "IN ATTESA DEL PARTNER%{0}",
        "pl": "OCZEKIWANIE NA PARTNERA%{0}",
    },
    "WAVE %{0}": {
        "it": "ONDATA %{0}",
        "pl": "FALA %{0}",
        "nl": "GOLF %{0}",
    },
    "WAVE %{0} CLEARED": {
        "it": "ONDATA %{0} COMPLETATA",
        "pl": "FALA %{0} UKOŃCZONA",
    },
    "Waiting for opponent%{0}": {
        "it": "In attesa dell'avversario%{0}",
        "pl": "Oczekiwanie na przeciwnika%{0}",
    },
}

for source, translations in JS_WAVE3_OVERRIDES.items():
    JS_OVERRIDES.setdefault(source, {}).update(translations)


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--locales",
        default=",".join(DEFAULT_LOCALES),
        help="Comma-separated locale codes to update",
    )
    parser.add_argument("paths", nargs="*", help="Optional PO glob paths")
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    locales = tuple(locale.strip() for locale in args.locales.split(",") if locale.strip())
    po_stats = apply_po_overrides(locales, args.paths)
    js_stats = apply_js_overrides(locales)
    print(
        "po_files={po_files} po_rewritten={po_rewritten} po_entries={po_entries} "
        "js_catalogs={js_catalogs} js_entries={js_entries}".format(
            **po_stats,
            **js_stats,
        )
    )
    return 0


def apply_po_overrides(locales: tuple[str, ...], paths: list[str]) -> dict[str, int]:
    files = po_files(locales, paths)
    rewritten = 0
    updated = 0

    for path in files:
        locale = locale_from_path(path)

        if locale not in locales:
            continue

        original = path.read_text(encoding="utf-8")
        rewritten_text, changed_entries = apply_po_text_overrides(original, locale)

        if changed_entries:
            path.write_text(rewritten_text, encoding="utf-8")
            rewritten += 1
            updated += changed_entries

    return {"po_files": len(files), "po_rewritten": rewritten, "po_entries": updated}


def po_files(locales: tuple[str, ...], paths: list[str]) -> list[Path]:
    if paths:
        files: list[Path] = []
        for pattern in paths:
            files.extend(Path(".").glob(pattern))
        return sorted(files)

    files = []
    for locale in locales:
        files.extend(Path(".").glob(f"apps/*/priv/gettext/{locale}/LC_MESSAGES/*.po"))
    return sorted(files)


def locale_from_path(path: Path) -> str:
    parts = path.parts
    return parts[parts.index("gettext") + 1]


def apply_po_text_overrides(text: str, locale: str) -> tuple[str, int]:
    parts = re.split(r"(\n{2,})", text)
    changed_entries = 0

    for index in range(0, len(parts), 2):
        block = parts[index]

        if "msgid " not in block or re.search(r"^#~", block, re.MULTILINE):
            continue

        entry = parse_po_block(block)

        if not entry.get("msgid"):
            continue

        rewritten, count = apply_po_block_overrides(block, entry, locale)

        if count:
            parts[index] = rewritten
            changed_entries += count

    return "".join(parts), changed_entries


def parse_po_block(block: str) -> dict:
    entry: dict = {"msgstr_plural": {}}
    current: tuple[str, int | None] | None = None

    for line in block.splitlines():
        parsed = field_line(line)

        if parsed is not None:
            field, index, value = parsed
            current = (field, index)
            set_po_value(entry, field, index, value)
            continue

        value = continuation_line(line)

        if value is not None and current is not None:
            append_po_value(entry, current[0], current[1], value)

    return entry


def field_line(line: str) -> tuple[str, int | None, str] | None:
    match = re.match(r'^(msgid_plural|msgid|msgstr)(?:\[(\d+)\])? "(.*)"$', line)

    if match is None:
        return None

    field, index, value = match.groups()
    return field, int(index) if index is not None else None, unquote(value)


def continuation_line(line: str) -> str | None:
    match = re.match(r'^"(.*)"$', line)
    return unquote(match.group(1)) if match else None


def set_po_value(entry: dict, field: str, index: int | None, value: str) -> None:
    if field == "msgstr" and index is not None:
        entry["msgstr_plural"][index] = value
    else:
        entry[field] = value


def append_po_value(entry: dict, field: str, index: int | None, value: str) -> None:
    if field == "msgstr" and index is not None:
        entry["msgstr_plural"][index] = entry["msgstr_plural"].get(index, "") + value
    else:
        entry[field] = entry.get(field, "") + value


def unquote(value: str) -> str:
    return ast.literal_eval(f'"{value}"')


def apply_po_block_overrides(block: str, entry: dict, locale: str) -> tuple[str, int]:
    changed_entries = 0

    if entry.get("msgid_plural"):
        plural_forms = entry["msgstr_plural"]

        for index in sorted(plural_forms.keys()):
            source = entry["msgid_plural"] if len(plural_forms) == 1 or index > 0 else entry["msgid"]
            translated = PO_OVERRIDES.get(source, {}).get(locale)

            if translated is None:
                continue

            ensure_placeholders(source, translated)

            if plural_forms[index] != translated:
                block = replace_msgstr(block, translated, index)
                changed_entries += 1
    else:
        translated = PO_OVERRIDES.get(entry["msgid"], {}).get(locale)

        if translated is not None:
            ensure_placeholders(entry["msgid"], translated)

            if entry.get("msgstr", "") != translated:
                block = replace_msgstr(block, translated)
                changed_entries += 1

    if changed_entries:
        block = clear_fuzzy_flag(block)

    return block, changed_entries


def replace_msgstr(block: str, translated: str, index: int | None = None) -> str:
    field = f"msgstr[{index}]" if index is not None else "msgstr"
    replacement = f"{field} {po_string(translated)}"
    lines = block.splitlines()

    for line_index, line in enumerate(lines):
        if not line.startswith(f"{field} "):
            continue

        end_index = line_index + 1

        while end_index < len(lines) and re.match(r'^"', lines[end_index]):
            end_index += 1

        lines[line_index:end_index] = [replacement]
        return "\n".join(lines)

    raise ValueError(f"could not find {field} in PO entry for {translated!r}")


def po_string(value: str) -> str:
    escaped = (
        value.replace("\\", "\\\\")
        .replace("\n", "\\n")
        .replace("\r", "\\r")
        .replace("\t", "\\t")
        .replace('"', '\\"')
    )
    return f'"{escaped}"'


def clear_fuzzy_flag(block: str) -> str:
    lines = []

    for line in block.splitlines():
        if not line.startswith("#,"):
            lines.append(line)
            continue

        flags = [flag.strip() for flag in line[2:].split(",") if flag.strip()]
        flags = [flag for flag in flags if flag != "fuzzy"]

        if flags:
            lines.append("#, " + ", ".join(flags))

    return "\n".join(lines)


def apply_js_overrides(locales: tuple[str, ...]) -> dict[str, int]:
    catalogs = read_catalogs()
    updated = 0
    updated_locales = []

    for locale in locales:
        export_name = LOCALE_EXPORTS.get(locale)

        if export_name not in catalogs:
            continue

        catalog = catalogs[export_name]

        for source, translations in JS_OVERRIDES.items():
            if source not in catalog:
                continue

            translated = translations.get(locale)

            if translated is None:
                continue

            ensure_placeholders(source, translated)

            if catalog[source] != translated:
                catalog[source] = translated
                updated += 1
                if locale not in updated_locales:
                    updated_locales.append(locale)

    if updated:
        write_catalogs(catalogs, locales=updated_locales)

    return {"js_catalogs": len(catalogs), "js_entries": updated}


def ensure_placeholders(source: str, translated: str) -> None:
    expected = placeholders(source)
    got = placeholders(translated)

    if expected != got:
        raise ValueError(
            f"placeholder mismatch for {source!r}: expected={sorted(expected)!r} got={sorted(got)!r}"
        )


def placeholders(value: str) -> set[str]:
    return set(PLACEHOLDER_RE.findall(value or ""))


if __name__ == "__main__":
    raise SystemExit(main())
