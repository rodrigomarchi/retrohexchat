defmodule RetroHexChat.Chat.EmojiData do
  @moduledoc """
  Static emoji data organized by category with search support.

  Provides ~300 curated Unicode emojis across 8 categories for the
  emoji picker component.
  """

  use Gettext, backend: RetroHexChat.Gettext

  @type emoji :: %{char: String.t(), name: String.t(), keywords: [String.t()]}

  @categories [
    dgettext_noop("emoji", "Smileys & Emotion"),
    dgettext_noop("emoji", "People & Body"),
    dgettext_noop("emoji", "Animals & Nature"),
    dgettext_noop("emoji", "Food & Drink"),
    dgettext_noop("emoji", "Travel & Places"),
    dgettext_noop("emoji", "Activities"),
    dgettext_noop("emoji", "Objects"),
    dgettext_noop("emoji", "Symbols")
  ]

  @emojis %{
    dgettext_noop("emoji", "Smileys & Emotion") => [
      %{
        char: "\u{1F600}",
        name: dgettext_noop("emoji", "grinning face"),
        keywords: [
          dgettext_noop("emoji", "smile"),
          dgettext_noop("emoji", "happy"),
          dgettext_noop("emoji", "grin")
        ]
      },
      %{
        char: "\u{1F601}",
        name: dgettext_noop("emoji", "beaming face with smiling eyes"),
        keywords: [
          dgettext_noop("emoji", "smile"),
          dgettext_noop("emoji", "happy"),
          dgettext_noop("emoji", "grin")
        ]
      },
      %{
        char: "\u{1F602}",
        name: dgettext_noop("emoji", "face with tears of joy"),
        keywords: [
          dgettext_noop("emoji", "laugh"),
          dgettext_noop("emoji", "cry"),
          dgettext_noop("emoji", "lol")
        ]
      },
      %{
        char: "\u{1F603}",
        name: dgettext_noop("emoji", "grinning face with big eyes"),
        keywords: [dgettext_noop("emoji", "smile"), dgettext_noop("emoji", "happy")]
      },
      %{
        char: "\u{1F604}",
        name: dgettext_noop("emoji", "grinning face with smiling eyes"),
        keywords: [dgettext_noop("emoji", "smile"), dgettext_noop("emoji", "happy")]
      },
      %{
        char: "\u{1F605}",
        name: dgettext_noop("emoji", "grinning face with sweat"),
        keywords: [dgettext_noop("emoji", "smile"), dgettext_noop("emoji", "nervous")]
      },
      %{
        char: "\u{1F606}",
        name: dgettext_noop("emoji", "grinning squinting face"),
        keywords: [dgettext_noop("emoji", "laugh"), dgettext_noop("emoji", "happy")]
      },
      %{
        char: "\u{1F609}",
        name: dgettext_noop("emoji", "winking face"),
        keywords: [dgettext_noop("emoji", "wink"), dgettext_noop("emoji", "flirt")]
      },
      %{
        char: "\u{1F60A}",
        name: dgettext_noop("emoji", "smiling face with smiling eyes"),
        keywords: [dgettext_noop("emoji", "blush"), dgettext_noop("emoji", "happy")]
      },
      %{
        char: "\u{1F60B}",
        name: dgettext_noop("emoji", "face savoring food"),
        keywords: [dgettext_noop("emoji", "yummy"), dgettext_noop("emoji", "delicious")]
      },
      %{
        char: "\u{1F60C}",
        name: dgettext_noop("emoji", "relieved face"),
        keywords: [dgettext_noop("emoji", "relieved"), dgettext_noop("emoji", "relaxed")]
      },
      %{
        char: "\u{1F60D}",
        name: dgettext_noop("emoji", "smiling face with heart-eyes"),
        keywords: [dgettext_noop("emoji", "love"), dgettext_noop("emoji", "heart")]
      },
      %{
        char: "\u{1F60E}",
        name: dgettext_noop("emoji", "smiling face with sunglasses"),
        keywords: [dgettext_noop("emoji", "cool"), dgettext_noop("emoji", "sunglasses")]
      },
      %{
        char: "\u{1F60F}",
        name: dgettext_noop("emoji", "smirking face"),
        keywords: [dgettext_noop("emoji", "smirk"), dgettext_noop("emoji", "sly")]
      },
      %{
        char: "\u{1F610}",
        name: dgettext_noop("emoji", "neutral face"),
        keywords: [dgettext_noop("emoji", "neutral"), dgettext_noop("emoji", "blank")]
      },
      %{
        char: "\u{1F612}",
        name: dgettext_noop("emoji", "unamused face"),
        keywords: [dgettext_noop("emoji", "unamused"), dgettext_noop("emoji", "annoyed")]
      },
      %{
        char: "\u{1F613}",
        name: dgettext_noop("emoji", "downcast face with sweat"),
        keywords: [dgettext_noop("emoji", "cold"), dgettext_noop("emoji", "sweat")]
      },
      %{
        char: "\u{1F614}",
        name: dgettext_noop("emoji", "pensive face"),
        keywords: [dgettext_noop("emoji", "sad"), dgettext_noop("emoji", "pensive")]
      },
      %{
        char: "\u{1F616}",
        name: dgettext_noop("emoji", "confounded face"),
        keywords: [dgettext_noop("emoji", "confused"), dgettext_noop("emoji", "frustrated")]
      },
      %{
        char: "\u{1F618}",
        name: dgettext_noop("emoji", "face blowing a kiss"),
        keywords: [dgettext_noop("emoji", "kiss"), dgettext_noop("emoji", "love")]
      },
      %{
        char: "\u{1F61A}",
        name: dgettext_noop("emoji", "kissing face with closed eyes"),
        keywords: [dgettext_noop("emoji", "kiss"), dgettext_noop("emoji", "love")]
      },
      %{
        char: "\u{1F61C}",
        name: dgettext_noop("emoji", "winking face with tongue"),
        keywords: [dgettext_noop("emoji", "tongue"), dgettext_noop("emoji", "silly")]
      },
      %{
        char: "\u{1F61D}",
        name: dgettext_noop("emoji", "squinting face with tongue"),
        keywords: [dgettext_noop("emoji", "tongue"), dgettext_noop("emoji", "silly")]
      },
      %{
        char: "\u{1F61E}",
        name: dgettext_noop("emoji", "disappointed face"),
        keywords: [dgettext_noop("emoji", "sad"), dgettext_noop("emoji", "disappointed")]
      },
      %{
        char: "\u{1F620}",
        name: dgettext_noop("emoji", "angry face"),
        keywords: [dgettext_noop("emoji", "angry"), dgettext_noop("emoji", "mad")]
      },
      %{
        char: "\u{1F621}",
        name: dgettext_noop("emoji", "pouting face"),
        keywords: [dgettext_noop("emoji", "angry"), dgettext_noop("emoji", "rage")]
      },
      %{
        char: "\u{1F622}",
        name: dgettext_noop("emoji", "crying face"),
        keywords: [
          dgettext_noop("emoji", "cry"),
          dgettext_noop("emoji", "sad"),
          dgettext_noop("emoji", "tear")
        ]
      },
      %{
        char: "\u{1F623}",
        name: dgettext_noop("emoji", "persevering face"),
        keywords: [dgettext_noop("emoji", "struggle"), dgettext_noop("emoji", "frustrated")]
      },
      %{
        char: "\u{1F624}",
        name: dgettext_noop("emoji", "face with steam from nose"),
        keywords: [dgettext_noop("emoji", "triumph"), dgettext_noop("emoji", "proud")]
      },
      %{
        char: "\u{1F625}",
        name: dgettext_noop("emoji", "sad but relieved face"),
        keywords: [dgettext_noop("emoji", "sad"), dgettext_noop("emoji", "relieved")]
      },
      %{
        char: "\u{1F628}",
        name: dgettext_noop("emoji", "fearful face"),
        keywords: [dgettext_noop("emoji", "fear"), dgettext_noop("emoji", "scared")]
      },
      %{
        char: "\u{1F629}",
        name: dgettext_noop("emoji", "weary face"),
        keywords: [dgettext_noop("emoji", "weary"), dgettext_noop("emoji", "tired")]
      },
      %{
        char: "\u{1F62B}",
        name: dgettext_noop("emoji", "tired face"),
        keywords: [dgettext_noop("emoji", "tired"), dgettext_noop("emoji", "exhausted")]
      },
      %{
        char: "\u{1F62D}",
        name: dgettext_noop("emoji", "loudly crying face"),
        keywords: [
          dgettext_noop("emoji", "cry"),
          dgettext_noop("emoji", "sob"),
          dgettext_noop("emoji", "sad")
        ]
      },
      %{
        char: "\u{1F631}",
        name: dgettext_noop("emoji", "face screaming in fear"),
        keywords: [dgettext_noop("emoji", "scream"), dgettext_noop("emoji", "horror")]
      },
      %{
        char: "\u{1F633}",
        name: dgettext_noop("emoji", "flushed face"),
        keywords: [dgettext_noop("emoji", "blush"), dgettext_noop("emoji", "embarrassed")]
      },
      %{
        char: "\u{1F634}",
        name: dgettext_noop("emoji", "sleeping face"),
        keywords: [dgettext_noop("emoji", "sleep"), dgettext_noop("emoji", "zzz")]
      },
      %{
        char: "\u{1F635}",
        name: dgettext_noop("emoji", "face with crossed-out eyes"),
        keywords: [dgettext_noop("emoji", "dizzy"), dgettext_noop("emoji", "dead")]
      },
      %{
        char: "\u{1F637}",
        name: dgettext_noop("emoji", "face with medical mask"),
        keywords: [dgettext_noop("emoji", "sick"), dgettext_noop("emoji", "mask")]
      },
      %{
        char: "\u{1F642}",
        name: dgettext_noop("emoji", "slightly smiling face"),
        keywords: [dgettext_noop("emoji", "smile"), dgettext_noop("emoji", "happy")]
      },
      %{
        char: "\u{1F643}",
        name: dgettext_noop("emoji", "upside-down face"),
        keywords: [dgettext_noop("emoji", "silly"), dgettext_noop("emoji", "sarcasm")]
      },
      %{
        char: "\u{1F644}",
        name: dgettext_noop("emoji", "face with rolling eyes"),
        keywords: [dgettext_noop("emoji", "eyeroll"), dgettext_noop("emoji", "annoyed")]
      },
      %{
        char: "\u{1F910}",
        name: dgettext_noop("emoji", "zipper-mouth face"),
        keywords: [dgettext_noop("emoji", "quiet"), dgettext_noop("emoji", "secret")]
      },
      %{
        char: "\u{1F911}",
        name: dgettext_noop("emoji", "money-mouth face"),
        keywords: [dgettext_noop("emoji", "money"), dgettext_noop("emoji", "rich")]
      },
      %{
        char: "\u{1F913}",
        name: dgettext_noop("emoji", "nerd face"),
        keywords: [dgettext_noop("emoji", "nerd"), dgettext_noop("emoji", "geek")]
      },
      %{
        char: "\u{1F914}",
        name: dgettext_noop("emoji", "thinking face"),
        keywords: [dgettext_noop("emoji", "think"), dgettext_noop("emoji", "hmm")]
      },
      %{
        char: "\u{1F917}",
        name: dgettext_noop("emoji", "hugging face"),
        keywords: [dgettext_noop("emoji", "hug"), dgettext_noop("emoji", "love")]
      },
      %{
        char: "\u{1F923}",
        name: dgettext_noop("emoji", "rolling on the floor laughing"),
        keywords: [dgettext_noop("emoji", "laugh"), dgettext_noop("emoji", "rofl")]
      },
      %{
        char: "\u{1F92A}",
        name: dgettext_noop("emoji", "zany face"),
        keywords: [dgettext_noop("emoji", "crazy"), dgettext_noop("emoji", "wild")]
      },
      %{
        char: "\u{1F92B}",
        name: dgettext_noop("emoji", "shushing face"),
        keywords: [dgettext_noop("emoji", "quiet"), dgettext_noop("emoji", "shh")]
      },
      %{
        char: "\u{1F92D}",
        name: dgettext_noop("emoji", "face with hand over mouth"),
        keywords: [dgettext_noop("emoji", "oops"), dgettext_noop("emoji", "giggle")]
      },
      %{
        char: "\u{1F92E}",
        name: dgettext_noop("emoji", "face vomiting"),
        keywords: [dgettext_noop("emoji", "sick"), dgettext_noop("emoji", "puke")]
      },
      %{
        char: "\u{1F970}",
        name: dgettext_noop("emoji", "smiling face with hearts"),
        keywords: [dgettext_noop("emoji", "love"), dgettext_noop("emoji", "adore")]
      },
      %{
        char: "\u{1F973}",
        name: dgettext_noop("emoji", "partying face"),
        keywords: [dgettext_noop("emoji", "party"), dgettext_noop("emoji", "celebrate")]
      },
      %{
        char: "\u{1F974}",
        name: dgettext_noop("emoji", "woozy face"),
        keywords: [dgettext_noop("emoji", "drunk"), dgettext_noop("emoji", "dizzy")]
      },
      %{
        char: "\u{1F975}",
        name: dgettext_noop("emoji", "hot face"),
        keywords: [dgettext_noop("emoji", "hot"), dgettext_noop("emoji", "heat")]
      },
      %{
        char: "\u{1F976}",
        name: dgettext_noop("emoji", "cold face"),
        keywords: [dgettext_noop("emoji", "cold"), dgettext_noop("emoji", "freezing")]
      },
      %{
        char: "\u{2764}\u{FE0F}",
        name: dgettext_noop("emoji", "red heart"),
        keywords: [dgettext_noop("emoji", "love"), dgettext_noop("emoji", "heart")]
      },
      %{
        char: "\u{1F494}",
        name: dgettext_noop("emoji", "broken heart"),
        keywords: [dgettext_noop("emoji", "heartbreak"), dgettext_noop("emoji", "sad")]
      },
      %{
        char: "\u{1F495}",
        name: dgettext_noop("emoji", "two hearts"),
        keywords: [dgettext_noop("emoji", "love"), dgettext_noop("emoji", "hearts")]
      },
      %{
        char: "\u{1F496}",
        name: dgettext_noop("emoji", "sparkling heart"),
        keywords: [dgettext_noop("emoji", "love"), dgettext_noop("emoji", "sparkle")]
      },
      %{
        char: "\u{1F497}",
        name: dgettext_noop("emoji", "growing heart"),
        keywords: [dgettext_noop("emoji", "love"), dgettext_noop("emoji", "growing")]
      },
      %{
        char: "\u{1F498}",
        name: dgettext_noop("emoji", "heart with arrow"),
        keywords: [dgettext_noop("emoji", "love"), dgettext_noop("emoji", "cupid")]
      },
      %{
        char: "\u{1F499}",
        name: dgettext_noop("emoji", "blue heart"),
        keywords: [dgettext_noop("emoji", "love"), dgettext_noop("emoji", "blue")]
      },
      %{
        char: "\u{1F49A}",
        name: dgettext_noop("emoji", "green heart"),
        keywords: [dgettext_noop("emoji", "love"), dgettext_noop("emoji", "green")]
      },
      %{
        char: "\u{1F49B}",
        name: dgettext_noop("emoji", "yellow heart"),
        keywords: [dgettext_noop("emoji", "love"), dgettext_noop("emoji", "yellow")]
      },
      %{
        char: "\u{1F49C}",
        name: dgettext_noop("emoji", "purple heart"),
        keywords: [dgettext_noop("emoji", "love"), dgettext_noop("emoji", "purple")]
      },
      %{
        char: "\u{1F4AF}",
        name: dgettext_noop("emoji", "hundred points"),
        keywords: [
          dgettext_noop("emoji", "100"),
          dgettext_noop("emoji", "perfect"),
          dgettext_noop("emoji", "score")
        ]
      }
    ],
    dgettext_noop("emoji", "People & Body") => [
      %{
        char: "\u{1F44D}",
        name: dgettext_noop("emoji", "thumbs up"),
        keywords: [
          dgettext_noop("emoji", "yes"),
          dgettext_noop("emoji", "good"),
          dgettext_noop("emoji", "like")
        ]
      },
      %{
        char: "\u{1F44E}",
        name: dgettext_noop("emoji", "thumbs down"),
        keywords: [
          dgettext_noop("emoji", "no"),
          dgettext_noop("emoji", "bad"),
          dgettext_noop("emoji", "dislike")
        ]
      },
      %{
        char: "\u{1F44B}",
        name: dgettext_noop("emoji", "waving hand"),
        keywords: [
          dgettext_noop("emoji", "wave"),
          dgettext_noop("emoji", "hello"),
          dgettext_noop("emoji", "bye")
        ]
      },
      %{
        char: "\u{1F44F}",
        name: dgettext_noop("emoji", "clapping hands"),
        keywords: [dgettext_noop("emoji", "clap"), dgettext_noop("emoji", "applause")]
      },
      %{
        char: "\u{1F450}",
        name: dgettext_noop("emoji", "open hands"),
        keywords: [dgettext_noop("emoji", "hands"), dgettext_noop("emoji", "open")]
      },
      %{
        char: "\u{1F64C}",
        name: dgettext_noop("emoji", "raising hands"),
        keywords: [dgettext_noop("emoji", "celebrate"), dgettext_noop("emoji", "hooray")]
      },
      %{
        char: "\u{1F64F}",
        name: dgettext_noop("emoji", "folded hands"),
        keywords: [
          dgettext_noop("emoji", "pray"),
          dgettext_noop("emoji", "please"),
          dgettext_noop("emoji", "thanks")
        ]
      },
      %{
        char: "\u{1F91D}",
        name: dgettext_noop("emoji", "handshake"),
        keywords: [dgettext_noop("emoji", "agreement"), dgettext_noop("emoji", "deal")]
      },
      %{
        char: "\u{270C}\u{FE0F}",
        name: dgettext_noop("emoji", "victory hand"),
        keywords: [dgettext_noop("emoji", "peace"), dgettext_noop("emoji", "victory")]
      },
      %{
        char: "\u{1F918}",
        name: dgettext_noop("emoji", "sign of the horns"),
        keywords: [dgettext_noop("emoji", "rock"), dgettext_noop("emoji", "metal")]
      },
      %{
        char: "\u{1F919}",
        name: dgettext_noop("emoji", "call me hand"),
        keywords: [dgettext_noop("emoji", "call"), dgettext_noop("emoji", "shaka")]
      },
      %{
        char: "\u{1F91E}",
        name: dgettext_noop("emoji", "crossed fingers"),
        keywords: [dgettext_noop("emoji", "luck"), dgettext_noop("emoji", "hope")]
      },
      %{
        char: "\u{1F91F}",
        name: dgettext_noop("emoji", "love-you gesture"),
        keywords: [dgettext_noop("emoji", "love"), dgettext_noop("emoji", "ily")]
      },
      %{
        char: "\u{1F448}",
        name: dgettext_noop("emoji", "backhand index pointing left"),
        keywords: [dgettext_noop("emoji", "left"), dgettext_noop("emoji", "point")]
      },
      %{
        char: "\u{1F449}",
        name: dgettext_noop("emoji", "backhand index pointing right"),
        keywords: [dgettext_noop("emoji", "right"), dgettext_noop("emoji", "point")]
      },
      %{
        char: "\u{1F446}",
        name: dgettext_noop("emoji", "backhand index pointing up"),
        keywords: [dgettext_noop("emoji", "up"), dgettext_noop("emoji", "point")]
      },
      %{
        char: "\u{1F447}",
        name: dgettext_noop("emoji", "backhand index pointing down"),
        keywords: [dgettext_noop("emoji", "down"), dgettext_noop("emoji", "point")]
      },
      %{
        char: "\u{261D}\u{FE0F}",
        name: dgettext_noop("emoji", "index pointing up"),
        keywords: [dgettext_noop("emoji", "point"), dgettext_noop("emoji", "one")]
      },
      %{
        char: "\u{270B}",
        name: dgettext_noop("emoji", "raised hand"),
        keywords: [dgettext_noop("emoji", "stop"), dgettext_noop("emoji", "high five")]
      },
      %{
        char: "\u{1F44A}",
        name: dgettext_noop("emoji", "oncoming fist"),
        keywords: [dgettext_noop("emoji", "punch"), dgettext_noop("emoji", "fist bump")]
      },
      %{
        char: "\u{1F4AA}",
        name: dgettext_noop("emoji", "flexed biceps"),
        keywords: [dgettext_noop("emoji", "strong"), dgettext_noop("emoji", "muscle")]
      },
      %{
        char: "\u{1F596}",
        name: dgettext_noop("emoji", "vulcan salute"),
        keywords: [dgettext_noop("emoji", "spock"), dgettext_noop("emoji", "trek")]
      },
      %{
        char: "\u{1F590}\u{FE0F}",
        name: dgettext_noop("emoji", "hand with fingers splayed"),
        keywords: [dgettext_noop("emoji", "hand"), dgettext_noop("emoji", "five")]
      },
      %{
        char: "\u{1F937}",
        name: dgettext_noop("emoji", "person shrugging"),
        keywords: [dgettext_noop("emoji", "shrug"), dgettext_noop("emoji", "dunno")]
      },
      %{
        char: "\u{1F926}",
        name: dgettext_noop("emoji", "person facepalming"),
        keywords: [dgettext_noop("emoji", "facepalm"), dgettext_noop("emoji", "smh")]
      },
      %{
        char: "\u{1F645}",
        name: dgettext_noop("emoji", "person gesturing NO"),
        keywords: [dgettext_noop("emoji", "no"), dgettext_noop("emoji", "stop")]
      },
      %{
        char: "\u{1F646}",
        name: dgettext_noop("emoji", "person gesturing OK"),
        keywords: [dgettext_noop("emoji", "ok"), dgettext_noop("emoji", "yes")]
      },
      %{
        char: "\u{1F647}",
        name: dgettext_noop("emoji", "person bowing"),
        keywords: [dgettext_noop("emoji", "bow"), dgettext_noop("emoji", "respect")]
      },
      %{
        char: "\u{1F471}",
        name: dgettext_noop("emoji", "person: blond hair"),
        keywords: [dgettext_noop("emoji", "blonde"), dgettext_noop("emoji", "person")]
      },
      %{
        char: "\u{1F474}",
        name: dgettext_noop("emoji", "old man"),
        keywords: [dgettext_noop("emoji", "elder"), dgettext_noop("emoji", "grandpa")]
      },
      %{
        char: "\u{1F475}",
        name: dgettext_noop("emoji", "old woman"),
        keywords: [dgettext_noop("emoji", "elder"), dgettext_noop("emoji", "grandma")]
      },
      %{
        char: "\u{1F476}",
        name: dgettext_noop("emoji", "baby"),
        keywords: [dgettext_noop("emoji", "baby"), dgettext_noop("emoji", "infant")]
      },
      %{
        char: "\u{1F466}",
        name: dgettext_noop("emoji", "boy"),
        keywords: [dgettext_noop("emoji", "boy"), dgettext_noop("emoji", "child")]
      },
      %{
        char: "\u{1F467}",
        name: dgettext_noop("emoji", "girl"),
        keywords: [dgettext_noop("emoji", "girl"), dgettext_noop("emoji", "child")]
      },
      %{
        char: "\u{1F468}",
        name: dgettext_noop("emoji", "man"),
        keywords: [dgettext_noop("emoji", "man"), dgettext_noop("emoji", "adult")]
      },
      %{
        char: "\u{1F469}",
        name: dgettext_noop("emoji", "woman"),
        keywords: [dgettext_noop("emoji", "woman"), dgettext_noop("emoji", "adult")]
      }
    ],
    dgettext_noop("emoji", "Animals & Nature") => [
      %{
        char: "\u{1F436}",
        name: dgettext_noop("emoji", "dog face"),
        keywords: [
          dgettext_noop("emoji", "dog"),
          dgettext_noop("emoji", "pet"),
          dgettext_noop("emoji", "puppy")
        ]
      },
      %{
        char: "\u{1F431}",
        name: dgettext_noop("emoji", "cat face"),
        keywords: [
          dgettext_noop("emoji", "cat"),
          dgettext_noop("emoji", "pet"),
          dgettext_noop("emoji", "kitty")
        ]
      },
      %{
        char: "\u{1F42D}",
        name: dgettext_noop("emoji", "mouse face"),
        keywords: [dgettext_noop("emoji", "mouse"), dgettext_noop("emoji", "rodent")]
      },
      %{
        char: "\u{1F439}",
        name: dgettext_noop("emoji", "hamster"),
        keywords: [dgettext_noop("emoji", "hamster"), dgettext_noop("emoji", "pet")]
      },
      %{
        char: "\u{1F430}",
        name: dgettext_noop("emoji", "rabbit face"),
        keywords: [dgettext_noop("emoji", "rabbit"), dgettext_noop("emoji", "bunny")]
      },
      %{
        char: "\u{1F43B}",
        name: dgettext_noop("emoji", "bear"),
        keywords: [dgettext_noop("emoji", "bear"), dgettext_noop("emoji", "animal")]
      },
      %{
        char: "\u{1F43C}",
        name: dgettext_noop("emoji", "panda"),
        keywords: [dgettext_noop("emoji", "panda"), dgettext_noop("emoji", "bear")]
      },
      %{
        char: "\u{1F428}",
        name: dgettext_noop("emoji", "koala"),
        keywords: [dgettext_noop("emoji", "koala"), dgettext_noop("emoji", "animal")]
      },
      %{
        char: "\u{1F42F}",
        name: dgettext_noop("emoji", "tiger face"),
        keywords: [dgettext_noop("emoji", "tiger"), dgettext_noop("emoji", "cat")]
      },
      %{
        char: "\u{1F981}",
        name: dgettext_noop("emoji", "lion"),
        keywords: [dgettext_noop("emoji", "lion"), dgettext_noop("emoji", "king")]
      },
      %{
        char: "\u{1F42E}",
        name: dgettext_noop("emoji", "cow face"),
        keywords: [dgettext_noop("emoji", "cow"), dgettext_noop("emoji", "moo")]
      },
      %{
        char: "\u{1F437}",
        name: dgettext_noop("emoji", "pig face"),
        keywords: [dgettext_noop("emoji", "pig"), dgettext_noop("emoji", "oink")]
      },
      %{
        char: "\u{1F438}",
        name: dgettext_noop("emoji", "frog"),
        keywords: [dgettext_noop("emoji", "frog"), dgettext_noop("emoji", "toad")]
      },
      %{
        char: "\u{1F435}",
        name: dgettext_noop("emoji", "monkey face"),
        keywords: [dgettext_noop("emoji", "monkey"), dgettext_noop("emoji", "ape")]
      },
      %{
        char: "\u{1F412}",
        name: dgettext_noop("emoji", "monkey"),
        keywords: [dgettext_noop("emoji", "monkey"), dgettext_noop("emoji", "primate")]
      },
      %{
        char: "\u{1F414}",
        name: dgettext_noop("emoji", "chicken"),
        keywords: [dgettext_noop("emoji", "chicken"), dgettext_noop("emoji", "hen")]
      },
      %{
        char: "\u{1F427}",
        name: dgettext_noop("emoji", "penguin"),
        keywords: [dgettext_noop("emoji", "penguin"), dgettext_noop("emoji", "cold")]
      },
      %{
        char: "\u{1F426}",
        name: dgettext_noop("emoji", "bird"),
        keywords: [dgettext_noop("emoji", "bird"), dgettext_noop("emoji", "fly")]
      },
      %{
        char: "\u{1F40D}",
        name: dgettext_noop("emoji", "snake"),
        keywords: [dgettext_noop("emoji", "snake"), dgettext_noop("emoji", "reptile")]
      },
      %{
        char: "\u{1F422}",
        name: dgettext_noop("emoji", "turtle"),
        keywords: [dgettext_noop("emoji", "turtle"), dgettext_noop("emoji", "slow")]
      },
      %{
        char: "\u{1F41D}",
        name: dgettext_noop("emoji", "honeybee"),
        keywords: [dgettext_noop("emoji", "bee"), dgettext_noop("emoji", "honey")]
      },
      %{
        char: "\u{1F41B}",
        name: dgettext_noop("emoji", "bug"),
        keywords: [dgettext_noop("emoji", "bug"), dgettext_noop("emoji", "insect")]
      },
      %{
        char: "\u{1F40C}",
        name: dgettext_noop("emoji", "snail"),
        keywords: [dgettext_noop("emoji", "snail"), dgettext_noop("emoji", "slow")]
      },
      %{
        char: "\u{1F419}",
        name: dgettext_noop("emoji", "octopus"),
        keywords: [dgettext_noop("emoji", "octopus"), dgettext_noop("emoji", "sea")]
      },
      %{
        char: "\u{1F420}",
        name: dgettext_noop("emoji", "tropical fish"),
        keywords: [dgettext_noop("emoji", "fish"), dgettext_noop("emoji", "tropical")]
      },
      %{
        char: "\u{1F421}",
        name: dgettext_noop("emoji", "blowfish"),
        keywords: [dgettext_noop("emoji", "fish"), dgettext_noop("emoji", "puffer")]
      },
      %{
        char: "\u{1F42C}",
        name: dgettext_noop("emoji", "dolphin"),
        keywords: [dgettext_noop("emoji", "dolphin"), dgettext_noop("emoji", "sea")]
      },
      %{
        char: "\u{1F433}",
        name: dgettext_noop("emoji", "whale"),
        keywords: [dgettext_noop("emoji", "whale"), dgettext_noop("emoji", "sea")]
      },
      %{
        char: "\u{1F332}",
        name: dgettext_noop("emoji", "evergreen tree"),
        keywords: [dgettext_noop("emoji", "tree"), dgettext_noop("emoji", "nature")]
      },
      %{
        char: "\u{1F333}",
        name: dgettext_noop("emoji", "deciduous tree"),
        keywords: [dgettext_noop("emoji", "tree"), dgettext_noop("emoji", "nature")]
      },
      %{
        char: "\u{1F334}",
        name: dgettext_noop("emoji", "palm tree"),
        keywords: [dgettext_noop("emoji", "palm"), dgettext_noop("emoji", "tropical")]
      },
      %{
        char: "\u{1F335}",
        name: dgettext_noop("emoji", "cactus"),
        keywords: [dgettext_noop("emoji", "cactus"), dgettext_noop("emoji", "desert")]
      },
      %{
        char: "\u{1F337}",
        name: dgettext_noop("emoji", "tulip"),
        keywords: [dgettext_noop("emoji", "flower"), dgettext_noop("emoji", "spring")]
      },
      %{
        char: "\u{1F339}",
        name: dgettext_noop("emoji", "rose"),
        keywords: [dgettext_noop("emoji", "flower"), dgettext_noop("emoji", "love")]
      },
      %{
        char: "\u{1F33B}",
        name: dgettext_noop("emoji", "sunflower"),
        keywords: [dgettext_noop("emoji", "flower"), dgettext_noop("emoji", "sun")]
      },
      %{
        char: "\u{1F33C}",
        name: dgettext_noop("emoji", "blossom"),
        keywords: [dgettext_noop("emoji", "flower"), dgettext_noop("emoji", "bloom")]
      },
      %{
        char: "\u{1F33F}",
        name: dgettext_noop("emoji", "herb"),
        keywords: [dgettext_noop("emoji", "herb"), dgettext_noop("emoji", "plant")]
      },
      %{
        char: "\u{2B50}",
        name: dgettext_noop("emoji", "star"),
        keywords: [dgettext_noop("emoji", "star"), dgettext_noop("emoji", "gold")]
      },
      %{
        char: "\u{2600}\u{FE0F}",
        name: dgettext_noop("emoji", "sun"),
        keywords: [dgettext_noop("emoji", "sun"), dgettext_noop("emoji", "bright")]
      },
      %{
        char: "\u{1F319}",
        name: dgettext_noop("emoji", "crescent moon"),
        keywords: [dgettext_noop("emoji", "moon"), dgettext_noop("emoji", "night")]
      },
      %{
        char: "\u{26A1}",
        name: dgettext_noop("emoji", "high voltage"),
        keywords: [dgettext_noop("emoji", "lightning"), dgettext_noop("emoji", "zap")]
      },
      %{
        char: "\u{1F525}",
        name: dgettext_noop("emoji", "fire"),
        keywords: [
          dgettext_noop("emoji", "fire"),
          dgettext_noop("emoji", "hot"),
          dgettext_noop("emoji", "lit")
        ]
      },
      %{
        char: "\u{1F4A7}",
        name: dgettext_noop("emoji", "droplet"),
        keywords: [dgettext_noop("emoji", "water"), dgettext_noop("emoji", "drop")]
      },
      %{
        char: "\u{2744}\u{FE0F}",
        name: dgettext_noop("emoji", "snowflake"),
        keywords: [
          dgettext_noop("emoji", "snow"),
          dgettext_noop("emoji", "cold"),
          dgettext_noop("emoji", "winter")
        ]
      },
      %{
        char: "\u{1F308}",
        name: dgettext_noop("emoji", "rainbow"),
        keywords: [dgettext_noop("emoji", "rainbow"), dgettext_noop("emoji", "colorful")]
      }
    ],
    dgettext_noop("emoji", "Food & Drink") => [
      %{
        char: "\u{1F34E}",
        name: dgettext_noop("emoji", "red apple"),
        keywords: [dgettext_noop("emoji", "apple"), dgettext_noop("emoji", "fruit")]
      },
      %{
        char: "\u{1F34F}",
        name: dgettext_noop("emoji", "green apple"),
        keywords: [dgettext_noop("emoji", "apple"), dgettext_noop("emoji", "fruit")]
      },
      %{
        char: "\u{1F34A}",
        name: dgettext_noop("emoji", "tangerine"),
        keywords: [dgettext_noop("emoji", "orange"), dgettext_noop("emoji", "fruit")]
      },
      %{
        char: "\u{1F34B}",
        name: dgettext_noop("emoji", "lemon"),
        keywords: [dgettext_noop("emoji", "lemon"), dgettext_noop("emoji", "citrus")]
      },
      %{
        char: "\u{1F34C}",
        name: dgettext_noop("emoji", "banana"),
        keywords: [dgettext_noop("emoji", "banana"), dgettext_noop("emoji", "fruit")]
      },
      %{
        char: "\u{1F34D}",
        name: dgettext_noop("emoji", "pineapple"),
        keywords: [dgettext_noop("emoji", "pineapple"), dgettext_noop("emoji", "fruit")]
      },
      %{
        char: "\u{1F347}",
        name: dgettext_noop("emoji", "grapes"),
        keywords: [dgettext_noop("emoji", "grape"), dgettext_noop("emoji", "wine")]
      },
      %{
        char: "\u{1F348}",
        name: dgettext_noop("emoji", "melon"),
        keywords: [dgettext_noop("emoji", "melon"), dgettext_noop("emoji", "fruit")]
      },
      %{
        char: "\u{1F349}",
        name: dgettext_noop("emoji", "watermelon"),
        keywords: [dgettext_noop("emoji", "watermelon"), dgettext_noop("emoji", "summer")]
      },
      %{
        char: "\u{1F353}",
        name: dgettext_noop("emoji", "strawberry"),
        keywords: [dgettext_noop("emoji", "strawberry"), dgettext_noop("emoji", "berry")]
      },
      %{
        char: "\u{1F352}",
        name: dgettext_noop("emoji", "cherries"),
        keywords: [dgettext_noop("emoji", "cherry"), dgettext_noop("emoji", "fruit")]
      },
      %{
        char: "\u{1F351}",
        name: dgettext_noop("emoji", "peach"),
        keywords: [dgettext_noop("emoji", "peach"), dgettext_noop("emoji", "fruit")]
      },
      %{
        char: "\u{1F354}",
        name: dgettext_noop("emoji", "hamburger"),
        keywords: [dgettext_noop("emoji", "burger"), dgettext_noop("emoji", "food")]
      },
      %{
        char: "\u{1F355}",
        name: dgettext_noop("emoji", "pizza"),
        keywords: [dgettext_noop("emoji", "pizza"), dgettext_noop("emoji", "food")]
      },
      %{
        char: "\u{1F35F}",
        name: dgettext_noop("emoji", "french fries"),
        keywords: [dgettext_noop("emoji", "fries"), dgettext_noop("emoji", "food")]
      },
      %{
        char: "\u{1F32D}",
        name: dgettext_noop("emoji", "hot dog"),
        keywords: [dgettext_noop("emoji", "hotdog"), dgettext_noop("emoji", "food")]
      },
      %{
        char: "\u{1F32E}",
        name: dgettext_noop("emoji", "taco"),
        keywords: [dgettext_noop("emoji", "taco"), dgettext_noop("emoji", "food")]
      },
      %{
        char: "\u{1F32F}",
        name: dgettext_noop("emoji", "burrito"),
        keywords: [dgettext_noop("emoji", "burrito"), dgettext_noop("emoji", "food")]
      },
      %{
        char: "\u{1F363}",
        name: dgettext_noop("emoji", "sushi"),
        keywords: [dgettext_noop("emoji", "sushi"), dgettext_noop("emoji", "japanese")]
      },
      %{
        char: "\u{1F359}",
        name: dgettext_noop("emoji", "rice ball"),
        keywords: [dgettext_noop("emoji", "rice"), dgettext_noop("emoji", "japanese")]
      },
      %{
        char: "\u{1F35C}",
        name: dgettext_noop("emoji", "steaming bowl"),
        keywords: [dgettext_noop("emoji", "noodles"), dgettext_noop("emoji", "ramen")]
      },
      %{
        char: "\u{1F370}",
        name: dgettext_noop("emoji", "shortcake"),
        keywords: [dgettext_noop("emoji", "cake"), dgettext_noop("emoji", "dessert")]
      },
      %{
        char: "\u{1F36A}",
        name: dgettext_noop("emoji", "cookie"),
        keywords: [dgettext_noop("emoji", "cookie"), dgettext_noop("emoji", "sweet")]
      },
      %{
        char: "\u{1F36B}",
        name: dgettext_noop("emoji", "chocolate bar"),
        keywords: [dgettext_noop("emoji", "chocolate"), dgettext_noop("emoji", "sweet")]
      },
      %{
        char: "\u{1F36C}",
        name: dgettext_noop("emoji", "candy"),
        keywords: [dgettext_noop("emoji", "candy"), dgettext_noop("emoji", "sweet")]
      },
      %{
        char: "\u{1F36D}",
        name: dgettext_noop("emoji", "lollipop"),
        keywords: [dgettext_noop("emoji", "lollipop"), dgettext_noop("emoji", "sweet")]
      },
      %{
        char: "\u{1F36E}",
        name: dgettext_noop("emoji", "custard"),
        keywords: [dgettext_noop("emoji", "pudding"), dgettext_noop("emoji", "dessert")]
      },
      %{
        char: "\u{1F36F}",
        name: dgettext_noop("emoji", "honey pot"),
        keywords: [dgettext_noop("emoji", "honey"), dgettext_noop("emoji", "sweet")]
      },
      %{
        char: "\u{2615}",
        name: dgettext_noop("emoji", "hot beverage"),
        keywords: [dgettext_noop("emoji", "coffee"), dgettext_noop("emoji", "tea")]
      },
      %{
        char: "\u{1F37A}",
        name: dgettext_noop("emoji", "beer mug"),
        keywords: [dgettext_noop("emoji", "beer"), dgettext_noop("emoji", "drink")]
      },
      %{
        char: "\u{1F37B}",
        name: dgettext_noop("emoji", "clinking beer mugs"),
        keywords: [dgettext_noop("emoji", "beer"), dgettext_noop("emoji", "cheers")]
      },
      %{
        char: "\u{1F377}",
        name: dgettext_noop("emoji", "wine glass"),
        keywords: [dgettext_noop("emoji", "wine"), dgettext_noop("emoji", "drink")]
      },
      %{
        char: "\u{1F378}",
        name: dgettext_noop("emoji", "cocktail glass"),
        keywords: [dgettext_noop("emoji", "cocktail"), dgettext_noop("emoji", "drink")]
      },
      %{
        char: "\u{1F379}",
        name: dgettext_noop("emoji", "tropical drink"),
        keywords: [dgettext_noop("emoji", "drink"), dgettext_noop("emoji", "tropical")]
      },
      %{
        char: "\u{1F37D}\u{FE0F}",
        name: dgettext_noop("emoji", "fork and knife with plate"),
        keywords: [dgettext_noop("emoji", "food"), dgettext_noop("emoji", "dining")]
      }
    ],
    dgettext_noop("emoji", "Travel & Places") => [
      %{
        char: "\u{1F697}",
        name: dgettext_noop("emoji", "automobile"),
        keywords: [dgettext_noop("emoji", "car"), dgettext_noop("emoji", "drive")]
      },
      %{
        char: "\u{1F695}",
        name: dgettext_noop("emoji", "taxi"),
        keywords: [dgettext_noop("emoji", "taxi"), dgettext_noop("emoji", "cab")]
      },
      %{
        char: "\u{1F68C}",
        name: dgettext_noop("emoji", "bus"),
        keywords: [dgettext_noop("emoji", "bus"), dgettext_noop("emoji", "transit")]
      },
      %{
        char: "\u{1F693}",
        name: dgettext_noop("emoji", "police car"),
        keywords: [dgettext_noop("emoji", "police"), dgettext_noop("emoji", "cop")]
      },
      %{
        char: "\u{1F691}",
        name: dgettext_noop("emoji", "ambulance"),
        keywords: [dgettext_noop("emoji", "ambulance"), dgettext_noop("emoji", "emergency")]
      },
      %{
        char: "\u{1F692}",
        name: dgettext_noop("emoji", "fire engine"),
        keywords: [dgettext_noop("emoji", "fire"), dgettext_noop("emoji", "truck")]
      },
      %{
        char: "\u{1F6B2}",
        name: dgettext_noop("emoji", "bicycle"),
        keywords: [dgettext_noop("emoji", "bike"), dgettext_noop("emoji", "cycling")]
      },
      %{
        char: "\u{2708}\u{FE0F}",
        name: dgettext_noop("emoji", "airplane"),
        keywords: [
          dgettext_noop("emoji", "plane"),
          dgettext_noop("emoji", "fly"),
          dgettext_noop("emoji", "travel")
        ]
      },
      %{
        char: "\u{1F680}",
        name: dgettext_noop("emoji", "rocket"),
        keywords: [dgettext_noop("emoji", "rocket"), dgettext_noop("emoji", "space")]
      },
      %{
        char: "\u{1F6F8}",
        name: dgettext_noop("emoji", "flying saucer"),
        keywords: [dgettext_noop("emoji", "ufo"), dgettext_noop("emoji", "alien")]
      },
      %{
        char: "\u{1F6A2}",
        name: dgettext_noop("emoji", "ship"),
        keywords: [dgettext_noop("emoji", "ship"), dgettext_noop("emoji", "boat")]
      },
      %{
        char: "\u{26F5}",
        name: dgettext_noop("emoji", "sailboat"),
        keywords: [dgettext_noop("emoji", "sail"), dgettext_noop("emoji", "boat")]
      },
      %{
        char: "\u{1F3E0}",
        name: dgettext_noop("emoji", "house"),
        keywords: [dgettext_noop("emoji", "home"), dgettext_noop("emoji", "house")]
      },
      %{
        char: "\u{1F3E2}",
        name: dgettext_noop("emoji", "office building"),
        keywords: [dgettext_noop("emoji", "office"), dgettext_noop("emoji", "work")]
      },
      %{
        char: "\u{1F3E5}",
        name: dgettext_noop("emoji", "hospital"),
        keywords: [dgettext_noop("emoji", "hospital"), dgettext_noop("emoji", "medical")]
      },
      %{
        char: "\u{1F3EB}",
        name: dgettext_noop("emoji", "school"),
        keywords: [dgettext_noop("emoji", "school"), dgettext_noop("emoji", "education")]
      },
      %{
        char: "\u{1F3ED}",
        name: dgettext_noop("emoji", "factory"),
        keywords: [dgettext_noop("emoji", "factory"), dgettext_noop("emoji", "industry")]
      },
      %{
        char: "\u{1F3F0}",
        name: dgettext_noop("emoji", "castle"),
        keywords: [dgettext_noop("emoji", "castle"), dgettext_noop("emoji", "kingdom")]
      },
      %{
        char: "\u{26EA}",
        name: dgettext_noop("emoji", "church"),
        keywords: [dgettext_noop("emoji", "church"), dgettext_noop("emoji", "religion")]
      },
      %{
        char: "\u{1F5FC}",
        name: dgettext_noop("emoji", "Tokyo Tower"),
        keywords: [dgettext_noop("emoji", "tower"), dgettext_noop("emoji", "japan")]
      },
      %{
        char: "\u{1F5FD}",
        name: dgettext_noop("emoji", "Statue of Liberty"),
        keywords: [dgettext_noop("emoji", "liberty"), dgettext_noop("emoji", "usa")]
      },
      %{
        char: "\u{1F30D}",
        name: dgettext_noop("emoji", "globe showing Europe-Africa"),
        keywords: [dgettext_noop("emoji", "earth"), dgettext_noop("emoji", "world")]
      },
      %{
        char: "\u{1F30E}",
        name: dgettext_noop("emoji", "globe showing Americas"),
        keywords: [dgettext_noop("emoji", "earth"), dgettext_noop("emoji", "world")]
      },
      %{
        char: "\u{1F30F}",
        name: dgettext_noop("emoji", "globe showing Asia-Australia"),
        keywords: [dgettext_noop("emoji", "earth"), dgettext_noop("emoji", "world")]
      },
      %{
        char: "\u{1F3D4}\u{FE0F}",
        name: dgettext_noop("emoji", "snow-capped mountain"),
        keywords: [dgettext_noop("emoji", "mountain"), dgettext_noop("emoji", "snow")]
      },
      %{
        char: "\u{1F3D6}\u{FE0F}",
        name: dgettext_noop("emoji", "beach with umbrella"),
        keywords: [dgettext_noop("emoji", "beach"), dgettext_noop("emoji", "vacation")]
      },
      %{
        char: "\u{1F3DD}\u{FE0F}",
        name: dgettext_noop("emoji", "desert island"),
        keywords: [dgettext_noop("emoji", "island"), dgettext_noop("emoji", "tropical")]
      }
    ],
    dgettext_noop("emoji", "Activities") => [
      %{
        char: "\u{26BD}",
        name: dgettext_noop("emoji", "soccer ball"),
        keywords: [dgettext_noop("emoji", "soccer"), dgettext_noop("emoji", "football")]
      },
      %{
        char: "\u{1F3C0}",
        name: dgettext_noop("emoji", "basketball"),
        keywords: [dgettext_noop("emoji", "basketball"), dgettext_noop("emoji", "sport")]
      },
      %{
        char: "\u{1F3C8}",
        name: dgettext_noop("emoji", "american football"),
        keywords: [dgettext_noop("emoji", "football"), dgettext_noop("emoji", "nfl")]
      },
      %{
        char: "\u{26BE}",
        name: dgettext_noop("emoji", "baseball"),
        keywords: [dgettext_noop("emoji", "baseball"), dgettext_noop("emoji", "sport")]
      },
      %{
        char: "\u{1F3BE}",
        name: dgettext_noop("emoji", "tennis"),
        keywords: [dgettext_noop("emoji", "tennis"), dgettext_noop("emoji", "sport")]
      },
      %{
        char: "\u{1F3D0}",
        name: dgettext_noop("emoji", "volleyball"),
        keywords: [dgettext_noop("emoji", "volleyball"), dgettext_noop("emoji", "sport")]
      },
      %{
        char: "\u{1F3B1}",
        name: dgettext_noop("emoji", "pool 8 ball"),
        keywords: [dgettext_noop("emoji", "billiards"), dgettext_noop("emoji", "pool")]
      },
      %{
        char: "\u{1F3D3}",
        name: dgettext_noop("emoji", "ping pong"),
        keywords: [dgettext_noop("emoji", "table tennis"), dgettext_noop("emoji", "sport")]
      },
      %{
        char: "\u{1F3C6}",
        name: dgettext_noop("emoji", "trophy"),
        keywords: [
          dgettext_noop("emoji", "trophy"),
          dgettext_noop("emoji", "winner"),
          dgettext_noop("emoji", "award")
        ]
      },
      %{
        char: "\u{1F3C5}",
        name: dgettext_noop("emoji", "sports medal"),
        keywords: [dgettext_noop("emoji", "medal"), dgettext_noop("emoji", "award")]
      },
      %{
        char: "\u{1F947}",
        name: dgettext_noop("emoji", "1st place medal"),
        keywords: [dgettext_noop("emoji", "gold"), dgettext_noop("emoji", "first")]
      },
      %{
        char: "\u{1F948}",
        name: dgettext_noop("emoji", "2nd place medal"),
        keywords: [dgettext_noop("emoji", "silver"), dgettext_noop("emoji", "second")]
      },
      %{
        char: "\u{1F949}",
        name: dgettext_noop("emoji", "3rd place medal"),
        keywords: [dgettext_noop("emoji", "bronze"), dgettext_noop("emoji", "third")]
      },
      %{
        char: "\u{1F3AE}",
        name: dgettext_noop("emoji", "video game"),
        keywords: [dgettext_noop("emoji", "game"), dgettext_noop("emoji", "controller")]
      },
      %{
        char: "\u{1F3AF}",
        name: dgettext_noop("emoji", "bullseye"),
        keywords: [dgettext_noop("emoji", "target"), dgettext_noop("emoji", "dart")]
      },
      %{
        char: "\u{1F3B0}",
        name: dgettext_noop("emoji", "slot machine"),
        keywords: [dgettext_noop("emoji", "casino"), dgettext_noop("emoji", "gamble")]
      },
      %{
        char: "\u{1F3B2}",
        name: dgettext_noop("emoji", "game die"),
        keywords: [dgettext_noop("emoji", "dice"), dgettext_noop("emoji", "game")]
      },
      %{
        char: "\u{265F}\u{FE0F}",
        name: dgettext_noop("emoji", "chess pawn"),
        keywords: [dgettext_noop("emoji", "chess"), dgettext_noop("emoji", "strategy")]
      },
      %{
        char: "\u{1F3B5}",
        name: dgettext_noop("emoji", "musical note"),
        keywords: [dgettext_noop("emoji", "music"), dgettext_noop("emoji", "note")]
      },
      %{
        char: "\u{1F3B6}",
        name: dgettext_noop("emoji", "musical notes"),
        keywords: [dgettext_noop("emoji", "music"), dgettext_noop("emoji", "notes")]
      },
      %{
        char: "\u{1F3B8}",
        name: dgettext_noop("emoji", "guitar"),
        keywords: [dgettext_noop("emoji", "guitar"), dgettext_noop("emoji", "music")]
      },
      %{
        char: "\u{1F3B9}",
        name: dgettext_noop("emoji", "musical keyboard"),
        keywords: [dgettext_noop("emoji", "piano"), dgettext_noop("emoji", "keyboard")]
      },
      %{
        char: "\u{1F3BA}",
        name: dgettext_noop("emoji", "trumpet"),
        keywords: [dgettext_noop("emoji", "trumpet"), dgettext_noop("emoji", "music")]
      },
      %{
        char: "\u{1F3BB}",
        name: dgettext_noop("emoji", "violin"),
        keywords: [dgettext_noop("emoji", "violin"), dgettext_noop("emoji", "music")]
      },
      %{
        char: "\u{1F3AC}",
        name: dgettext_noop("emoji", "clapper board"),
        keywords: [dgettext_noop("emoji", "movie"), dgettext_noop("emoji", "film")]
      },
      %{
        char: "\u{1F3A8}",
        name: dgettext_noop("emoji", "artist palette"),
        keywords: [dgettext_noop("emoji", "art"), dgettext_noop("emoji", "paint")]
      },
      %{
        char: "\u{1F3AD}",
        name: dgettext_noop("emoji", "performing arts"),
        keywords: [dgettext_noop("emoji", "theater"), dgettext_noop("emoji", "drama")]
      }
    ],
    dgettext_noop("emoji", "Objects") => [
      %{
        char: "\u{1F4F1}",
        name: dgettext_noop("emoji", "mobile phone"),
        keywords: [dgettext_noop("emoji", "phone"), dgettext_noop("emoji", "cell")]
      },
      %{
        char: "\u{1F4BB}",
        name: dgettext_noop("emoji", "laptop"),
        keywords: [dgettext_noop("emoji", "computer"), dgettext_noop("emoji", "laptop")]
      },
      %{
        char: "\u{1F5A5}\u{FE0F}",
        name: dgettext_noop("emoji", "desktop computer"),
        keywords: [dgettext_noop("emoji", "computer"), dgettext_noop("emoji", "desktop")]
      },
      %{
        char: "\u{2328}\u{FE0F}",
        name: dgettext_noop("emoji", "keyboard"),
        keywords: [dgettext_noop("emoji", "keyboard"), dgettext_noop("emoji", "type")]
      },
      %{
        char: "\u{1F4BE}",
        name: dgettext_noop("emoji", "floppy disk"),
        keywords: [dgettext_noop("emoji", "floppy"), dgettext_noop("emoji", "save")]
      },
      %{
        char: "\u{1F4BF}",
        name: dgettext_noop("emoji", "optical disk"),
        keywords: [dgettext_noop("emoji", "cd"), dgettext_noop("emoji", "disc")]
      },
      %{
        char: "\u{1F4C0}",
        name: dgettext_noop("emoji", "dvd"),
        keywords: [dgettext_noop("emoji", "dvd"), dgettext_noop("emoji", "disc")]
      },
      %{
        char: "\u{1F4BD}",
        name: dgettext_noop("emoji", "minidisc"),
        keywords: [dgettext_noop("emoji", "disc"), dgettext_noop("emoji", "data")]
      },
      %{
        char: "\u{1F4F7}",
        name: dgettext_noop("emoji", "camera"),
        keywords: [dgettext_noop("emoji", "camera"), dgettext_noop("emoji", "photo")]
      },
      %{
        char: "\u{1F4FA}",
        name: dgettext_noop("emoji", "television"),
        keywords: [dgettext_noop("emoji", "tv"), dgettext_noop("emoji", "screen")]
      },
      %{
        char: "\u{1F4FB}",
        name: dgettext_noop("emoji", "radio"),
        keywords: [dgettext_noop("emoji", "radio"), dgettext_noop("emoji", "broadcast")]
      },
      %{
        char: "\u{1F50B}",
        name: dgettext_noop("emoji", "battery"),
        keywords: [dgettext_noop("emoji", "battery"), dgettext_noop("emoji", "power")]
      },
      %{
        char: "\u{1F50C}",
        name: dgettext_noop("emoji", "electric plug"),
        keywords: [dgettext_noop("emoji", "plug"), dgettext_noop("emoji", "power")]
      },
      %{
        char: "\u{1F4A1}",
        name: dgettext_noop("emoji", "light bulb"),
        keywords: [dgettext_noop("emoji", "idea"), dgettext_noop("emoji", "light")]
      },
      %{
        char: "\u{1F50D}",
        name: dgettext_noop("emoji", "magnifying glass left"),
        keywords: [dgettext_noop("emoji", "search"), dgettext_noop("emoji", "find")]
      },
      %{
        char: "\u{1F50E}",
        name: dgettext_noop("emoji", "magnifying glass right"),
        keywords: [dgettext_noop("emoji", "search"), dgettext_noop("emoji", "find")]
      },
      %{
        char: "\u{1F512}",
        name: dgettext_noop("emoji", "locked"),
        keywords: [dgettext_noop("emoji", "lock"), dgettext_noop("emoji", "security")]
      },
      %{
        char: "\u{1F513}",
        name: dgettext_noop("emoji", "unlocked"),
        keywords: [dgettext_noop("emoji", "unlock"), dgettext_noop("emoji", "open")]
      },
      %{
        char: "\u{1F511}",
        name: dgettext_noop("emoji", "key"),
        keywords: [dgettext_noop("emoji", "key"), dgettext_noop("emoji", "lock")]
      },
      %{
        char: "\u{1F528}",
        name: dgettext_noop("emoji", "hammer"),
        keywords: [dgettext_noop("emoji", "hammer"), dgettext_noop("emoji", "tool")]
      },
      %{
        char: "\u{1F527}",
        name: dgettext_noop("emoji", "wrench"),
        keywords: [dgettext_noop("emoji", "wrench"), dgettext_noop("emoji", "tool")]
      },
      %{
        char: "\u{1F529}",
        name: dgettext_noop("emoji", "nut and bolt"),
        keywords: [dgettext_noop("emoji", "nut"), dgettext_noop("emoji", "bolt")]
      },
      %{
        char: "\u{2699}\u{FE0F}",
        name: dgettext_noop("emoji", "gear"),
        keywords: [dgettext_noop("emoji", "gear"), dgettext_noop("emoji", "settings")]
      },
      %{
        char: "\u{1F4E7}",
        name: dgettext_noop("emoji", "email"),
        keywords: [dgettext_noop("emoji", "email"), dgettext_noop("emoji", "mail")]
      },
      %{
        char: "\u{1F4E8}",
        name: dgettext_noop("emoji", "incoming envelope"),
        keywords: [dgettext_noop("emoji", "email"), dgettext_noop("emoji", "inbox")]
      },
      %{
        char: "\u{1F4DD}",
        name: dgettext_noop("emoji", "memo"),
        keywords: [dgettext_noop("emoji", "note"), dgettext_noop("emoji", "write")]
      },
      %{
        char: "\u{1F4D6}",
        name: dgettext_noop("emoji", "open book"),
        keywords: [dgettext_noop("emoji", "book"), dgettext_noop("emoji", "read")]
      },
      %{
        char: "\u{1F4DA}",
        name: dgettext_noop("emoji", "books"),
        keywords: [dgettext_noop("emoji", "books"), dgettext_noop("emoji", "library")]
      },
      %{
        char: "\u{1F4CB}",
        name: dgettext_noop("emoji", "clipboard"),
        keywords: [dgettext_noop("emoji", "clipboard"), dgettext_noop("emoji", "list")]
      },
      %{
        char: "\u{1F4CC}",
        name: dgettext_noop("emoji", "pushpin"),
        keywords: [dgettext_noop("emoji", "pin"), dgettext_noop("emoji", "mark")]
      },
      %{
        char: "\u{1F4CE}",
        name: dgettext_noop("emoji", "paperclip"),
        keywords: [dgettext_noop("emoji", "paperclip"), dgettext_noop("emoji", "attach")]
      },
      %{
        char: "\u{2702}\u{FE0F}",
        name: dgettext_noop("emoji", "scissors"),
        keywords: [dgettext_noop("emoji", "scissors"), dgettext_noop("emoji", "cut")]
      },
      %{
        char: "\u{1F4B0}",
        name: dgettext_noop("emoji", "money bag"),
        keywords: [dgettext_noop("emoji", "money"), dgettext_noop("emoji", "rich")]
      },
      %{
        char: "\u{1F4B3}",
        name: dgettext_noop("emoji", "credit card"),
        keywords: [dgettext_noop("emoji", "card"), dgettext_noop("emoji", "payment")]
      },
      %{
        char: "\u{1F48E}",
        name: dgettext_noop("emoji", "gem stone"),
        keywords: [dgettext_noop("emoji", "gem"), dgettext_noop("emoji", "diamond")]
      }
    ],
    dgettext_noop("emoji", "Symbols") => [
      %{
        char: "\u{2705}",
        name: dgettext_noop("emoji", "check mark button"),
        keywords: [
          dgettext_noop("emoji", "check"),
          dgettext_noop("emoji", "yes"),
          dgettext_noop("emoji", "done")
        ]
      },
      %{
        char: "\u{274C}",
        name: dgettext_noop("emoji", "cross mark"),
        keywords: [
          dgettext_noop("emoji", "no"),
          dgettext_noop("emoji", "wrong"),
          dgettext_noop("emoji", "delete")
        ]
      },
      %{
        char: "\u{274E}",
        name: dgettext_noop("emoji", "cross mark button"),
        keywords: [dgettext_noop("emoji", "no"), dgettext_noop("emoji", "wrong")]
      },
      %{
        char: "\u{2B55}",
        name: dgettext_noop("emoji", "hollow red circle"),
        keywords: [dgettext_noop("emoji", "circle"), dgettext_noop("emoji", "zero")]
      },
      %{
        char: "\u{2757}",
        name: dgettext_noop("emoji", "red exclamation mark"),
        keywords: [dgettext_noop("emoji", "exclamation"), dgettext_noop("emoji", "warning")]
      },
      %{
        char: "\u{2753}",
        name: dgettext_noop("emoji", "red question mark"),
        keywords: [dgettext_noop("emoji", "question"), dgettext_noop("emoji", "help")]
      },
      %{
        char: "\u{2049}\u{FE0F}",
        name: dgettext_noop("emoji", "exclamation question mark"),
        keywords: [dgettext_noop("emoji", "surprise"), dgettext_noop("emoji", "what")]
      },
      %{
        char: "\u{203C}\u{FE0F}",
        name: dgettext_noop("emoji", "double exclamation mark"),
        keywords: [dgettext_noop("emoji", "exclamation"), dgettext_noop("emoji", "urgent")]
      },
      %{
        char: "\u{1F4F2}",
        name: dgettext_noop("emoji", "mobile phone with arrow"),
        keywords: [dgettext_noop("emoji", "call"), dgettext_noop("emoji", "phone")]
      },
      %{
        char: "\u{1F6AB}",
        name: dgettext_noop("emoji", "prohibited"),
        keywords: [dgettext_noop("emoji", "no"), dgettext_noop("emoji", "forbidden")]
      },
      %{
        char: "\u{1F4A4}",
        name: dgettext_noop("emoji", "zzz"),
        keywords: [dgettext_noop("emoji", "sleep"), dgettext_noop("emoji", "tired")]
      },
      %{
        char: "\u{1F4A2}",
        name: dgettext_noop("emoji", "anger symbol"),
        keywords: [dgettext_noop("emoji", "angry"), dgettext_noop("emoji", "rage")]
      },
      %{
        char: "\u{1F4A3}",
        name: dgettext_noop("emoji", "bomb"),
        keywords: [dgettext_noop("emoji", "bomb"), dgettext_noop("emoji", "explode")]
      },
      %{
        char: "\u{1F4A5}",
        name: dgettext_noop("emoji", "collision"),
        keywords: [dgettext_noop("emoji", "boom"), dgettext_noop("emoji", "crash")]
      },
      %{
        char: "\u{1F4A8}",
        name: dgettext_noop("emoji", "dashing away"),
        keywords: [dgettext_noop("emoji", "wind"), dgettext_noop("emoji", "fast")]
      },
      %{
        char: "\u{1F4AC}",
        name: dgettext_noop("emoji", "speech balloon"),
        keywords: [dgettext_noop("emoji", "chat"), dgettext_noop("emoji", "talk")]
      },
      %{
        char: "\u{1F4AD}",
        name: dgettext_noop("emoji", "thought balloon"),
        keywords: [dgettext_noop("emoji", "think"), dgettext_noop("emoji", "thought")]
      },
      %{
        char: "\u{1F440}",
        name: dgettext_noop("emoji", "eyes"),
        keywords: [dgettext_noop("emoji", "eyes"), dgettext_noop("emoji", "look")]
      },
      %{
        char: "\u{1F648}",
        name: dgettext_noop("emoji", "see-no-evil monkey"),
        keywords: [dgettext_noop("emoji", "monkey"), dgettext_noop("emoji", "blind")]
      },
      %{
        char: "\u{1F649}",
        name: dgettext_noop("emoji", "hear-no-evil monkey"),
        keywords: [dgettext_noop("emoji", "monkey"), dgettext_noop("emoji", "deaf")]
      },
      %{
        char: "\u{1F64A}",
        name: dgettext_noop("emoji", "speak-no-evil monkey"),
        keywords: [dgettext_noop("emoji", "monkey"), dgettext_noop("emoji", "mute")]
      },
      %{
        char: "\u{2B06}\u{FE0F}",
        name: dgettext_noop("emoji", "up arrow"),
        keywords: [dgettext_noop("emoji", "up"), dgettext_noop("emoji", "arrow")]
      },
      %{
        char: "\u{2B07}\u{FE0F}",
        name: dgettext_noop("emoji", "down arrow"),
        keywords: [dgettext_noop("emoji", "down"), dgettext_noop("emoji", "arrow")]
      },
      %{
        char: "\u{27A1}\u{FE0F}",
        name: dgettext_noop("emoji", "right arrow"),
        keywords: [dgettext_noop("emoji", "right"), dgettext_noop("emoji", "arrow")]
      },
      %{
        char: "\u{2B05}\u{FE0F}",
        name: dgettext_noop("emoji", "left arrow"),
        keywords: [dgettext_noop("emoji", "left"), dgettext_noop("emoji", "arrow")]
      },
      %{
        char: "\u{1F504}",
        name: dgettext_noop("emoji", "counterclockwise arrows"),
        keywords: [dgettext_noop("emoji", "refresh"), dgettext_noop("emoji", "reload")]
      },
      %{
        char: "\u{2139}\u{FE0F}",
        name: dgettext_noop("emoji", "information"),
        keywords: [dgettext_noop("emoji", "info"), dgettext_noop("emoji", "help")]
      },
      %{
        char: "\u{1F195}",
        name: dgettext_noop("emoji", "NEW button"),
        keywords: [dgettext_noop("emoji", "new"), dgettext_noop("emoji", "badge")]
      },
      %{
        char: "\u{1F197}",
        name: dgettext_noop("emoji", "OK button"),
        keywords: [dgettext_noop("emoji", "ok"), dgettext_noop("emoji", "accept")]
      },
      %{
        char: "\u{1F199}",
        name: dgettext_noop("emoji", "UP! button"),
        keywords: [dgettext_noop("emoji", "up"), dgettext_noop("emoji", "update")]
      }
    ]
  }

  @all_emojis @emojis
              |> Map.values()
              |> List.flatten()

  @doc "Returns all emojis grouped by category."
  @spec all() :: %{String.t() => [emoji()]}
  def all do
    Map.new(@emojis, fn {category, emojis} ->
      {t(category), translate_emojis(emojis)}
    end)
  end

  @doc "Returns the list of category names in display order."
  @spec categories() :: [String.t()]
  def categories, do: Enum.map(@categories, &t/1)

  @doc "Returns emojis for a given category."
  @spec by_category(String.t()) :: [emoji()]
  def by_category(category) do
    category
    |> canonical_category()
    |> then(&Map.get(@emojis, &1, []))
    |> translate_emojis()
  end

  @doc """
  Searches emojis by name and keywords.

  Returns empty list for queries shorter than 2 characters.
  Case-insensitive matching on name and keywords.
  """
  @spec search(String.t()) :: [emoji()]
  def search(query) when byte_size(query) < 2, do: []

  def search(query) do
    downcased = String.downcase(query)

    @all_emojis
    |> Enum.filter(&emoji_matches?(&1, downcased))
    |> translate_emojis()
  end

  defp canonical_category(category) do
    Enum.find(@categories, fn canonical ->
      category in [canonical, t(canonical)]
    end) || category
  end

  defp emoji_matches?(emoji, downcased) do
    searchable =
      [emoji.name, t(emoji.name)] ++
        emoji.keywords ++ Enum.map(emoji.keywords, &t/1)

    Enum.any?(searchable, fn text ->
      String.contains?(String.downcase(text), downcased)
    end)
  end

  defp translate_emojis(emojis), do: Enum.map(emojis, &translate_emoji/1)

  defp translate_emoji(emoji) do
    %{emoji | name: t(emoji.name), keywords: Enum.map(emoji.keywords, &t/1)}
  end

  defp t(msgid), do: Gettext.dgettext(RetroHexChat.Gettext, "emoji", msgid)
end
