#!/usr/bin/env python3
"""
probe.py — Capture a web page's accessibility tree and interactive elements
using standalone Playwright (outside the Login Enterprise engine).

The LE engine's WebScriptBase has no DOM dump capability, so this script runs
Playwright directly to discover real element identifiers for app-map.json.

Output: a JSON file with the aria snapshot (YAML-like tree) and a list of
interactive DOM elements with tag, role, name, text, id, class, and href.

Requires: pip install playwright && playwright install chromium
"""
import argparse
import json
import os
import sys


def probe(url, browser_type="chromium", headless=True, wait_seconds=2, out_path="web-dump.json"):
    try:
        from playwright.sync_api import sync_playwright
    except ImportError:
        sys.exit(
            "ERROR: playwright is not installed.\n"
            "Run: pip install playwright && playwright install chromium"
        )

    with sync_playwright() as p:
        launcher = getattr(p, browser_type, None)
        if launcher is None:
            sys.exit(f"ERROR: unknown browser type '{browser_type}'. Use chromium, firefox, or webkit.")

        try:
            browser = launcher.launch(headless=headless)
        except Exception as e:
            sys.exit(
                f"ERROR: failed to launch {browser_type}.\n"
                f"  {e}\n"
                f"Ensure the browser is installed: playwright install {browser_type}"
            )

        page = browser.new_page()

        try:
            print(f"Navigating to {url}...")
            page.goto(url, wait_until="networkidle", timeout=30000)
        except Exception as e:
            browser.close()
            sys.exit(
                f"ERROR: failed to navigate to {url}.\n"
                f"  {e}\n"
                f"Check the URL is correct and the site is reachable."
            )

        if wait_seconds > 0:
            page.wait_for_timeout(wait_seconds * 1000)

        title = page.title()
        final_url = page.url

        # Aria snapshot — YAML-like tree of accessible elements
        print("Capturing aria snapshot...")
        try:
            aria_snapshot = page.locator("body").aria_snapshot()
        except Exception as e:
            print(f"Warning: aria snapshot failed ({e}), continuing without it.")
            aria_snapshot = ""

        # Interactive elements via JS evaluation
        print("Enumerating DOM elements...")
        try:
            elements = page.evaluate("""() => {
                const selectors = 'a, button, input, select, textarea, [role], ' +
                    'h1, h2, h3, h4, h5, h6, label, img, nav, main, footer, ' +
                    'header, section, article, form, table, th, td, li, [aria-label]';
                const els = document.querySelectorAll(selectors);
                const seen = new Set();
                const results = [];

                for (const el of els) {
                    // Build a reasonable CSS selector
                    let selector = el.tagName.toLowerCase();
                    if (el.id) {
                        selector = '#' + el.id;
                    } else if (el.className && typeof el.className === 'string' && el.className.trim()) {
                        selector += '.' + el.className.trim().split(/\\s+/).join('.');
                    }

                    // Deduplicate by selector + text
                    const text = (el.innerText || '').slice(0, 200).trim();
                    const key = selector + '|' + text;
                    if (seen.has(key)) continue;
                    seen.add(key);

                    results.push({
                        tag: el.tagName.toLowerCase(),
                        role: el.getAttribute('role') || '',
                        name: el.getAttribute('aria-label') || '',
                        text: text,
                        id: el.id || '',
                        className: (typeof el.className === 'string' ? el.className : '') || '',
                        type: el.type || '',
                        href: el.href || '',
                        selector: selector
                    });
                }
                return results;
            }""")
        except Exception as e:
            browser.close()
            sys.exit(
                f"ERROR: failed to enumerate DOM elements.\n"
                f"  {e}\n"
                f"The page may use content security policies that block evaluation."
            )

        dump = {
            "url": final_url,
            "title": title,
            "ariaSnapshot": aria_snapshot,
            "elementCount": len(elements),
            "elements": elements,
        }

        os.makedirs(os.path.dirname(os.path.abspath(out_path)), exist_ok=True)
        with open(out_path, "w", encoding="utf-8") as f:
            json.dump(dump, f, indent=2, ensure_ascii=False)

        print(f"Captured {len(elements)} elements from '{title}'")
        print(f"  Dump: {os.path.abspath(out_path)}")

        browser.close()


def main():
    ap = argparse.ArgumentParser(description="Capture web page structure for app-map.json.")
    ap.add_argument("url", help="URL to probe")
    ap.add_argument("--out", default="web-dump.json", help="Output JSON path (default: web-dump.json)")
    ap.add_argument("--browser", default="chromium", choices=["chromium", "firefox", "webkit"],
                    help="Browser to use (default: chromium)")
    ap.add_argument("--wait", type=int, default=2, help="Seconds to wait after load (default: 2)")
    ap.add_argument("--no-headless", action="store_true", help="Show the browser window")
    args = ap.parse_args()

    probe(args.url, browser_type=args.browser, headless=not args.no_headless,
          wait_seconds=args.wait, out_path=args.out)


if __name__ == "__main__":
    main()
