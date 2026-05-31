defmodule RetroHexChat.Bots.Capabilities.Trivia.QuestionBank do
  @moduledoc """
  Built-in question bank for the Trivia capability.
  Organized by category with questions, answers, and hints.
  """

  use Gettext, backend: RetroHexChat.Gettext

  @type question :: %{
          question: String.t(),
          answer: String.t(),
          hints: [String.t()],
          category: String.t()
        }

  @questions %{
    "general" => [
      %{
        question: gettext("What is the capital of France?"),
        answer: gettext("Paris"),
        hints: [gettext("City of Light")]
      },
      %{
        question: gettext("How many continents are there?"),
        answer: "7",
        hints: [gettext("More than 5")]
      },
      %{
        question: gettext("What is the largest ocean?"),
        answer: gettext("Pacific"),
        hints: [gettext("Peaceful")]
      },
      %{
        question: gettext("What year did the Titanic sink?"),
        answer: "1912",
        hints: [gettext("Early 20th century")]
      },
      %{
        question: gettext("How many colors in a rainbow?"),
        answer: "7",
        hints: [gettext("ROY G BIV")]
      },
      %{
        question: gettext("What is the hardest natural substance?"),
        answer: "diamond",
        hints: [gettext("A gem")]
      },
      %{
        question: gettext("What planet is known as the Red Planet?"),
        answer: gettext("Mars"),
        hints: [gettext("4th from sun")]
      },
      %{
        question: gettext("How many sides does a hexagon have?"),
        answer: "6",
        hints: [gettext("Hex = six")]
      },
      %{
        question: gettext("What is the chemical symbol for gold?"),
        answer: gettext("Au"),
        hints: [gettext("From Latin aurum")]
      },
      %{
        question: gettext("What is the largest mammal?"),
        answer: gettext("blue whale"),
        hints: [gettext("Lives in the ocean")]
      },
      %{
        question: gettext("What gas do plants absorb?"),
        answer: gettext("carbon dioxide"),
        hints: ["CO2"]
      },
      %{
        question: gettext("What is the boiling point of water in Celsius?"),
        answer: "100",
        hints: [gettext("Three digits")]
      },
      %{
        question: gettext("How many bones in the adult human body?"),
        answer: "206",
        hints: [gettext("Over 200")]
      },
      %{
        question: gettext("What is the speed of light (km/s)?"),
        answer: "300000",
        hints: [gettext("~3 x 10^5 km/s")]
      },
      %{
        question: gettext("What is the smallest country by area?"),
        answer: gettext("Vatican City"),
        hints: [gettext("In Rome")]
      }
    ],
    "science" => [
      %{
        question: gettext("What is the chemical symbol for water?"),
        answer: "H2O",
        hints: [gettext("Two elements")]
      },
      %{
        question: gettext("What planet has the most moons?"),
        answer: gettext("Saturn"),
        hints: [gettext("Famous for rings")]
      },
      %{
        question: gettext("What is the powerhouse of the cell?"),
        answer: "mitochondria",
        hints: [gettext("Organelle")]
      },
      %{
        question: gettext("What element has atomic number 1?"),
        answer: "hydrogen",
        hints: [gettext("Lightest")]
      },
      %{
        question: gettext("What is the closest star to Earth?"),
        answer: gettext("Sun"),
        hints: [gettext("Look up")]
      },
      %{
        question: gettext("What is the pH of pure water?"),
        answer: "7",
        hints: [gettext("Neutral")]
      },
      %{
        question: gettext("What gas makes up 78% of Earth's atmosphere?"),
        answer: "nitrogen",
        hints: ["N2"]
      },
      %{
        question: gettext("How many planets in our solar system?"),
        answer: "8",
        hints: [gettext("Pluto was demoted")]
      },
      %{
        question: gettext("What is the chemical formula for table salt?"),
        answer: gettext("NaCl"),
        hints: [gettext("Sodium...")]
      },
      %{
        question: gettext("What force keeps planets in orbit?"),
        answer: "gravity",
        hints: [gettext("Newton's apple")]
      },
      %{
        question: gettext("What is absolute zero in Celsius?"),
        answer: "-273",
        hints: [gettext("Very cold")]
      },
      %{
        question: gettext("What vitamin does the sun provide?"),
        answer: "D",
        hints: [gettext("A single letter")]
      },
      %{
        question: gettext("What is the largest organ in the human body?"),
        answer: "skin",
        hints: [gettext("Outside")]
      },
      %{
        question: gettext("What particle has a positive charge?"),
        answer: "proton",
        hints: [gettext("In the nucleus")]
      },
      %{
        question: gettext("What is the study of fungi called?"),
        answer: "mycology",
        hints: [gettext("Myco-")]
      }
    ],
    "history" => [
      %{
        question: gettext("In what year did World War II end?"),
        answer: "1945",
        hints: ["Mid-1940s"]
      },
      %{
        question: gettext("Who was the first president of the USA?"),
        answer: gettext("George Washington"),
        hints: [gettext("Dollar bill")]
      },
      %{
        question: gettext("What ancient wonder was in Alexandria?"),
        answer: gettext("Lighthouse"),
        hints: [gettext("Pharos")]
      },
      %{
        question: gettext("What year did the Berlin Wall fall?"),
        answer: "1989",
        hints: [gettext("Late 1980s")]
      },
      %{
        question: gettext("Who wrote the Communist Manifesto?"),
        answer: gettext("Karl Marx"),
        hints: [gettext("German philosopher")]
      },
      %{
        question: gettext("What empire built the Colosseum?"),
        answer: gettext("Roman"),
        hints: [gettext("In Italy")]
      },
      %{
        question: gettext("What ship brought Pilgrims to America?"),
        answer: gettext("Mayflower"),
        hints: [gettext("A flower")]
      },
      %{
        question: gettext("Who invented the printing press?"),
        answer: gettext("Gutenberg"),
        hints: [gettext("Johannes")]
      },
      %{
        question: gettext("What year did Columbus reach America?"),
        answer: "1492",
        hints: [gettext("15th century")]
      },
      %{
        question: gettext("Who was the first man on the moon?"),
        answer: gettext("Neil Armstrong"),
        hints: [gettext("Apollo 11")]
      },
      %{
        question: gettext("What revolution started in 1789?"),
        answer: gettext("French Revolution"),
        hints: [gettext("Bastille")]
      },
      %{
        question: gettext("Who painted the Mona Lisa?"),
        answer: gettext("Leonardo da Vinci"),
        hints: [gettext("Renaissance")]
      },
      %{
        question: gettext("What year was the Declaration of Independence signed?"),
        answer: "1776",
        hints: ["17--"]
      },
      %{
        question: gettext("Who discovered penicillin?"),
        answer: gettext("Alexander Fleming"),
        hints: [gettext("Scottish")]
      },
      %{
        question: gettext("What civilization built Machu Picchu?"),
        answer: gettext("Inca"),
        hints: [gettext("South America")]
      }
    ],
    "geography" => [
      %{
        question: gettext("What is the longest river in the world?"),
        answer: gettext("Nile"),
        hints: [gettext("In Africa")]
      },
      %{
        question: gettext("What is the tallest mountain?"),
        answer: gettext("Mount Everest"),
        hints: [gettext("In Nepal")]
      },
      %{
        question: gettext("What country has the most people?"),
        answer: gettext("India"),
        hints: [gettext("South Asia")]
      },
      %{
        question: gettext("What is the largest desert?"),
        answer: gettext("Sahara"),
        hints: [gettext("In Africa")]
      },
      %{
        question: gettext("What is the capital of Japan?"),
        answer: gettext("Tokyo"),
        hints: [gettext("Starts with T")]
      },
      %{
        question: gettext("What is the deepest ocean trench?"),
        answer: gettext("Mariana Trench"),
        hints: [gettext("Pacific")]
      },
      %{
        question: gettext("What continent is Brazil in?"),
        answer: gettext("South America"),
        hints: [gettext("Southern hemisphere")]
      },
      %{
        question: gettext("What is the capital of Australia?"),
        answer: gettext("Canberra"),
        hints: [gettext("Not Sydney")]
      },
      %{
        question: gettext("What is the smallest continent?"),
        answer: gettext("Australia"),
        hints: [gettext("Also a country")]
      },
      %{
        question: gettext("What sea is between Europe and Africa?"),
        answer: gettext("Mediterranean"),
        hints: [gettext("Middle earth")]
      },
      %{
        question: gettext("What is the capital of Canada?"),
        answer: gettext("Ottawa"),
        hints: [gettext("Not Toronto")]
      },
      %{
        question: gettext("What strait separates Asia and North America?"),
        answer: gettext("Bering Strait"),
        hints: [gettext("Named after Vitus")]
      },
      %{
        question: gettext("What is the largest island?"),
        answer: gettext("Greenland"),
        hints: [gettext("Danish territory")]
      },
      %{
        question: gettext("What country is the Sahara Desert mostly in?"),
        answer: gettext("Algeria"),
        hints: [gettext("North Africa")]
      },
      %{
        question: gettext("What is the capital of Egypt?"),
        answer: gettext("Cairo"),
        hints: [gettext("On the Nile")]
      }
    ],
    "technology" => [
      %{
        question: gettext("What does HTML stand for?"),
        answer: gettext("HyperText Markup Language"),
        hints: [gettext("Web pages")]
      },
      %{
        question: gettext("Who created Linux?"),
        answer: gettext("Linus Torvalds"),
        hints: [gettext("Finnish")]
      },
      %{
        question: gettext("What year was the first iPhone released?"),
        answer: "2007",
        hints: [gettext("Late 2000s")]
      },
      %{
        question: gettext("What does CPU stand for?"),
        answer: gettext("Central Processing Unit"),
        hints: [gettext("Brain of computer")]
      },
      %{
        question: gettext("What company created Java?"),
        answer: gettext("Sun Microsystems"),
        hints: [gettext("Now Oracle")]
      },
      %{
        question: gettext("What does HTTP stand for?"),
        answer: gettext("HyperText Transfer Protocol"),
        hints: [gettext("Web")]
      },
      %{
        question: gettext("Who founded Microsoft?"),
        answer: gettext("Bill Gates"),
        hints: [gettext("And Paul Allen")]
      },
      %{
        question: gettext("What year was the World Wide Web invented?"),
        answer: "1989",
        hints: [gettext("Tim Berners-Lee")]
      },
      %{
        question: gettext("What does RAM stand for?"),
        answer: gettext("Random Access Memory"),
        hints: [gettext("Volatile")]
      },
      %{
        question: gettext("What programming language is Elixir built on?"),
        answer: gettext("Erlang"),
        hints: [gettext("BEAM VM")]
      },
      %{
        question: gettext("What does SQL stand for?"),
        answer: gettext("Structured Query Language"),
        hints: [gettext("Databases")]
      },
      %{
        question: gettext("Who invented the telephone?"),
        answer: gettext("Alexander Graham Bell"),
        hints: [gettext("Bell Labs")]
      },
      %{
        question: gettext("What does USB stand for?"),
        answer: gettext("Universal Serial Bus"),
        hints: [gettext("Plug it in")]
      },
      %{
        question: gettext("What year was Google founded?"),
        answer: "1998",
        hints: [gettext("Late 1990s")]
      },
      %{
        question: gettext("What does API stand for?"),
        answer: gettext("Application Programming Interface"),
        hints: [gettext("Integration")]
      }
    ],
    "entertainment" => [
      %{
        question: gettext("What movie features a character named Neo?"),
        answer: gettext("The Matrix"),
        hints: [gettext("Red pill")]
      },
      %{
        question: gettext("Who played Iron Man in the MCU?"),
        answer: gettext("Robert Downey Jr"),
        hints: [gettext("RDJ")]
      },
      %{
        question: gettext("What band wrote 'Bohemian Rhapsody'?"),
        answer: gettext("Queen"),
        hints: [gettext("Freddie Mercury")]
      },
      %{
        question: gettext("What is the highest-grossing film of all time?"),
        answer: gettext("Avatar"),
        hints: [gettext("Blue aliens")]
      },
      %{
        question: gettext("Who wrote Harry Potter?"),
        answer: gettext("J.K. Rowling"),
        hints: [gettext("British author")]
      },
      %{
        question: gettext("What instrument has 88 keys?"),
        answer: "piano",
        hints: [gettext("Black and white")]
      },
      %{
        question: gettext("What TV show features dragons and an iron throne?"),
        answer: gettext("Game of Thrones"),
        hints: [gettext("HBO")]
      },
      %{
        question: gettext("Who directed Jurassic Park?"),
        answer: gettext("Steven Spielberg"),
        hints: [gettext("Hollywood legend")]
      },
      %{
        question: gettext("What game features a plumber named Mario?"),
        answer: gettext("Super Mario Bros"),
        hints: [gettext("Nintendo")]
      },
      %{
        question: gettext("What is the best-selling video game of all time?"),
        answer: gettext("Minecraft"),
        hints: [gettext("Blocks")]
      },
      %{
        question: gettext("Who painted the Starry Night?"),
        answer: gettext("Vincent van Gogh"),
        hints: [gettext("Dutch painter")]
      },
      %{
        question: gettext("What fictional detective lived at 221B Baker Street?"),
        answer: gettext("Sherlock Holmes"),
        hints: [gettext("Elementary")]
      },
      %{
        question: gettext("What Disney movie features a genie?"),
        answer: gettext("Aladdin"),
        hints: [gettext("Three wishes")]
      },
      %{
        question: gettext("What board game has properties like Boardwalk?"),
        answer: gettext("Monopoly"),
        hints: [gettext("Pass Go")]
      },
      %{
        question: gettext("Who sang 'Thriller'?"),
        answer: gettext("Michael Jackson"),
        hints: [gettext("King of Pop")]
      }
    ]
  }

  @spec categories() :: [String.t()]
  def categories, do: Map.keys(@questions)

  @spec random_questions(String.t(), pos_integer()) :: [question()]
  def random_questions(category, count) do
    pool = Map.get(@questions, category, Map.get(@questions, "general", []))
    pool |> Enum.shuffle() |> Enum.take(count)
  end

  @spec question_count(String.t()) :: non_neg_integer()
  def question_count(category) do
    pool = Map.get(@questions, category, [])
    length(pool)
  end
end
