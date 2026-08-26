# RetroHexChat — Traditional Chinese Rooms — `zh_hant`

Ten channels, twelve bots, twenty-one verified feeds. Documentation in English
for the operator; everything a user reads is in Traditional Chinese.

Separate from `zh_hans` for the reason the two Portuguese scripts are separate,
only more so: not one source is shared between them. `#fanti` is the social room,
and `#hongkong` exists because Hong Kong's remaining independent newsroom writes
for a readership that Taipei's front page does not serve.

## Prerequisite

Run [`en.md`](en.md) first. Paste the block below into the Admin Console in one
shot, logged in as an admin who has `/identify`-ed.

## Full script

```
# ══════════════════════════════════════════════════════════
#  RetroHexChat — 安裝 zh_hant
#  10 個頻道 · 12 個機器人 · 訂閱來源逐條驗證
# ══════════════════════════════════════════════════════════

# ── 1. 頻道 ──────────────────────────────────────────────

/join #fanti
/cs register
/topic 正體中文頻道 — 進來坐，聊聊天。咖啡算店裡的。
/mode +tn

/join #tw-news
/cs register
/topic 新聞 — 聯合新聞網、Yahoo 奇摩、中央廣播電臺，直接來自訂閱來源。!Chunhua sources 顯示清單。
/mode +tn

/join #hongkong
/cs register
/topic 香港 — 獨立媒體在線上。另一座城市的頭條，同一種文字。
/mode +tn

/join #tw-world
/cs register
/topic 國際 — 中央社國際新聞與 BBC 中文網。世界的事，用自己的字看。
/mode +tn

/join #tw-tech
/cs register
/topic 科技 — TechNews、iThome、中央社科技、INSIDE。專案的技術支援在專案那邊；這裡是聊天。
/mode +tn

/join #tw-games
/cs register
/topic 遊戲 — 巴哈姆特 GNN 與 4Gamers。真要玩的話，打開 Games 選單：18 款經典直接在瀏覽器裡跑。
/mode +tn

/join #tw-sports
/cs register
/topic 體育 — 中央社體育與自由時報體育。戰績、轉隊，還有老掉牙的爭論。
/mode +tn

/join #tw-money
/cs register
/topic 財經 — 中央社財經與自由時報財經。標題不是投資建議。
/mode +tn

/join #tw-science
/cs register
/topic 科學 — 泛科學在線上。沒有笨問題，只有沒問出口的問題。
/mode +tn

/join #tw-life
/cs register
/topic 生活 — 中央社生活與自由時報娛樂。吃飯、看戲、身體健康。
/mode +tn

# ══════════════════════════════════════════════════════════
#  2. Baoan — 值班，所有頻道
# ══════════════════════════════════════════════════════════
# 每種語言配自己的值班：看不懂的警告不算警告。進出時不出聲 —— 它站在十個
# 頻道裡，打兩次招呼看起來像故障，不像個性。
/bot create Baoan Anjing yu limao de fuzeren
/bot set Baoan prefix !
/bot set Baoan cooldown 1000
/bot set Baoan mod_action warn
/bot set Baoan mod_spam 5
/bot set Baoan mod_flood 8
/bot set Baoan mod_warn \c04\b[Baoan]\o 慢一點，{nickname}。\c05客氣一些\o大家都舒服，我不趕時間。
/bot set Baoan greeting none
/bot set Baoan farewell none
/bot set Baoan mention_response \c04\b[Baoan]\o 我看著。\c05一直看著\o。守規矩，就什麼都不會發生。

/bot addcmd Baoan rules \c04\b[Baoan]\o 短版：\c05別當討厭鬼\o。長版沒有。
/bot addcmd Baoan report \c04\b[Baoan]\o 看到奇怪的事？\c05告訴管理員\o。自動的歸我，其餘歸人。

/bot join Baoan #fanti
/bot join Baoan #tw-news
/bot join Baoan #hongkong
/bot join Baoan #tw-world
/bot join Baoan #tw-tech
/bot join Baoan #tw-games
/bot join Baoan #tw-sports
/bot join Baoan #tw-money
/bot join Baoan #tw-science
/bot join Baoan #tw-life

# ══════════════════════════════════════════════════════════
#  3. Meiling — #fanti 的主人
# ══════════════════════════════════════════════════════════
# 歡迎詞走私訊 notice：新來的人在頻道裡拿到指引，別人的紀錄不會被洗版。
/bot create Meiling Zhengti zhongwen pindao de zhuren
/bot set Meiling prefix !
/bot set Meiling cooldown 1000
/bot set Meiling dice_default 1d20
/bot set Meiling greeting \c03\b[Meiling]\o 你好，{nickname}！我是 Meiling。\c02試試 !rooms\o、!zaoan 或 !english。隨意坐。
/bot set Meiling greeting_delivery private_notice
/bot set Meiling greeter_repeat_window 43200
/bot set Meiling public_greeting \c03\b[Meiling]\o \b{nickname}\o 剛進來。隨便坐。
/bot set Meiling onboarding_1 \c14\b[{botname}]\o \c10/join #fanti\o 進入房間 · \c10/msg nick\o 私聊 · \c10/nick 名字\o 改暱稱。
/bot set Meiling onboarding_2 \c14\b[{botname}]\o \c10/part\o 離開房間 · \c10/help\o 列出所有指令。
/bot set Meiling farewell none
/bot set Meiling mention_response \c03\b[Meiling]\o 叫我？在的。\c02試試 !rooms\o。

/bot addcmd Meiling rooms \c03\b[Meiling]\o #fanti #tw-news #hongkong #tw-world #tw-tech #tw-games #tw-sports #tw-money #tw-science #tw-life — \c02十個正體中文頻道\o，每個裡面都有東西在動。
/bot addcmd Meiling zaoan \c03\b[Meiling]\o \c02早安\o，{nickname}。咖啡沖好了，鍵盤擦乾淨了，一天開始。
/bot addcmd Meiling english \c03\b[Meiling]\o 也有英文頻道，{nickname}：\c02#lobby、#tech、#news\o 等等。語言在工具列切換。
/bot addcmd Meiling jianti \c03\b[Meiling]\o 簡體中文有自己的一套頻道，{nickname}：\c02#zhongwen\o 那邊。字不同，來源也完全不同，所以分開。

/bot join Meiling #fanti

# ══════════════════════════════════════════════════════════
#  4. 訂閱機器人 —— 每個頻道一個
# ══════════════════════════════════════════════════════════
# 下面每個網址都先用正式環境的 fetcher 抓過、用應用程式的解析器讀過，才寫
# 進來。第一次抓取會把收到的那一頁貼出來並記下；之後只貼新的。
#
# 第一次讀取分批送出，不是一次倒完：洗版保護在每個讀者自己的工作階段裡，超過
# 就自動忽略。不會丟東西 —— 還有積壓的來源會在一分鐘內回來拿剩下的。

# ── Ahsiung — #fanti ─────────────────────────────────────
# 不打招呼：這個頻道裡迎客的是 Meiling。
/bot create Ahsiung Zhiban jizhe
/bot set Ahsiung prefix !
/bot set Ahsiung cooldown 1000
/bot set Ahsiung rss_interval 20
/bot set Ahsiung greeting none
/bot set Ahsiung farewell none
/bot set Ahsiung mention_response \c03\b[Ahsiung]\o 我讀自由時報和公視新聞。\c02!sources\o 列出訂閱來源。
/bot addcmd Ahsiung sources \c03\b[Ahsiung]\o 自由時報和公視新聞網，\c02每二十分鐘\o 抓一次。
/bot join Ahsiung #fanti
/bot rss add Ahsiung https://news.ltn.com.tw/rss/all.xml #fanti
/bot rss add Ahsiung https://news.pts.org.tw/xml/newsfeed.xml #fanti

# ── Chunhua — #tw-news ───────────────────────────────────
/bot create Chunhua Xinwen zhuobian
/bot set Chunhua prefix !
/bot set Chunhua cooldown 1000
/bot set Chunhua rss_interval 20
/bot set Chunhua greeting \c02\b[Chunhua]\o 歡迎來到 #tw-news，{nickname}。\c14頭條會自己進來\o —— !sources 說明來源。
/bot set Chunhua greeting_delivery private_notice
/bot set Chunhua greeter_repeat_window 43200
/bot set Chunhua public_greeting \c02\b[Chunhua]\o \b{nickname}\o 進了編輯室。
/bot set Chunhua onboarding_1 \c14\b[{botname}]\o \c10/join #fanti\o 進入房間 · \c10/msg nick\o 私聊 · \c10/nick 名字\o 改暱稱。
/bot set Chunhua onboarding_2 \c14\b[{botname}]\o \c10/part\o 離開房間 · \c10/help\o 列出所有指令。
/bot set Chunhua farewell none
/bot set Chunhua mention_response \c02\b[Chunhua]\o 訂閱來源送什麼我貼什麼。\c14!sources\o 看清單，!diyici 看其餘。
/bot addcmd Chunhua sources \c02\b[Chunhua]\o 聯合新聞網、Yahoo 奇摩新聞和中央廣播電臺，\c14每二十分鐘\o 抓一次。
/bot addcmd Chunhua diyici \c02\b[Chunhua]\o 一個來源第一次抓取時，會把當下那一頁貼出來並記下。之後 \c14只貼新的\o。
/bot join Chunhua #tw-news
/bot rss add Chunhua https://udn.com/rssfeed/news/2/6638?ch=news #tw-news
/bot rss add Chunhua https://tw.news.yahoo.com/rss/ #tw-news
/bot rss add Chunhua https://www.rti.org.tw/rss #tw-news

# ── Ahfai — #hongkong ────────────────────────────────────
/bot create Ahfai Xianggang zhuanlan de kanshouren
/bot set Ahfai prefix !
/bot set Ahfai cooldown 1000
/bot set Ahfai rss_interval 30
/bot set Ahfai greeting \c07\b[Ahfai]\o {nickname}，歡迎。\c11香港獨立媒體\o在線上。!sources 看清單。
/bot set Ahfai greeting_delivery private_notice
/bot set Ahfai greeter_repeat_window 43200
/bot set Ahfai public_greeting \c07\b[Ahfai]\o \b{nickname}\o 到咗，歡迎。
/bot set Ahfai onboarding_1 \c14\b[{botname}]\o \c10/join #fanti\o 進入房間 · \c10/msg nick\o 私聊 · \c10/nick 名字\o 改暱稱。
/bot set Ahfai onboarding_2 \c14\b[{botname}]\o \c10/part\o 離開房間 · \c10/help\o 列出所有指令。
/bot set Ahfai farewell none
/bot set Ahfai mention_response \c07\b[Ahfai]\o 另一座城市的頭條。\c11!sources\o 看清單。
/bot addcmd Ahfai sources \c07\b[Ahfai]\o 香港獨立媒體網，\c11每半小時\o 抓一次。
/bot join Ahfai #hongkong
/bot rss add Ahfai https://www.inmediahk.net/rss.xml #hongkong

# ── Shijie — #tw-world ───────────────────────────────────
/bot create Shijie Guoji xinwen bianji
/bot set Shijie prefix !
/bot set Shijie cooldown 1000
/bot set Shijie rss_interval 30
/bot set Shijie greeting \c10\b[Shijie]\o 你好，{nickname}。\c06中央社國際新聞和 BBC 中文網\o在線上。!sources 看清單。
/bot set Shijie greeting_delivery private_notice
/bot set Shijie greeter_repeat_window 43200
/bot set Shijie public_greeting \c10\b[Shijie]\o \b{nickname}\o 來了，歡迎。
/bot set Shijie onboarding_1 \c14\b[{botname}]\o \c10/join #fanti\o 進入房間 · \c10/msg nick\o 私聊 · \c10/nick 名字\o 改暱稱。
/bot set Shijie onboarding_2 \c14\b[{botname}]\o \c10/part\o 離開房間 · \c10/help\o 列出所有指令。
/bot set Shijie farewell none
/bot set Shijie mention_response \c10\b[Shijie]\o 世界的事，用自己的字看。\c06!sources\o 列出兩個來源。
/bot addcmd Shijie sources \c10\b[Shijie]\o 中央社國際新聞和 BBC 中文網，\c06每半小時\o 抓一次。
/bot join Shijie #tw-world
/bot rss add Shijie https://feeds.feedburner.com/rsscna/intworld #tw-world
/bot rss add Shijie https://www.bbc.com/zhongwen/trad/index.xml #tw-world

# ── Keji — #tw-tech ──────────────────────────────────────
/bot create Keji Keji tiaomu de bianji
/bot set Keji prefix !
/bot set Keji cooldown 1000
/bot set Keji rss_interval 30
/bot set Keji greeting \c12\b[Keji]\o 歡迎，{nickname}。\c10TechNews、iThome、中央社科技、INSIDE\o 會自己落進來。!sources 看清單，!support 在提問之前看。
/bot set Keji greeting_delivery private_notice
/bot set Keji greeter_repeat_window 43200
/bot set Keji public_greeting \c12\b[Keji]\o \b{nickname}\o 到了，歡迎。
/bot set Keji onboarding_1 \c14\b[{botname}]\o \c10/join #fanti\o 進入房間 · \c10/msg nick\o 私聊 · \c10/nick 名字\o 改暱稱。
/bot set Keji onboarding_2 \c14\b[{botname}]\o \c10/part\o 離開房間 · \c10/help\o 列出所有指令。
/bot set Keji farewell none
/bot set Keji mention_response \c12\b[Keji]\o 四個科技來源在線上。\c10!sources\o 告訴你是哪幾個。
/bot addcmd Keji sources \c12\b[Keji]\o 科技新報、iThome、中央社科技新聞和 INSIDE，\c10每半小時\o 抓一次。
/bot addcmd Keji support \c12\b[Keji]\o 專案的技術支援在專案那邊，{nickname} —— 答得好的是維護它的人。\c10這裡是茶館\o。
/bot join Keji #tw-tech
/bot rss add Keji https://technews.tw/feed/ #tw-tech
/bot rss add Keji https://www.ithome.com.tw/rss #tw-tech
/bot rss add Keji https://feeds.feedburner.com/rsscna/technology #tw-tech
/bot rss add Keji https://www.inside.com.tw/feed/rss #tw-tech

# ── Dianwan — #tw-games ──────────────────────────────────
/bot create Dianwan Youyichang de kanchang
/bot set Dianwan prefix !
/bot set Dianwan cooldown 1000
/bot set Dianwan rss_interval 45
/bot set Dianwan greeting \c12\b[Dianwan]\o 進來吧，{nickname}！\c10巴哈姆特 GNN 和 4Gamers\o在線上，Games 選單裡有 18 款經典可以直接玩。!sources、!play。
/bot set Dianwan greeting_delivery private_notice
/bot set Dianwan greeter_repeat_window 43200
/bot set Dianwan public_greeting \c12\b[Dianwan]\o \b{nickname}\o 進入遊戲。
/bot set Dianwan onboarding_1 \c14\b[{botname}]\o \c10/join #fanti\o 進入房間 · \c10/msg nick\o 私聊 · \c10/nick 名字\o 改暱稱。
/bot set Dianwan onboarding_2 \c14\b[{botname}]\o \c10/part\o 離開房間 · \c10/help\o 列出所有指令。
/bot set Dianwan farewell none
/bot set Dianwan mention_response \c12\b[Dianwan]\o 遊戲的消息我來搬。\c10!play\o 說明怎麼在這裡直接玩。
/bot addcmd Dianwan sources \c12\b[Dianwan]\o 巴哈姆特 GNN 和 4Gamers，\c10每四十五分鐘\o 抓一次。
/bot addcmd Dianwan play \c12\b[Dianwan]\o 打開上面的 \c10Games\o 選單，{nickname}：DOOM、Quake、Wolfenstein 和六個 ScummVM 冒險，全在瀏覽器裡。
/bot join Dianwan #tw-games
/bot rss add Dianwan https://gnn.gamer.com.tw/rss.xml #tw-games
/bot rss add Dianwan https://www.4gamers.com.tw/rss/latest-news #tw-games

# ── Yundong — #tw-sports ─────────────────────────────────
/bot create Yundong Kanpai shang de jiluzhe
/bot set Yundong prefix !
/bot set Yundong cooldown 1000
/bot set Yundong rss_interval 20
/bot set Yundong greeting \c09\b[Yundong]\o {nickname}，你好！\c03中央社體育和自由時報體育\o在線上。!sources 看清單，!qiudui 你真要問再說。
/bot set Yundong greeting_delivery private_notice
/bot set Yundong greeter_repeat_window 43200
/bot set Yundong public_greeting \c09\b[Yundong]\o \b{nickname}\o 上場了。
/bot set Yundong onboarding_1 \c14\b[{botname}]\o \c10/join #fanti\o 進入房間 · \c10/msg nick\o 私聊 · \c10/nick 名字\o 改暱稱。
/bot set Yundong onboarding_2 \c14\b[{botname}]\o \c10/part\o 離開房間 · \c10/help\o 列出所有指令。
/bot set Yundong farewell none
/bot set Yundong mention_response \c09\b[Yundong]\o 球在動。\c03!sources\o 說明我讀什麼。
/bot addcmd Yundong sources \c09\b[Yundong]\o 中央社體育新聞和自由時報體育，\c03每二十分鐘\o 抓一次。
/bot addcmd Yundong qiudui \c09\b[Yundong]\o 我支持哪一隊不說，{nickname}。\c03有立場的機器人\o 第一場德比就少掉半個頻道。
/bot join Yundong #tw-sports
/bot rss add Yundong https://feeds.feedburner.com/rsscna/sport #tw-sports
/bot rss add Yundong https://news.ltn.com.tw/rss/sports.xml #tw-sports

# ── Caijing — #tw-money ──────────────────────────────────
/bot create Caijing Shichang guanchazhe
/bot set Caijing prefix !
/bot set Caijing cooldown 1000
/bot set Caijing rss_interval 30
/bot set Caijing greeting \c07\b[Caijing]\o 你好，{nickname}。\c14中央社財經和自由時報財經\o在線上 —— !sources 看清單，!tixing 在相信之前看。
/bot set Caijing greeting_delivery private_notice
/bot set Caijing greeter_repeat_window 43200
/bot set Caijing public_greeting \c07\b[Caijing]\o \b{nickname}\o 進場了。
/bot set Caijing onboarding_1 \c14\b[{botname}]\o \c10/join #fanti\o 進入房間 · \c10/msg nick\o 私聊 · \c10/nick 名字\o 改暱稱。
/bot set Caijing onboarding_2 \c14\b[{botname}]\o \c10/part\o 離開房間 · \c10/help\o 列出所有指令。
/bot set Caijing farewell none
/bot set Caijing mention_response \c14\b[Caijing]\o 兩個財經來源。\c07!sources\o 告訴你是哪兩個。
/bot addcmd Caijing sources \c14\b[Caijing]\o 中央社財經新聞和自由時報財經，\c07每半小時\o 抓一次。
/bot addcmd Caijing tixing \c14\b[Caijing]\o 標題不是建議，{nickname}。\c07我讀的是訂閱來源\o，不是水晶球。
/bot join Caijing #tw-money
/bot rss add Caijing https://feeds.feedburner.com/rsscna/finance #tw-money
/bot rss add Caijing https://news.ltn.com.tw/rss/business.xml #tw-money

# ── Kexue — #tw-science ──────────────────────────────────
/bot create Kexue Guancha jilu de kanshouren
/bot set Kexue prefix !
/bot set Kexue cooldown 1000
/bot set Kexue rss_interval 90
/bot set Kexue greeting \c11\b[Kexue]\o 歡迎，{nickname}。\c02泛科學\o在線上 —— 更新不快，所以九十分鐘抓一次。!sources。
/bot set Kexue greeting_delivery private_notice
/bot set Kexue greeter_repeat_window 43200
/bot set Kexue public_greeting \c11\b[Kexue]\o \b{nickname}\o 加入了，歡迎。
/bot set Kexue onboarding_1 \c14\b[{botname}]\o \c10/join #fanti\o 進入房間 · \c10/msg nick\o 私聊 · \c10/nick 名字\o 改暱稱。
/bot set Kexue onboarding_2 \c14\b[{botname}]\o \c10/part\o 離開房間 · \c10/help\o 列出所有指令。
/bot set Kexue farewell none
/bot set Kexue mention_response \c11\b[Kexue]\o 泛科學，沒有付費牆。\c02!sources\o 看清單。
/bot addcmd Kexue sources \c11\b[Kexue]\o 泛科學 PanSci，\c02每九十分鐘\o 抓一次。
/bot join Kexue #tw-science
/bot rss add Kexue https://pansci.asia/feed #tw-science

# ── Shenghuo — #tw-life ──────────────────────────────────
/bot create Shenghuo Shenghuo banmian de bianji
/bot set Shenghuo prefix !
/bot set Shenghuo cooldown 1000
/bot set Shenghuo rss_interval 60
/bot set Shenghuo greeting \c06\b[Shenghuo]\o 你好，{nickname}。\c13中央社生活和自由時報娛樂\o每小時送來一次。!sources 看清單。
/bot set Shenghuo greeting_delivery private_notice
/bot set Shenghuo greeter_repeat_window 43200
/bot set Shenghuo public_greeting \c06\b[Shenghuo]\o \b{nickname}\o 來了，坐。
/bot set Shenghuo onboarding_1 \c14\b[{botname}]\o \c10/join #fanti\o 進入房間 · \c10/msg nick\o 私聊 · \c10/nick 名字\o 改暱稱。
/bot set Shenghuo onboarding_2 \c14\b[{botname}]\o \c10/part\o 離開房間 · \c10/help\o 列出所有指令。
/bot set Shenghuo farewell none
/bot set Shenghuo mention_response \c06\b[Shenghuo]\o 吃飯、看戲、身體健康。\c13!sources\o 列出來源。
/bot addcmd Shenghuo sources \c06\b[Shenghuo]\o 中央社生活與健康新聞和自由時報娛樂，\c13每小時\o 抓一次。
/bot join Shenghuo #tw-life
/bot rss add Shenghuo https://feeds.feedburner.com/rsscna/lifehealth #tw-life
/bot rss add Shenghuo https://news.ltn.com.tw/rss/entertainment.xml #tw-life
```

---

## Verification

```
/bot list
/bot info Baoan
/admin channel list
```

`!Ahsiung rss list` in `#fanti` shows what a bot actually stored — the check that
matters after a paste.

## Channel reference

| channel | host / wire bot | feeds |
|---|---|---|
| `#fanti` | **Meiling**, Ahsiung | 自由時報, 公視新聞網 |
| `#tw-news` | **Chunhua** | 聯合新聞網, Yahoo 奇摩新聞, 中央廣播電臺 |
| `#hongkong` | **Ahfai** | 香港獨立媒體網 |
| `#tw-world` | **Shijie** | 中央社國際, BBC 中文網 |
| `#tw-tech` | **Keji** | 科技新報, iThome, 中央社科技, INSIDE |
| `#tw-games` | **Dianwan** | 巴哈姆特 GNN, 4Gamers |
| `#tw-sports` | **Yundong** | 中央社體育, 自由時報體育 |
| `#tw-money` | **Caijing** | 中央社財經, 自由時報財經 |
| `#tw-science` | **Kexue** | 泛科學 |
| `#tw-life` | **Shenghuo** | 中央社生活, 自由時報娛樂 |

**Baoan** stands in all ten and greets in none of them. All channels are `+tn`.
