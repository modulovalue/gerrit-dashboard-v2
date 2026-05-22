# gerrit-dashboard-v2

A Flutter web app (compiled to WebAssembly) that surfaces a read-only dashboard of changes from a Gerrit server. Inspired by [kevmoo/scripts.dart `gerrit-view`](https://github.com/kevmoo/scripts.dart#gerrit-view), reduced to the half that does not require local git access.

## Repo layout

This is a Dart 3.5 workspace with two packages:

- `packages/gerrit_api/` -- pure Dart REST bindings for the Gerrit REST API.
- `packages/gerrit_dashboard/` -- Flutter web app that consumes `gerrit_api`.

## Defaults

- Host: `dart-review.googlesource.com`
- Project: `sdk`

Both are editable in the UI and persisted via `SharedPreferences` (browser localStorage).

## Run (development)

```sh
cd packages/gerrit_dashboard
flutter run -d chrome --wasm
```

## Build (release, Wasm)

```sh
cd packages/gerrit_dashboard
flutter build web --wasm
```

Artifacts land in `packages/gerrit_dashboard/build/web/`.

## Tests

```sh
# In repo root
dart test --concurrency=1
# Or per package
cd packages/gerrit_api && dart test
cd packages/gerrit_dashboard && flutter test
```

## CORS

`*.googlesource.com` Gerrit hosts do not generally enable CORS for arbitrary browser origins, so direct Wasm fetches may be blocked. Two ways out:

1. **Same-origin reverse proxy.** Run `caddy` locally, terminating on `localhost:8080`, reverse-proxying `/gerrit/*` to `https://dart-review.googlesource.com/*`. Point the app's host field at `localhost:8080/gerrit`.
2. **Self-host on a domain where you control the proxy** (Cloudflare Worker, nginx, etc.).

A reference Caddyfile:

```Caddyfile
:8080 {
  handle_path /gerrit/* {
    reverse_proxy https://dart-review.googlesource.com {
      header_up Host {upstream_hostport}
    }
  }
  handle {
    reverse_proxy localhost:5173
  }
}
```

The app is intentionally anonymous-only; no credentials are sent or stored.

## Authorization

None. The app uses anonymous Gerrit endpoints (no `/a/` prefix). This means:

- It cannot resolve `owner:self`. Type an explicit owner in the Custom query box (`owner:alice`).
- It cannot see private CLs.

## Out of scope vs. the original `gerrit-view`

- Local branch detection (`branch.*.gerritissue` config)
- `git fetch` / shadow alignment / tree-hash comparisons
- Cleanup safety checks (`git cherry`)
- "Conflated branches" detection
- Authenticated endpoints
