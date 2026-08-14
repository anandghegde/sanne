# Contributing to Sanne

Thanks for helping build a free, open-source gesture layer for macOS.

## Ground rules

- Sanne is **free forever** — no paid features, no license keys, no “pro” tier.
- Keep changes focused. Match existing style. Prefer simple code.
- Discuss large features in a GitHub Issue before a big PR.
- Stay inside product scope. We intentionally are **not** building a BetterTouchTool clone.

## Development

1. macOS 13+ and Swift 5.9+ (Xcode or Command Line Tools with macOS SDK).
2. From the repo root:

   ```bash
   swift build
   swift run
   ```

   Or open `Package.swift` in Xcode.

3. Grant **Accessibility** to the `Sanne` binary when prompted.
4. Prefer unit tests for pure logic (`LayoutGeometry`, config matching, etc.).

### Packaging a local `.app` / DMG

```bash
./scripts/package-app.sh      # dist/Sanne.app (ad-hoc sign)
./scripts/package-dmg.sh      # also builds Sanne-<version>.dmg + .sha256
```

Version comes from the `VERSION` file. Release/notarization steps: [docs/RELEASING.md](./docs/RELEASING.md).

## Pull requests

1. Fork and branch from `main`.
2. One logical change per PR when possible.
3. Describe *what* and *why*.
4. Note devices tested (built-in trackpad, Magic Trackpad, Magic Mouse 2/3, multi-monitor).
5. Do not commit secrets, signing certs, or notarization credentials.

## Code of conduct

Be respectful. Harassment or bad-faith behavior is not welcome.

## License

By contributing, you agree your contributions are licensed under the **MIT License** (see [LICENSE](./LICENSE)).
