import js from "@eslint/js";
import prettier from "eslint-config-prettier";
import globals from "globals";

// What a game may not write: the core does each of these once (see
// docs/guide/games.md), and a game that does it again starts the next copy.
const ENGINE =
  "A game is a defineGame definition (core/define_game.js), not the engine underneath.";
const TIMERS = "A game counts time in ticks (core/flow.js), never on the page's timers.";
const RANDOM =
  "The simulation draws from game.random (seeded, the same on every replay), not Math.random.";

const GAME_SYNTAX = [
  {
    selector:
      "NewExpression[callee.name='DataView'], NewExpression[callee.property.name='DataView']",
    message: "A game's wire is a core/codec.js schema, not a hand-written DataView.",
  },
  {
    selector:
      "CallExpression[callee.property.name='createOscillator'], CallExpression[callee.property.value='createOscillator']",
    message: "A game's sounds are data for core/synth.js (its sounds.js table).",
  },
  { selector: "CallExpression[callee.name=/^set(Timeout|Interval)$/]", message: TIMERS },
  { selector: "CallExpression[callee.property.name=/^set(Timeout|Interval)$/]", message: TIMERS },
  {
    selector:
      "ClassDeclaration[superClass.name='GameEngine'], ClassExpression[superClass.name='GameEngine'], ClassDeclaration[superClass.property.name='GameEngine'], ClassExpression[superClass.property.name='GameEngine']",
    message: ENGINE,
  },
  { selector: "ImportExpression[source.value=/game_engine/]", message: ENGINE },
];

// Math.random, however reached — except handed on as a parameter's default:
// the pure physics functions are tested with it and called with game.random.
const SIMULATION_RANDOM = [
  {
    selector:
      "MemberExpression[object.name='Math'][property.name='random']:not(AssignmentPattern > MemberExpression.right)",
    message: RANDOM,
  },
  { selector: "MemberExpression[object.name='Math'][property.value='random']", message: RANDOM },
  { selector: "VariableDeclarator[init.name='Math'] > ObjectPattern", message: RANDOM },
];

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
      "no-restricted-syntax": ["error", ...GAME_SYNTAX, ...SIMULATION_RANDOM],
      "no-restricted-imports": [
        "error",
        {
          patterns: [{ group: ["**/game_engine", "**/game_engine.js"], message: ENGINE }],
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
