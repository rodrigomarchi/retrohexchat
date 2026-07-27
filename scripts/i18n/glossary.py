"""Curated translations for the universal UI vocabulary.

Machine translation is unreliable for one- and two-word UI labels: with no
sentence around them the model picks the conversational sense over the
interface sense. It rendered "OK" as "Está bem." in pt_BR, "No" as "Numéro"
in fr, "Done" as "Artikel" in de, and "Next" as mojibake in both Chinese
locales. No amount of re-running fixes that — button labels are a glossary,
not a translation task.

Rules encoded here:

- "OK" stays literal everywhere except Chinese, where 确定/確定 is the
  established convention. It is one of the most widely borrowed words in any
  language and reads as the confirm button in all of our locales.
- No label ends in a period. Buttons and menu items are not sentences.
- A term identical to English is fine when the language genuinely borrows it
  ("Menu" in Portuguese, "Server" in German). Those are listed explicitly so
  the intent is visible rather than looking like a missing translation.
"""

from __future__ import annotations

# Column order for every row below. Keep in sync with the tuples.
LOCALE_ORDER = (
    "pt_BR",
    "pt_PT",
    "es",
    "fr",
    "de",
    "it",
    "nl",
    "pl",
    "ru",
    "id",
    "ja",
    "zh_hans",
    "zh_hant",
)

# fmt: off
_ROWS = {
    # ── Confirmation and dismissal ────────────────────────────
    "OK":           ("OK", "OK", "OK", "OK", "OK", "OK", "OK", "OK", "OK", "OK", "OK", "确定", "確定"),
    "Cancel":       ("Cancelar", "Cancelar", "Cancelar", "Annuler", "Abbrechen", "Annulla", "Annuleren", "Anuluj", "Отмена", "Batal", "キャンセル", "取消", "取消"),
    "Yes":          ("Sim", "Sim", "Sí", "Oui", "Ja", "Sì", "Ja", "Tak", "Да", "Ya", "はい", "是", "是"),
    "No":           ("Não", "Não", "No", "Non", "Nein", "No", "Nee", "Nie", "Нет", "Tidak", "いいえ", "否", "否"),
    "Close":        ("Fechar", "Fechar", "Cerrar", "Fermer", "Schließen", "Chiudi", "Sluiten", "Zamknij", "Закрыть", "Tutup", "閉じる", "关闭", "關閉"),
    "Done":         ("Concluído", "Concluído", "Hecho", "Terminé", "Fertig", "Fatto", "Klaar", "Gotowe", "Готово", "Selesai", "完了", "完成", "完成"),
    "Apply":        ("Aplicar", "Aplicar", "Aplicar", "Appliquer", "Übernehmen", "Applica", "Toepassen", "Zastosuj", "Применить", "Terapkan", "適用", "应用", "套用"),
    "Save":         ("Salvar", "Guardar", "Guardar", "Enregistrer", "Speichern", "Salva", "Opslaan", "Zapisz", "Сохранить", "Simpan", "保存", "保存", "儲存"),
    "Retry":        ("Tentar novamente", "Repetir", "Reintentar", "Réessayer", "Wiederholen", "Riprova", "Opnieuw proberen", "Ponów", "Повторить", "Coba lagi", "再試行", "重试", "重試"),
    "Continue":     ("Continuar", "Continuar", "Continuar", "Continuer", "Fortfahren", "Continua", "Doorgaan", "Kontynuuj", "Продолжить", "Lanjutkan", "続ける", "继续", "繼續"),
    "Confirm":      ("Confirmar", "Confirmar", "Confirmar", "Confirmer", "Bestätigen", "Conferma", "Bevestigen", "Potwierdź", "Подтвердить", "Konfirmasi", "確認", "确认", "確認"),
    "Accept":       ("Aceitar", "Aceitar", "Aceptar", "Accepter", "Annehmen", "Accetta", "Accepteren", "Akceptuj", "Принять", "Terima", "承認", "接受", "接受"),
    "Decline":      ("Recusar", "Recusar", "Rechazar", "Refuser", "Ablehnen", "Rifiuta", "Weigeren", "Odrzuć", "Отклонить", "Tolak", "拒否", "拒绝", "拒絕"),

    # ── Navigation ────────────────────────────────────────────
    "Back":         ("Voltar", "Voltar", "Atrás", "Retour", "Zurück", "Indietro", "Terug", "Wstecz", "Назад", "Kembali", "戻る", "返回", "返回"),
    "Next":         ("Próximo", "Próximo", "Siguiente", "Suivant", "Weiter", "Avanti", "Volgende", "Dalej", "Далее", "Berikutnya", "次へ", "下一步", "下一步"),
    "Previous":     ("Anterior", "Anterior", "Anterior", "Précédent", "Zurück", "Precedente", "Vorige", "Poprzedni", "Назад", "Sebelumnya", "前へ", "上一步", "上一步"),
    "Open":         ("Abrir", "Abrir", "Abrir", "Ouvrir", "Öffnen", "Apri", "Openen", "Otwórz", "Открыть", "Buka", "開く", "打开", "開啟"),
    "Search":       ("Pesquisar", "Procurar", "Buscar", "Rechercher", "Suchen", "Cerca", "Zoeken", "Szukaj", "Поиск", "Cari", "検索", "搜索", "搜尋"),
    "Find":         ("Localizar", "Localizar", "Buscar", "Rechercher", "Suchen", "Trova", "Zoeken", "Znajdź", "Найти", "Temukan", "検索", "查找", "尋找"),

    # ── Editing ───────────────────────────────────────────────
    "Edit":         ("Editar", "Editar", "Editar", "Modifier", "Bearbeiten", "Modifica", "Bewerken", "Edytuj", "Изменить", "Sunting", "編集", "编辑", "編輯"),
    "Delete":       ("Excluir", "Eliminar", "Eliminar", "Supprimer", "Löschen", "Elimina", "Verwijderen", "Usuń", "Удалить", "Hapus", "削除", "删除", "刪除"),
    "Remove":       ("Remover", "Remover", "Quitar", "Retirer", "Entfernen", "Rimuovi", "Verwijderen", "Usuń", "Удалить", "Hapus", "削除", "移除", "移除"),
    "Add":          ("Adicionar", "Adicionar", "Añadir", "Ajouter", "Hinzufügen", "Aggiungi", "Toevoegen", "Dodaj", "Добавить", "Tambah", "追加", "添加", "新增"),
    "Copy":         ("Copiar", "Copiar", "Copiar", "Copier", "Kopieren", "Copia", "Kopiëren", "Kopiuj", "Копировать", "Salin", "コピー", "复制", "複製"),
    "Paste":        ("Colar", "Colar", "Pegar", "Coller", "Einfügen", "Incolla", "Plakken", "Wklej", "Вставить", "Tempel", "貼り付け", "粘贴", "貼上"),
    "Cut":          ("Recortar", "Cortar", "Cortar", "Couper", "Ausschneiden", "Taglia", "Knippen", "Wytnij", "Вырезать", "Potong", "切り取り", "剪切", "剪下"),
    "Rename":       ("Renomear", "Renomear", "Cambiar nombre", "Renommer", "Umbenennen", "Rinomina", "Naam wijzigen", "Zmień nazwę", "Переименовать", "Ganti nama", "名前を変更", "重命名", "重新命名"),
    "Clear":        ("Limpar", "Limpar", "Borrar", "Effacer", "Löschen", "Cancella", "Wissen", "Wyczyść", "Очистить", "Bersihkan", "クリア", "清除", "清除"),
    "Reset":        ("Redefinir", "Repor", "Restablecer", "Réinitialiser", "Zurücksetzen", "Reimposta", "Herstellen", "Resetuj", "Сбросить", "Atur ulang", "リセット", "重置", "重設"),
    "Refresh":      ("Atualizar", "Atualizar", "Actualizar", "Actualiser", "Aktualisieren", "Aggiorna", "Vernieuwen", "Odśwież", "Обновить", "Segarkan", "更新", "刷新", "重新整理"),

    # ── Transfer ──────────────────────────────────────────────
    "Send":         ("Enviar", "Enviar", "Enviar", "Envoyer", "Senden", "Invia", "Verzenden", "Wyślij", "Отправить", "Kirim", "送信", "发送", "傳送"),
    "Upload":       ("Enviar", "Carregar", "Subir", "Téléverser", "Hochladen", "Carica", "Uploaden", "Prześlij", "Загрузить", "Unggah", "アップロード", "上传", "上傳"),
    "Download":     ("Baixar", "Transferir", "Descargar", "Télécharger", "Herunterladen", "Scarica", "Downloaden", "Pobierz", "Скачать", "Unduh", "ダウンロード", "下载", "下載"),
    "Export":       ("Exportar", "Exportar", "Exportar", "Exporter", "Exportieren", "Esporta", "Exporteren", "Eksportuj", "Экспорт", "Ekspor", "エクスポート", "导出", "匯出"),

    # ── Application chrome ────────────────────────────────────
    "Help":         ("Ajuda", "Ajuda", "Ayuda", "Aide", "Hilfe", "Aiuto", "Help", "Pomoc", "Справка", "Bantuan", "ヘルプ", "帮助", "說明"),
    "Settings":     ("Configurações", "Definições", "Ajustes", "Paramètres", "Einstellungen", "Impostazioni", "Instellingen", "Ustawienia", "Настройки", "Pengaturan", "設定", "设置", "設定"),
    "About":        ("Sobre", "Sobre", "Acerca de", "À propos", "Über", "Informazioni", "Over", "O programie", "О программе", "Tentang", "バージョン情報", "关于", "關於"),
    "Menu":         ("Menu", "Menu", "Menú", "Menu", "Menü", "Menu", "Menu", "Menu", "Меню", "Menu", "メニュー", "菜单", "選單"),
    "File":         ("Arquivo", "Ficheiro", "Archivo", "Fichier", "Datei", "File", "Bestand", "Plik", "Файл", "Berkas", "ファイル", "文件", "檔案"),
    "View":         ("Exibir", "Ver", "Ver", "Affichage", "Ansicht", "Visualizza", "Beeld", "Widok", "Вид", "Tampilan", "表示", "视图", "檢視"),
    "Exit":         ("Sair", "Sair", "Salir", "Quitter", "Beenden", "Esci", "Afsluiten", "Zakończ", "Выход", "Keluar", "終了", "退出", "結束"),

    # ── Connection ────────────────────────────────────────────
    "Connect":      ("Conectar", "Ligar", "Conectar", "Se connecter", "Verbinden", "Connetti", "Verbinden", "Połącz", "Подключиться", "Hubungkan", "接続", "连接", "連線"),
    "Disconnect":   ("Desconectar", "Desligar", "Desconectar", "Se déconnecter", "Trennen", "Disconnetti", "Verbinding verbreken", "Rozłącz", "Отключиться", "Putuskan", "切断", "断开", "斷線"),
    "Connected":    ("Conectado", "Ligado", "Conectado", "Connecté", "Verbunden", "Connesso", "Verbonden", "Połączono", "Подключено", "Terhubung", "接続済み", "已连接", "已連線"),
    "Disconnected": ("Desconectado", "Desligado", "Desconectado", "Déconnecté", "Getrennt", "Disconnesso", "Verbinding verbroken", "Rozłączono", "Отключено", "Terputus", "切断済み", "已断开", "已斷線"),
    "Connecting":   ("Conectando", "A ligar", "Conectando", "Connexion", "Verbindung wird hergestellt", "Connessione", "Verbinden", "Łączenie", "Подключение", "Menghubungkan", "接続中", "连接中", "連線中"),
    "Reconnecting": ("Reconectando", "A reconectar", "Reconectando", "Reconnexion", "Erneut verbinden", "Riconnessione", "Opnieuw verbinden", "Ponowne łączenie", "Переподключение", "Menghubungkan ulang", "再接続中", "重新连接中", "重新連線中"),

    # ── Status ────────────────────────────────────────────────
    "Ready":        ("Pronto", "Pronto", "Listo", "Prêt", "Bereit", "Pronto", "Gereed", "Gotowy", "Готово", "Siap", "準備完了", "就绪", "就緒"),
    "Away":         ("Ausente", "Ausente", "Ausente", "Absent", "Abwesend", "Assente", "Afwezig", "Nieobecny", "Отошёл", "Tidak di tempat", "離席中", "离开", "離開"),
    "Idle":         ("Inativo", "Inativo", "Inactivo", "Inactif", "Inaktiv", "Inattivo", "Inactief", "Bezczynny", "Неактивен", "Diam", "アイドル", "空闲", "閒置"),
    "Online":       ("Online", "Online", "En línea", "En ligne", "Online", "Online", "Online", "Online", "В сети", "Daring", "オンライン", "在线", "線上"),
    "Offline":      ("Offline", "Offline", "Sin conexión", "Hors ligne", "Offline", "Offline", "Offline", "Offline", "Не в сети", "Luring", "オフライン", "离线", "離線"),
    "Loading":      ("Carregando", "A carregar", "Cargando", "Chargement", "Wird geladen", "Caricamento", "Laden", "Ładowanie", "Загрузка", "Memuat", "読み込み中", "加载中", "載入中"),
    "Error":        ("Erro", "Erro", "Error", "Erreur", "Fehler", "Errore", "Fout", "Błąd", "Ошибка", "Kesalahan", "エラー", "错误", "錯誤"),
    "Warning":      ("Aviso", "Aviso", "Advertencia", "Avertissement", "Warnung", "Avviso", "Waarschuwing", "Ostrzeżenie", "Предупреждение", "Peringatan", "警告", "警告", "警告"),
    "Failed":       ("Falhou", "Falhou", "Falló", "Échec", "Fehlgeschlagen", "Non riuscito", "Mislukt", "Niepowodzenie", "Не удалось", "Gagal", "失敗", "失败", "失敗"),
    "Success":      ("Sucesso", "Sucesso", "Éxito", "Succès", "Erfolg", "Successo", "Gelukt", "Powodzenie", "Успешно", "Berhasil", "成功", "成功", "成功"),

    # ── Chat actions ──────────────────────────────────────────
    "Mute":         ("Silenciar", "Silenciar", "Silenciar", "Couper le son", "Stummschalten", "Disattiva audio", "Dempen", "Wycisz", "Отключить звук", "Bisukan", "ミュート", "静音", "靜音"),
    "Unmute":       ("Reativar som", "Reativar som", "Activar sonido", "Réactiver le son", "Stummschaltung aufheben", "Riattiva audio", "Dempen opheffen", "Wyłącz wyciszenie", "Включить звук", "Suarakan", "ミュート解除", "取消静音", "取消靜音"),
    "Join":         ("Entrar", "Entrar", "Unirse", "Rejoindre", "Beitreten", "Entra", "Deelnemen", "Dołącz", "Присоединиться", "Gabung", "参加", "加入", "加入"),
    "Leave":        ("Sair", "Sair", "Salir", "Quitter", "Verlassen", "Esci", "Verlaten", "Opuść", "Покинуть", "Keluar", "退出", "离开", "離開"),
    "Start":        ("Iniciar", "Iniciar", "Iniciar", "Démarrer", "Starten", "Avvia", "Starten", "Rozpocznij", "Начать", "Mulai", "開始", "开始", "開始"),
    "Stop":         ("Parar", "Parar", "Detener", "Arrêter", "Stoppen", "Ferma", "Stoppen", "Zatrzymaj", "Остановить", "Berhenti", "停止", "停止", "停止"),
    "Pause":        ("Pausar", "Pausar", "Pausar", "Pause", "Pause", "Pausa", "Pauzeren", "Wstrzymaj", "Пауза", "Jeda", "一時停止", "暂停", "暫停"),
    "Resume":       ("Retomar", "Retomar", "Reanudar", "Reprendre", "Fortsetzen", "Riprendi", "Hervatten", "Wznów", "Продолжить", "Lanjutkan", "再開", "继续", "繼續"),
    "Ignore":       ("Ignorar", "Ignorar", "Ignorar", "Ignorer", "Ignorieren", "Ignora", "Negeren", "Ignoruj", "Игнорировать", "Abaikan", "無視", "忽略", "忽略"),
    "Block":        ("Bloquear", "Bloquear", "Bloquear", "Bloquer", "Blockieren", "Blocca", "Blokkeren", "Zablokuj", "Заблокировать", "Blokir", "ブロック", "屏蔽", "封鎖"),

    # ── Account ───────────────────────────────────────────────
    "Login":        ("Entrar", "Entrar", "Iniciar sesión", "Connexion", "Anmelden", "Accedi", "Inloggen", "Zaloguj", "Вход", "Masuk", "ログイン", "登录", "登入"),
    "Logout":       ("Sair", "Sair", "Cerrar sesión", "Déconnexion", "Abmelden", "Esci", "Uitloggen", "Wyloguj", "Выход", "Keluar", "ログアウト", "登出", "登出"),
    "Register":     ("Registrar", "Registar", "Registrarse", "S'inscrire", "Registrieren", "Registrati", "Registreren", "Zarejestruj", "Регистрация", "Daftar", "登録", "注册", "註冊"),
    "Username":     ("Nome de usuário", "Nome de utilizador", "Nombre de usuario", "Nom d'utilisateur", "Benutzername", "Nome utente", "Gebruikersnaam", "Nazwa użytkownika", "Имя пользователя", "Nama pengguna", "ユーザー名", "用户名", "使用者名稱"),
    "Password":     ("Senha", "Palavra-passe", "Contraseña", "Mot de passe", "Passwort", "Password", "Wachtwoord", "Hasło", "Пароль", "Kata sandi", "パスワード", "密码", "密碼"),
    "Name":         ("Nome", "Nome", "Nombre", "Nom", "Name", "Nome", "Naam", "Nazwa", "Имя", "Nama", "名前", "名称", "名稱"),
    # Distinct from Help on purpose: zh_hant uses 說明 for the Help menu, so a
    # description field must not land on the same word.
    "Description":  ("Descrição", "Descrição", "Descripción", "Description", "Beschreibung", "Descrizione", "Beschrijving", "Opis", "Описание", "Deskripsi", "説明", "描述", "描述"),
    "Status":       ("Status", "Estado", "Estado", "Statut", "Status", "Stato", "Status", "Status", "Статус", "Status", "ステータス", "状态", "狀態"),
    "Server":       ("Servidor", "Servidor", "Servidor", "Serveur", "Server", "Server", "Server", "Serwer", "Сервер", "Server", "サーバー", "服务器", "伺服器"),
    "Channel":      ("Canal", "Canal", "Canal", "Canal", "Kanal", "Canale", "Kanaal", "Kanał", "Канал", "Kanal", "チャンネル", "频道", "頻道"),
}
# fmt: on


def _validate() -> None:
    from .quality import has_trailing_stop, looks_like_mojibake

    width = len(LOCALE_ORDER)

    for term, row in _ROWS.items():
        if len(row) != width:
            raise ValueError(f"glossary row {term!r} has {len(row)} values, expected {width}")

        for locale_code, value in zip(LOCALE_ORDER, row):
            if not value.strip():
                raise ValueError(f"glossary {term!r} has an empty value for {locale_code}")

            if has_trailing_stop(term, value):
                raise ValueError(f"glossary {term!r} for {locale_code} ends in a full stop: {value!r}")

            if looks_like_mojibake(value):
                raise ValueError(f"glossary {term!r} for {locale_code} looks corrupted: {value!r}")


_validate()

GLOSSARY: dict[str, dict[str, str]] = {
    term: dict(zip(LOCALE_ORDER, row)) for term, row in _ROWS.items()
}


def for_locale(locale_code: str) -> dict[str, str]:
    """Curated source -> translation pairs for one locale."""
    return {
        term: translations[locale_code]
        for term, translations in GLOSSARY.items()
        if locale_code in translations
    }


def terms() -> frozenset[str]:
    return frozenset(GLOSSARY)
