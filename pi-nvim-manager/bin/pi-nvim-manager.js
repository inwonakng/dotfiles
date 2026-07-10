#!/usr/bin/env node
require("../src/cli").main().catch((err) => {
  console.error(err && err.stack ? err.stack : String(err));
  process.exit(1);
});
