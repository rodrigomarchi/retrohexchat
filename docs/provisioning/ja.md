# RetroHexChat — Japanese Rooms — `ja`

Ten channels, twelve bots, twenty-two verified feeds. Documentation in English
for the operator; everything a user reads is in Japanese.

Room names use a `jp-` prefix rather than romaji. Romaji is not how anyone
writes Japanese — `#gijutsu` is a word no reader would type — and the client
only linkifies ASCII channel names, so the honest choice is an English topic
word with a language tag. `#nihon` is the exception because it is a name, not a
translation.

Two of Japan's biggest feeds did not survive the check: RDF 1.0 is still common
here (Asahi, Impress, Famitsu, 4Gamer) and the parser reads RSS 2.0 and Atom.
Every source below was fetched and parsed before it was written down.

## Prerequisite

Run [`en.md`](en.md) first. Paste the block below into the Admin Console in one
shot, logged in as an admin who has `/identify`-ed.

## Full script

```
# ══════════════════════════════════════════════════════════
#  RetroHexChat — セットアップ ja
#  10チャンネル · 12ボット · フィードは一件ずつ検証済み
# ══════════════════════════════════════════════════════════

# ── 1. チャンネル ────────────────────────────────────────

/join #nihon
/cs register
/topic 日本語チャンネル — どうぞお入りください。座って、話しましょう。コーヒーは店のおごりです。
/mode +tn

/join #jp-tech
/cs register
/topic テクノロジー — GIGAZINE、ITmedia、ASCII をフィードから直接。!Ken sources で一覧が出ます。
/mode +tn

/join #jp-gadgets
/cs register
/topic ガジェット — ギズモード・ジャパン、ITmedia NEWS、Mogura VR。製品、レビュー、そして VR の話。
/mode +tn

/join #jp-dev
/cs register
/topic 開発 — Publickey、Zenn、Qiita。プロジェクトのサポートはプロジェクトへ。ここは雑談です。
/mode +tn

/join #jp-games
/cs register
/topic ゲーム — AUTOMATON と電ファミニコゲーマー。実際に遊ぶなら Games メニュー、18本の名作がブラウザで動きます。
/mode +tn

/join #jp-soccer
/cs register
/topic サッカー — サッカーキングとフットボールチャンネル。順位表、移籍、いつもの議論。
/mode +tn

/join #jp-yakyu
/cs register
/topic 野球 — ベースボールチャンネル。順位、開幕から日本シリーズまで。
/mode +tn

/join #jp-science
/cs register
/topic 科学 — sorae とナゾロジー。宇宙開発と、まだ答えの出ていない話。
/mode +tn

/join #jp-money
/cs register
/topic 経済 — 東洋経済、ダイヤモンド、Business Insider Japan。見出しは推奨ではありません。
/mode +tn

/join #jp-life
/cs register
/topic 暮らし — ライフハッカー・ジャパン。道具、習慣、少しだけ楽をする方法。
/mode +tn

# ══════════════════════════════════════════════════════════
#  2. Kuma — モデレーション、全チャンネル
# ══════════════════════════════════════════════════════════
# 言語ごとにモデレーターを置きます。読めない警告は警告ではありません。
# 入退室では黙っています — 十チャンネル全部に居るので、二度挨拶すると
# 個性ではなく不具合に見えます。
/bot create Kuma Shizukesa to reigi no sekininsha
/bot set Kuma prefix !
/bot set Kuma cooldown 1000
/bot set Kuma mod_action warn
/bot set Kuma mod_spam 5
/bot set Kuma mod_flood 8
/bot set Kuma mod_warn \c04\b[Kuma]\o 落ち着いて、{nickname}さん。\c05礼儀正しく\o いきましょう。こちらは急いでいません。
/bot set Kuma greeting none
/bot set Kuma farewell none
/bot set Kuma mention_response \c04\b[Kuma]\o 見ています。\c05いつも見ています\o。行儀よくしていれば、何も起きません。

/bot addcmd Kuma rules \c04\b[Kuma]\o 短い版：\c05失礼をしないこと\o。長い版はありません。
/bot addcmd Kuma report \c04\b[Kuma]\o おかしなものを見たら \c05管理者に知らせてください\o。自動処理は私、残りは人間の仕事です。

/bot join Kuma #nihon
/bot join Kuma #jp-tech
/bot join Kuma #jp-gadgets
/bot join Kuma #jp-dev
/bot join Kuma #jp-games
/bot join Kuma #jp-soccer
/bot join Kuma #jp-yakyu
/bot join Kuma #jp-science
/bot join Kuma #jp-money
/bot join Kuma #jp-life

# ══════════════════════════════════════════════════════════
#  3. Hana — #nihon のホスト
# ══════════════════════════════════════════════════════════
# 挨拶はプライベート notice で送ります。新しく来た人はチャンネルの中で
# 案内を受け取り、他の人の履歴は汚れません。
/bot create Hana Nihongo channel no hosuto
/bot set Hana prefix !
/bot set Hana cooldown 1000
/bot set Hana dice_default 1d20
/bot set Hana greeting \c03\b[Hana]\o こんにちは、{nickname}さん！ Hana と申します。\c02!rooms\o、!ohayo、!english をどうぞ。ごゆっくり。
/bot set Hana greeting_delivery private_notice
/bot set Hana greeter_repeat_window 43200
/bot set Hana public_greeting \c03\b[Hana]\o \b{nickname}\o が入ってきました。どうぞごゆっくり。
/bot set Hana onboarding_1 \c14\b[{botname}]\o \c10/join #nihon\o で部屋に入る · \c10/msg nick\o で個人宛て · \c10/nick 名前\o でニックを変更。
/bot set Hana onboarding_2 \c14\b[{botname}]\o 部屋は上のタブに並びます。\c10/part\o で退出、\c10/help\o でコマンド一覧、\c10F1\o でマニュアル。
/bot set Hana farewell none
/bot set Hana mention_response \c03\b[Hana]\o 呼びましたか。ここにいます。\c02!rooms\o をどうぞ。

/bot addcmd Hana rooms \c03\b[Hana]\o #nihon #jp-tech #jp-gadgets #jp-dev #jp-games #jp-soccer #jp-yakyu #jp-science #jp-money #jp-life — \c02日本語の十部屋\o、どれも何かが流れています。
/bot addcmd Hana ohayo \c03\b[Hana]\o \c02おはようございます\o、{nickname}さん。コーヒーが入りました。今日が始まります。
/bot addcmd Hana english \c03\b[Hana]\o 英語の部屋もあります、{nickname}さん：\c02#lobby、#tech、#news\o など。言語はツールバーで切り替えられます。
/bot addcmd Hana namae \c03\b[Hana]\o 部屋の名前が英字なのは、\c02クライアントが ASCII しかリンクにしないから\o です、{nickname}さん。部屋の中は日本語のままで大丈夫です。

/bot join Hana #nihon

# ══════════════════════════════════════════════════════════
#  4. フィードのボット — 部屋ごとに一体
# ══════════════════════════════════════════════════════════
# 以下のアドレスはすべて、本番の fetcher で取得し、アプリのパーサーで
# 読めることを確認してから書いています。最初の取得では受け取ったページを
# 投稿して記録し、それ以降は新しいものだけが流れます。
#
# 最初の読み込みは一度にではなく分割して届きます。フラッド保護は読み手ごとの
# セッションにあり、超えた相手を自動で無視するためです。捨てるものはありません
# — 残りを抱えたフィードは一分以内に戻ってきます。

# ── Taro — #nihon ────────────────────────────────────────
# 挨拶はしません。この部屋で迎えるのは Hana です。
/bot create Taro Toban no kisha
/bot set Taro prefix !
/bot set Taro cooldown 1000
/bot set Taro rss_interval 20
/bot set Taro greeting none
/bot set Taro farewell none
/bot set Taro mention_response \c03\b[Taro]\o NHK と Yahoo!ニュースを読んでいます。\c02!sources\o で一覧が出ます。
/bot addcmd Taro sources \c03\b[Taro]\o NHK ニュースと Yahoo!ニュース、\c02二十分ごと\o に取得しています。
/bot join Taro #nihon
/bot rss add Taro https://www3.nhk.or.jp/rss/news/cat0.xml #nihon
/bot rss add Taro https://news.yahoo.co.jp/rss/topics/top-picks.xml #nihon

# ── Ken — #jp-tech ───────────────────────────────────────
/bot create Ken Gijutsu tantou no kisha
/bot set Ken prefix !
/bot set Ken cooldown 1000
/bot set Ken rss_interval 30
/bot set Ken greeting \c12\b[Ken]\o {nickname}さん、ようこそ。\c10GIGAZINE、ITmedia、ASCII\o が自動で流れます。!sources で一覧、!support は質問の前に。
/bot set Ken greeting_delivery private_notice
/bot set Ken greeter_repeat_window 43200
/bot set Ken public_greeting \c12\b[Ken]\o \b{nickname}\o が来ました。ようこそ。
/bot set Ken onboarding_1 \c14\b[{botname}]\o \c10/join #nihon\o で部屋に入る · \c10/msg nick\o で個人宛て · \c10/nick 名前\o でニックを変更。
/bot set Ken onboarding_2 \c14\b[{botname}]\o 部屋は上のタブに並びます。\c10/part\o で退出、\c10/help\o でコマンド一覧、\c10F1\o でマニュアル。
/bot set Ken farewell none
/bot set Ken mention_response \c12\b[Ken]\o 技術系のフィードが三本。\c10!sources\o で分かります。
/bot addcmd Ken sources \c12\b[Ken]\o GIGAZINE、ITmedia、ASCII.jp、\c10三十分ごと\o に取得しています。
/bot addcmd Ken support \c12\b[Ken]\o プロジェクトのサポートはそのプロジェクトへ、{nickname}さん。よく答えられるのは作っている人です。\c10ここは居酒屋\o です。
/bot join Ken #jp-tech
/bot rss add Ken https://gigazine.net/news/rss_2.0/ #jp-tech
/bot rss add Ken https://rss.itmedia.co.jp/rss/2.0/itmedia_all.xml #jp-tech
/bot rss add Ken https://ascii.jp/rss.xml #jp-tech

# ── Mio — #jp-gadgets ────────────────────────────────────
/bot create Mio Gajetto no shiyousha
/bot set Mio prefix !
/bot set Mio cooldown 1000
/bot set Mio rss_interval 45
/bot set Mio greeting \c13\b[Mio]\o {nickname}さん、どうぞ。\c11ギズモード、ITmedia NEWS、Mogura VR\o が流れています。!sources で一覧。
/bot set Mio greeting_delivery private_notice
/bot set Mio greeter_repeat_window 43200
/bot set Mio public_greeting \c13\b[Mio]\o \b{nickname}\o が到着。いらっしゃい。
/bot set Mio onboarding_1 \c14\b[{botname}]\o \c10/join #nihon\o で部屋に入る · \c10/msg nick\o で個人宛て · \c10/nick 名前\o でニックを変更。
/bot set Mio onboarding_2 \c14\b[{botname}]\o 部屋は上のタブに並びます。\c10/part\o で退出、\c10/help\o でコマンド一覧、\c10F1\o でマニュアル。
/bot set Mio farewell none
/bot set Mio mention_response \c13\b[Mio]\o 製品、レビュー、VR。\c11!sources\o で一覧が出ます。
/bot addcmd Mio sources \c13\b[Mio]\o ギズモード・ジャパン、ITmedia NEWS、Mogura VR、\c11四十五分ごと\o に取得しています。
/bot join Mio #jp-gadgets
/bot rss add Mio https://www.gizmodo.jp/index.xml #jp-gadgets
/bot rss add Mio https://rss.itmedia.co.jp/rss/2.0/news_bursts.xml #jp-gadgets
/bot rss add Mio https://www.moguravr.com/feed/ #jp-gadgets

# ── Sora — #jp-dev ───────────────────────────────────────
/bot create Sora Tanin no komitto wo yomu hito
/bot set Sora prefix !
/bot set Sora cooldown 1000
/bot set Sora rss_interval 30
/bot set Sora greeting \c06\b[Sora]\o {nickname}さん、こんにちは。\c13Publickey、Zenn、Qiita\o が自動で流れます。!sources で一覧。
/bot set Sora greeting_delivery private_notice
/bot set Sora greeter_repeat_window 43200
/bot set Sora public_greeting \c06\b[Sora]\o \b{nickname}\o が参加しました。
/bot set Sora onboarding_1 \c14\b[{botname}]\o \c10/join #nihon\o で部屋に入る · \c10/msg nick\o で個人宛て · \c10/nick 名前\o でニックを変更。
/bot set Sora onboarding_2 \c14\b[{botname}]\o 部屋は上のタブに並びます。\c10/part\o で退出、\c10/help\o でコマンド一覧、\c10F1\o でマニュアル。
/bot set Sora farewell none
/bot set Sora mention_response \c06\b[Sora]\o Publickey と Zenn と Qiita。\c13!sources\o で一覧が出ます。
/bot addcmd Sora sources \c06\b[Sora]\o Publickey、Zenn、Qiita の人気記事、\c13三十分ごと\o に取得しています。
/bot join Sora #jp-dev
/bot rss add Sora https://www.publickey1.jp/atom.xml #jp-dev
/bot rss add Sora https://zenn.dev/feed #jp-dev
/bot rss add Sora https://qiita.com/popular-items/feed #jp-dev

# ── Hiro — #jp-games ─────────────────────────────────────
/bot create Hiro Geemu sentaa no tenchou
/bot set Hiro prefix !
/bot set Hiro cooldown 1000
/bot set Hiro rss_interval 45
/bot set Hiro greeting \c12\b[Hiro]\o {nickname}さん、いらっしゃい！ \c10AUTOMATON と電ファミニコゲーマー\o が流れます。Games メニューからは18本の名作が動きます。!sources、!play。
/bot set Hiro greeting_delivery private_notice
/bot set Hiro greeter_repeat_window 43200
/bot set Hiro public_greeting \c12\b[Hiro]\o \b{nickname}\o がゲームに入りました。
/bot set Hiro onboarding_1 \c14\b[{botname}]\o \c10/join #nihon\o で部屋に入る · \c10/msg nick\o で個人宛て · \c10/nick 名前\o でニックを変更。
/bot set Hiro onboarding_2 \c14\b[{botname}]\o 部屋は上のタブに並びます。\c10/part\o で退出、\c10/help\o でコマンド一覧、\c10F1\o でマニュアル。
/bot set Hiro farewell none
/bot set Hiro mention_response \c12\b[Hiro]\o ゲームのニュースは私が運びます。\c10!play\o でここでの遊び方を説明します。
/bot addcmd Hiro sources \c12\b[Hiro]\o AUTOMATON と電ファミニコゲーマー、\c10四十五分ごと\o に取得しています。
/bot addcmd Hiro play \c12\b[Hiro]\o 上のバーの \c10Games\o メニューをどうぞ、{nickname}さん。DOOM、Quake、Wolfenstein と ScummVM の冒険6本が、ブラウザで動きます。
/bot join Hiro #jp-games
/bot rss add Hiro https://automaton-media.com/feed/ #jp-games
/bot rss add Hiro https://news.denfaminicogamer.jp/feed #jp-games

# ── Kenji — #jp-soccer ───────────────────────────────────
/bot create Kenji Sutando no kirokugakari
/bot set Kenji prefix !
/bot set Kenji cooldown 1000
/bot set Kenji rss_interval 20
/bot set Kenji greeting \c09\b[Kenji]\o {nickname}さん、どうも！ \c03サッカーキングとフットボールチャンネル\o が流れます。!sources で一覧、!team は聞かれたら。
/bot set Kenji greeting_delivery private_notice
/bot set Kenji greeter_repeat_window 43200
/bot set Kenji public_greeting \c09\b[Kenji]\o \b{nickname}\o がピッチに立ちました。
/bot set Kenji onboarding_1 \c14\b[{botname}]\o \c10/join #nihon\o で部屋に入る · \c10/msg nick\o で個人宛て · \c10/nick 名前\o でニックを変更。
/bot set Kenji onboarding_2 \c14\b[{botname}]\o 部屋は上のタブに並びます。\c10/part\o で退出、\c10/help\o でコマンド一覧、\c10F1\o でマニュアル。
/bot set Kenji farewell none
/bot set Kenji mention_response \c09\b[Kenji]\o ボールは転がっています。\c03!sources\o で読んでいるものが分かります。
/bot addcmd Kenji sources \c09\b[Kenji]\o サッカーキングとフットボールチャンネル、\c03二十分ごと\o に取得しています。
/bot addcmd Kenji team \c09\b[Kenji]\o 私の贔屓は言いません、{nickname}さん。\c03贔屓のあるボット\o は最初のダービーで部屋の半分を失います。
/bot join Kenji #jp-soccer
/bot rss add Kenji https://www.soccer-king.jp/feed #jp-soccer
/bot rss add Kenji https://www.footballchannel.jp/feed #jp-soccer

# ── Daichi — #jp-yakyu ───────────────────────────────────
/bot create Daichi Yakyuu no kirokugakari
/bot set Daichi prefix !
/bot set Daichi cooldown 1000
/bot set Daichi rss_interval 30
/bot set Daichi greeting \c11\b[Daichi]\o {nickname}さん、どうぞ。\c14ベースボールチャンネル\o が流れます。!sources で一覧。
/bot set Daichi greeting_delivery private_notice
/bot set Daichi greeter_repeat_window 43200
/bot set Daichi public_greeting \c11\b[Daichi]\o \b{nickname}\o がグラウンドに来ました。
/bot set Daichi onboarding_1 \c14\b[{botname}]\o \c10/join #nihon\o で部屋に入る · \c10/msg nick\o で個人宛て · \c10/nick 名前\o でニックを変更。
/bot set Daichi onboarding_2 \c14\b[{botname}]\o 部屋は上のタブに並びます。\c10/part\o で退出、\c10/help\o でコマンド一覧、\c10F1\o でマニュアル。
/bot set Daichi farewell none
/bot set Daichi mention_response \c11\b[Daichi]\o 野球の話はこちらへ。\c14!sources\o で一覧が出ます。
/bot addcmd Daichi sources \c11\b[Daichi]\o ベースボールチャンネル、\c14三十分ごと\o に取得しています。
/bot join Daichi #jp-yakyu
/bot rss add Daichi https://www.baseballchannel.jp/feed #jp-yakyu

# ── Nozomi — #jp-science ─────────────────────────────────
/bot create Nozomi Kansoku no kirokugakari
/bot set Nozomi prefix !
/bot set Nozomi cooldown 1000
/bot set Nozomi rss_interval 60
/bot set Nozomi greeting \c10\b[Nozomi]\o {nickname}さん、ようこそ。\c02sorae とナゾロジー\o が一時間ごとに届きます。!sources で一覧。
/bot set Nozomi greeting_delivery private_notice
/bot set Nozomi greeter_repeat_window 43200
/bot set Nozomi public_greeting \c10\b[Nozomi]\o \b{nickname}\o が来ました。ようこそ。
/bot set Nozomi onboarding_1 \c14\b[{botname}]\o \c10/join #nihon\o で部屋に入る · \c10/msg nick\o で個人宛て · \c10/nick 名前\o でニックを変更。
/bot set Nozomi onboarding_2 \c14\b[{botname}]\o 部屋は上のタブに並びます。\c10/part\o で退出、\c10/help\o でコマンド一覧、\c10F1\o でマニュアル。
/bot set Nozomi farewell none
/bot set Nozomi mention_response \c10\b[Nozomi]\o 宇宙開発と、答えの出ていない話。\c02!sources\o で一覧が出ます。
/bot addcmd Nozomi sources \c10\b[Nozomi]\o sorae とナゾロジー、\c02一時間ごと\o に取得しています。
/bot join Nozomi #jp-science
/bot rss add Nozomi https://sorae.info/feed #jp-science
/bot rss add Nozomi https://nazology.kusuguru.co.jp/feed #jp-science

# ── Akira — #jp-money ────────────────────────────────────
/bot create Akira Shijou wo miru hito
/bot set Akira prefix !
/bot set Akira cooldown 1000
/bot set Akira rss_interval 30
/bot set Akira greeting \c07\b[Akira]\o {nickname}さん、こんにちは。\c14東洋経済、ダイヤモンド、Business Insider Japan\o が流れます。!sources、!chuui。
/bot set Akira greeting_delivery private_notice
/bot set Akira greeter_repeat_window 43200
/bot set Akira public_greeting \c07\b[Akira]\o \b{nickname}\o が相場に来ました。
/bot set Akira onboarding_1 \c14\b[{botname}]\o \c10/join #nihon\o で部屋に入る · \c10/msg nick\o で個人宛て · \c10/nick 名前\o でニックを変更。
/bot set Akira onboarding_2 \c14\b[{botname}]\o 部屋は上のタブに並びます。\c10/part\o で退出、\c10/help\o でコマンド一覧、\c10F1\o でマニュアル。
/bot set Akira farewell none
/bot set Akira mention_response \c07\b[Akira]\o 経済メディアが三本。\c14!sources\o で分かります。
/bot addcmd Akira sources \c07\b[Akira]\o 東洋経済オンライン、ダイヤモンド・オンライン、Business Insider Japan、\c14三十分ごと\o に取得しています。
/bot addcmd Akira chuui \c07\b[Akira]\o 見出しは推奨ではありません、{nickname}さん。\c14私が読むのはフィード\o であって、水晶玉ではありません。
/bot join Akira #jp-money
/bot rss add Akira https://toyokeizai.net/list/feed/rss #jp-money
/bot rss add Akira https://diamond.jp/list/feed/rss/dol #jp-money
/bot rss add Akira https://www.businessinsider.jp/feed/index.xml #jp-money

# ── Yui — #jp-life ───────────────────────────────────────
/bot create Yui Kurashi no tantou
/bot set Yui prefix !
/bot set Yui cooldown 1000
/bot set Yui rss_interval 60
/bot set Yui greeting \c05\b[Yui]\o {nickname}さん、どうぞ。\c13ライフハッカー・ジャパン\o が一時間ごとに届きます。!sources で一覧。
/bot set Yui greeting_delivery private_notice
/bot set Yui greeter_repeat_window 43200
/bot set Yui public_greeting \c05\b[Yui]\o \b{nickname}\o が来ました。ゆっくりどうぞ。
/bot set Yui onboarding_1 \c14\b[{botname}]\o \c10/join #nihon\o で部屋に入る · \c10/msg nick\o で個人宛て · \c10/nick 名前\o でニックを変更。
/bot set Yui onboarding_2 \c14\b[{botname}]\o 部屋は上のタブに並びます。\c10/part\o で退出、\c10/help\o でコマンド一覧、\c10F1\o でマニュアル。
/bot set Yui farewell none
/bot set Yui mention_response \c05\b[Yui]\o 道具と習慣の話。\c13!sources\o で一覧が出ます。
/bot addcmd Yui sources \c05\b[Yui]\o ライフハッカー・ジャパン、\c13一時間ごと\o に取得しています。
/bot join Yui #jp-life
/bot rss add Yui https://www.lifehacker.jp/feed/index.xml #jp-life
```

---

## Verification

```
/bot list
/bot info Kuma
/admin channel list
```

`!Taro rss list` in `#nihon` shows what a bot actually stored — the check that
matters after a paste.

## Channel reference

| channel | host / wire bot | feeds |
|---|---|---|
| `#nihon` | **Hana**, Taro | NHK, Yahoo!ニュース |
| `#jp-tech` | **Ken** | GIGAZINE, ITmedia, ASCII.jp |
| `#jp-gadgets` | **Mio** | ギズモード・ジャパン, ITmedia NEWS, Mogura VR |
| `#jp-dev` | **Sora** | Publickey, Zenn, Qiita |
| `#jp-games` | **Hiro** | AUTOMATON, 電ファミニコゲーマー |
| `#jp-soccer` | **Kenji** | サッカーキング, フットボールチャンネル |
| `#jp-yakyu` | **Daichi** | ベースボールチャンネル |
| `#jp-science` | **Nozomi** | sorae, ナゾロジー |
| `#jp-money` | **Akira** | 東洋経済, ダイヤモンド, Business Insider Japan |
| `#jp-life` | **Yui** | ライフハッカー・ジャパン |

**Kuma** stands in all ten and greets in none of them. All channels are `+tn`.

`#anime` is deliberately absent: the English script already runs it with Anime
News Network, LiveChart, Anime Corner and MyAnimeList, and a second anime room in
Japanese would split the smallest crowd on the server rather than serve it.
