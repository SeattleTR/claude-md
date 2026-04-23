#!/bin/bash
# playwright-capture.sh — capture DOM screenshot of a URL for visual validation
# Usage: ./skills/playwright-capture.sh <url> [output.png]
# Requires: playwright installed (npm i -D playwright && npx playwright install chromium)
#
# Output: a PNG file the agent can pass to a Vision-Language Model (VLM)
# for independent visual review. Self-grading of UI is forbidden — always
# submit the screenshot for review.

URL="${1:-http://localhost:3000}"
OUT="${2:-screenshot.png}"

if ! command -v npx &>/dev/null; then
  echo "Error: npx not found. Install Node.js first."
  exit 1
fi

if ! npx playwright --version &>/dev/null 2>&1; then
  echo "Error: playwright not installed. Run:"
  echo "  npm i -D playwright && npx playwright install chromium"
  exit 1
fi

node <<EOF
const { chromium } = require('playwright');
(async () => {
  const browser = await chromium.launch();
  const page = await browser.newPage({ viewport: { width: 1280, height: 800 } });
  try {
    await page.goto('$URL', { waitUntil: 'networkidle', timeout: 15000 });
    await page.screenshot({ path: '$OUT', fullPage: true });
    console.log('Captured: $OUT');
  } catch (e) {
    console.error('Capture failed:', e.message);
    process.exit(1);
  } finally {
    await browser.close();
  }
})();
EOF
