module.exports = {
  root: true,
  env: {
    es6: true,
    node: true,
  },
  extends: [
    "eslint:recommended",
    "plugin:@typescript-eslint/recommended",
  ],
  parser: "@typescript-eslint/parser",
  parserOptions: {
    sourceType: "module",
  },
  ignorePatterns: ["/lib/**/*"],
  plugins: ["@typescript-eslint"],
  rules: {
    "quotes": ["error", "double"],
    "indent": ["error", 2],
    "max-len": ["warn", {"code": 120}],
    "valid-jsdoc": "off",
    "no-multi-spaces": "error",
    "object-curly-spacing": ["error", "never"],
    "operator-linebreak": ["error", "after"],
    "@typescript-eslint/no-unused-vars": ["warn", {"argsIgnorePattern": "^_|context"}],
  },
};
