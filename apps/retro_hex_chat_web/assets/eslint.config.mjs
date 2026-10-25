import js from "@eslint/js";
import prettier from "eslint-config-prettier";
import globals from "globals";

// What a game may not write: the core does each of these once (see
// docs/guide/games.md), and a game that does it again starts the next copy.
const GAME_SYNTAX = [
  {
    selector: "NewExpression[callee.name='DataView']",
    message: "A game's wire is a core/codec.js schema, not a hand-written DataView.",
  },
  {
    selector: "CallExpression[callee.property.name='createOscillator']",
    message: "A game's sounds are data for core/synth.js (its sounds.js table).",
  },
  {
    selector: "CallExpression[callee.name=/^set(Timeout|Interval)$/]",
    message: "A game counts time in ticks (core/flow.js), never on the page's timers.",
  },
  {
    selector: "CallExpression[callee.property.name=/^set(Timeout|Interval)$/]",
    message: "A game counts time in ticks (core/flow.js), never on the page's timers.",
  },
  {
    selector:
      "ClassDeclaration[superClass.name='GameEngine'], ClassExpression[superClass.name='GameEngine']",
    message: "A game is a defineGame definition (core/define_game.js), not a GameEngine subclass.",
  },
];

const SIMULATION_RANDOM = {
  selector: "CallExpression[callee.object.name='Math'][callee.property.name='random']",
  message:
    "The simulation draws from game.random (seeded, the same on every replay), not Math.random.",
};

export default [
  {
    ignores: ["node_modules/", "vendor/"],
  },
  js.configs.recommended,
  prettier,
  {
    languageOptions: {
      ecmaVersion: 2022,
      sourceType: "module",
      globals: {
        ...globals.browser,
        process: "readonly",
      },
    },
    rules: {
      "no-unused-vars": ["error", { argsIgnorePattern: "^_" }],
      "no-console": "warn",
      eqeqeq: ["error", "always"],
      curly: ["error", "multi-line"],
      "no-var": "error",
      "prefer-const": "error",
    },
  },
  {
    files: ["test/**/*.test.js", "test/helpers/**/*.js", "test/support/**/*.js"],
    languageOptions: {
      globals: {
        ...globals.browser,
        // Vitest globals
        describe: "readonly",
        it: "readonly",
        expect: "readonly",
        beforeEach: "readonly",
        afterEach: "readonly",
        vi: "readonly",
      },
    },
  },
  {
    files: ["js/lib/games/*/**/*.js"],
    ignores: ["js/lib/games/core/**"],
    rules: {
      "no-restricted-syntax": ["error", ...GAME_SYNTAX, SIMULATION_RANDOM],
      "no-restricted-imports": [
        "error",
        {
          patterns: [
            {
              group: ["**/game_engine.js"],
              message:
                "A game is a defineGame definition (core/define_game.js); the engine is the core's.",
            },
          ],
        },
      ],
    },
  },
  {
    // A renderer's sparkle and snow are decoration: no replay depends on them.
    files: ["js/lib/games/*/renderer.js"],
    rules: {
      "no-restricted-syntax": ["error", ...GAME_SYNTAX],
    },
  },
  {
    files: ["scripts/**/*.cjs"],
    languageOptions: {
      sourceType: "commonjs",
      globals: {
        ...globals.node,
      },
    },
  },
];
