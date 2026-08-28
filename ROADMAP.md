# PeerPlay — Development Roadmap

> Decentralized P2P Media Streaming & Offline-First Caching Platform
> Tech Stack: Go (Golang) Backend · React Native CLI (Android-first) · PostgreSQL · OP-SQLite + Drizzle ORM

---

## Architecture Overview

```
┌─────────────────────────────────────────────────────────────┐
│                    React Native Client                       │
│  ┌──────────┐  ┌──────────┐  ┌──────────┐  ┌───────────┐  │
│  │ Home Feed│  │  Player  │  │  Vault   │  │  Settings │  │
│  └────┬─────┘  └────┬─────┘  └────┬─────┘  └─────┬─────┘  │
│       │              │              │               │        │
│  ┌────┴──────────────┴──────────────┴───────────────┴────┐  │
│  │              React Native Bridge / Turbo Module         │  │
│  └────┬───────────────────────────────────────────────────┘  │
│       │                                                       │
│  ┌────┴─────────────┐  ┌──────────────┐  ┌──────────────┐  │
│  │ Rust Torrent     │  │ OP-SQLite    │  │ Encrypted    │  │
│  │ Engine (librqbit)│  │ + Drizzle    │  │ Storage      │  │
│  └──────────────────┘  └──────────────┘  └──────────────┘  │
└─────────────────────────────────────────────────────────────┘
                            │
                    ┌───────┴───────┐
                    │   Internet    │
                    └───────┬───────┘
                            │
┌───────────────────────────┴─────────────────────────────────┐
│                     Go Backend Server                        │
│  ┌──────────┐  ┌──────────┐  ┌──────────┐  ┌───────────┐  │
│  │  Auth    │  │ Catalog  │  │   DHT    │  │  Health   │  │
│  │ (JWT)    │  │   API    │  │ Bootstrap│  │   Check   │  │
│  └──────────┘  └──────────┘  └──────────┘  └───────────┘  │
│  ┌──────────────────────────────────────────────────────┐   │
│  │              PostgreSQL + Redis Cache                 │   │
│  └──────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────┘
```

---

## Phase 0: Foundation & Project Scaffolding
**Duration: Week 1–2**

### Objectives
- Initialize monorepo with Go backend and React Native client
- Set up Docker Compose for local development
- Establish CI/CD pipeline

### Tasks

| # | Task | Status | Details |
|---|------|--------|---------|
| 0.1 | Git repo initialization | ✅ | Monorepo with `server/` and `mobile/` directories |
| 0.2 | Go backend scaffold | ✅ | Clean architecture: `cmd/server/main.go`, `internal/{api,dht,models,repository,middleware,config}`, `go.mod`, `.env`, multi-stage Dockerfile |
| 0.3 | React Native CLI init | ✅ | Manual scaffold with all screens, navigation, services, hooks, types |
| 0.4 | Docker Compose | ✅ | PostgreSQL 16 + Redis 7 + Go backend with hot-reload |
| 0.5 | CI/CD skeleton | ✅ | GitHub Actions: lint, build for server |
| 0.6 | Linting & formatting | ✅ | golangci-lint configured for Go backend with 20+ linters. ESLint + Prettier for React Native. `Makefile` with `lint`, `build`, `test` targets. All lint issues fixed. |

---

## Phase 1: Backend Infrastructure & Database
**Duration: Week 2–4**

### Objectives
- PostgreSQL schema with migrations
- JWT authentication with device fingerprinting
- Movie catalog API with caching
- DHT bootstrap node

### Tasks

| # | Ticket | Status | Acceptance Criteria |
|---|--------|--------|---------------------|
| 1.1 | PostgreSQL schema & migrations | ✅ | `init.sql` with tables: `movies`, `video_sources`, `subtitles`, `users`, `watch_history`, `bookmarks` + seed data |
| 1.2 | JWT auth + device fingerprinting | ✅ | `golang-jwt/jwt/v5` middleware, protected endpoints return 401, device fingerprint binding |
| 1.3 | Movie catalog API | ✅ | `GET /api/v1/movies` paginated, search, trending, recent. Full-text search with GIN index |
| 1.4 | DHT bootstrap node | ✅ | `internal/dht/` with peer tracking, announce handling, HTTP API, cleanup goroutine |
| 1.5 | Health check + monitoring | ✅ | `GET /health`, `slog` structured logging, request ID, panic recovery middleware |
| 1.6 | Seed data pipeline | ✅ | 5 sample movies with metadata in `init.sql` |
| 1.7 | API documentation | ⬜ | Swagger/OpenAPI spec for all endpoints — **not yet started** |

### Database Schema

```sql
-- Users
CREATE TABLE users (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    email VARCHAR(255) UNIQUE NOT NULL,
    password_hash VARCHAR(255) NOT NULL,
    display_name VARCHAR(100),
    device_fingerprint VARCHAR(255),
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Movies
CREATE TABLE movies (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    title VARCHAR(500) NOT NULL,
    description TEXT,
    release_year INTEGER,
    genre VARCHAR(100)[],
    poster_url TEXT,
    backdrop_url TEXT,
    duration_minutes INTEGER,
    rating DECIMAL(3,1),
    info_hash VARCHAR(40), -- torrent info hash
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_movies_title ON movies USING GIN (to_tsvector('english', title));
CREATE INDEX idx_movies_year ON movies (release_year);
CREATE INDEX idx_movies_genre ON movies USING GIN (genre);

-- Video Sources
CREATE TABLE video_sources (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    movie_id UUID REFERENCES movies(id) ON DELETE CASCADE,
    quality VARCHAR(10), -- 720p, 1080p, 4K
    magnet_link TEXT,
    file_size_bytes BIGINT,
    codec VARCHAR(50),
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Subtitles
CREATE TABLE subtitles (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    movie_id UUID REFERENCES movies(id) ON DELETE CASCADE,
    language_code VARCHAR(10) NOT NULL,
    language_name VARCHAR(100),
    file_url TEXT,
    format VARCHAR(10), -- srt, vtt
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Watch History
CREATE TABLE watch_history (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES users(id) ON DELETE CASCADE,
    movie_id UUID REFERENCES movies(id) ON DELETE CASCADE,
    progress_seconds INTEGER DEFAULT 0,
    completed BOOLEAN DEFAULT FALSE,
    last_watched_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(user_id, movie_id)
);

-- Bookmarks
CREATE TABLE bookmarks (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES users(id) ON DELETE CASCADE,
    movie_id UUID REFERENCES movies(id) ON DELETE CASCADE,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(user_id, movie_id)
);
```

---

## Phase 2: React Native Client Core
**Duration: Week 4–6**

### Objectives
- Navigation stack with core screens
- Local offline database (WatermelonDB)
- Secure token storage
- API client with offline-first data layer
- Design system / UI components

### Tasks

| # | Ticket | Status | Acceptance Criteria |
|---|--------|--------|---------------------|
| 2.1 | Navigation stack | ✅ | React Navigation v7 native stack. Auth flow (Login/Register), tab navigator (Home, Search, Vault, Settings), modal screens (MovieDetail, Player) |
| 2.2 | Local database | ✅ | **OP-SQLite + Drizzle ORM** — JSI-based SQLite (5-8x faster than bridge alternatives). Schema: `cached_movies`, `cached_bookmarks`, `cached_watch_history`. Cache-first hooks with 30min TTL. `react-native-sqlite-storage` removed. |
| 2.3 | Secure storage | ✅ | `react-native-encrypted-storage` used for JWT tokens + device fingerprints in `authService.ts` and `api.ts` |
| 2.4 | API client layer | ✅ | Axios + TanStack Query with request/response interceptors, JWT auth, 401 handling, `useMovies` hooks |
| 2.5 | Design system | ✅ | Full theme system (`COLORS`, `SPACING`, `FONT_SIZE`, `RADIUS`, `SHADOWS`, `LAYOUT`). Components: `MovieCard`, `GenreChip`, `LoadingSpinner`, `SectionHeader`, `EmptyState` |
| 2.6 | Offline-first sync | 🟡 | Cache-first pattern implemented (API → SQLite cache → serve offline). Full bidirectional sync with conflict resolution deferred to Phase 3. |
| 2.7 | Home Feed screen | ✅ | Hero billboard, genre filter chips, trending/recent rows, pull-to-refresh, skeleton loading |
| 2.8 | Movie Detail screen | ✅ | Backdrop hero, rating, year, duration, genres, play/download/bookmark/share actions, quality sources, subtitles |
| 2.9 | Settings screen | ✅ | Account, download settings (auto-download toggle, quality, cache), playback, about, privacy policy, terms, licenses |
| 2.10 | Search screen | ✅ | Search bar, 2-column grid results, real-time query with debounced API calls |
| 2.11 | Auth screens | ✅ | Login (email/password with show/hide toggle) and Register (email/password/confirm/display name) |
| 2.12 | Player screen (UI shell) | 🟡 | Custom controls: play/pause, seek bar, skip, volume, subtitles, fullscreen, auto-hide. **No actual `react-native-video` integration yet — placeholder UI only** |

---

## Phase 3: P2P Engine & Offline Storage Vault
**Duration: Week 6–10** ⚠️ Critical Path

### Objectives
- Compile Go torrent engine to Android native library
- Android Foreground Service for background P2P
- Local HTTP proxy for streaming
- AES chunk encryption
- Smart storage management

### Tasks

| # | Ticket | Status | Acceptance Criteria |
|---|--------|--------|---------------------|
| 3.1 | Rust torrent engine crate | ✅ | `peerplay-torrent-engine` crate: `librqbit 9.0` + `warp 0.3` HTTP proxy + UniFFI 0.28 annotations. **Cross-compiled to 3 Android architectures via NDK r27c.** .so files in `jniLibs/`. |
| 3.2 | UniFFI + React Native bindings | 🟡 | TypeScript Turbo Module interface (`TorrentEngineNative.ts`), high-level wrapper (`TorrentEngine.ts`), `useTorrentEngine` hook. Kotlin bridge module + package created. Awaiting JNI binding generation from `.so`. |
| 3.3 | Local HTTP proxy server | ✅ | Warp-based proxy in Rust (`proxy.rs`) — `GET /stream/{id}`, `GET /health`, `GET /torrents`. Built and compiled into `.so`. Wired to PlayerScreen. |
| 3.4 | Android native module | ✅ | Kotlin `PeerplayTorrentEngineModule` + `PeerplayTorrentEnginePackage` registered in `MainApplication.kt`. `.so` files in `jniLibs/{arm64-v8a,armeabi-v7a,x86_64}/`. |
| 3.5 | React Native hook | ✅ | `useTorrentEngine()` — engine lifecycle, `addTorrent()`, `removeTorrent()`, `getStreamUrl()`, pause/resume, automatic stream URL resolution. Connected to PlayerScreen. |
| 3.6 | Android Foreground Service | ⬜ | Native Android service wrapping Rust daemon. Runs with persistent notification |
| 3.7 | Protocol encryption (PE/MSE) | ⬜ | Encryption negotiated during peer handshakes. Prevents ISP throttling |
| 3.8 | AES chunk encryption writer | ⬜ | Downloaded chunks encrypted with local AES-256 keys before disk write |
| 3.9 | Smart storage monitor | ⬜ | Background disk space check. Auto-pause at 500MB. Cache purge UI |
| 3.10 | Download manager | ⬜ | Queue system, progress tracking, pause/resume/cancel per download |

### Architecture: Local Proxy Daemon Pattern

```
React Native App
    │
    ├── JS Layer (UI + State)
    │       │
    │       ├── react-native-video ──► http://127.0.0.1:8491/stream/{id}
    │       │                              │
    │       ├── useTorrentEngine() hook    │
    │       │       │                      │
    │       └── Native Bridge (Turbo Module)
    │               │                      │
    │               ▼                      ▼
    │         ┌─────────────────────────────┐
    │         │  Rust Torrent Engine        │
    │         │  (UniFFI → JNI → .so)       │
    │         │                             │
    │         │  • librqbit (DHT + streaming)│
    │         │  • warp HTTP proxy server   │
    │         │  • PE/MSE encryption        │
    │         │  • AES-256 chunk writer     │
    │         └─────────────────────────────┘
    │
    └── OP-SQLite + Drizzle ORM (Offline Metadata)
```

---

## Phase 4: Video Player & Subtitles
**Duration: Week 10–12**

### Objectives
- Full-featured video player with custom controls
- Multi-language subtitle support
- Audio track switching
- End-to-end offline verification

### Tasks

| # | Ticket | Status | Acceptance Criteria |
|---|--------|--------|---------------------|
| 4.1 | react-native-video integration | 🟡 | `react-native-video` connected to PlayerScreen with `<Video>` component, ExoPlayer on Android. Demo URL active. **Needs real stream URL from torrent daemon** |
| 4.2 | Custom player UI | ✅ | Full custom controls: play/pause, seek bar with thumb, skip ±15s, restart, volume, subtitles, fullscreen buttons, auto-hide after 3s, buffering indicator. Connected to real `<Video>` ref |
| 4.3 | Subtitle manager | ⬜ | `.srt`/`.vtt` side-loading. Multi-language toggle. Download missing packs locally |
| 4.4 | Audio track switching | ⬜ | Multiple audio tracks in containers. Language selector in player |
| 4.5 | Offline playback test | ⬜ | Full integration: airplane mode → browse → play from local vault. No crashes |
| 4.6 | Background audio | ⬜ | Audio continues when app is backgrounded (Android notification controls) |

---

## Phase 5: Polish & Play Store Preparation
**Duration: Week 12–14**

### Objectives
- App store assets and metadata
- Android signing and release configuration
- Privacy policy and content declarations
- Performance optimization

### Tasks

| # | Task | Status | Details |
|---|------|--------|---------|
| 5.1 | App icon + splash screen | ⬜ | High-quality adaptive icon, branded splash |
| 5.2 | Privacy policy | ⬜ | Hosted URL, linked in app Settings + Play Console |
| 5.3 | Android signing | ⬜ | Generate upload keystore. Configure Gradle. Enable Play App Signing |
| 5.4 | Target SDK 36 | ⬜ | Android 16 (API 36) — required by Aug 2026 |
| 5.5 | Data Safety form | ⬜ | Complete Play Console data disclosure questionnaire |
| 5.6 | Permissions Declaration | ⬜ | Justify P2P, network, and storage permissions |
| 5.7 | Content policy framing | ⬜ | Position as legal media distribution. No piracy features |
| 5.8 | Performance profiling | ⬜ | Memory during P2P, battery impact, storage I/O benchmarks |
| 5.9 | Release build optimization | ⬜ | ProGuard, bundle splitting, asset optimization |

---

## Phase 6: Testing & Launch
**Duration: Week 14–16**

### Objectives
- Closed testing with real users
- Device matrix validation
- Security audit
- Production release

### Tasks

| # | Task | Status | Details |
|---|------|--------|---------|
| 6.1 | Closed testing | ⬜ | 20 testers × 14 days (mandatory for new Play Console accounts) |
| 6.2 | Device matrix | ⬜ | Test on budget Android devices (common in target markets) |
| 6.3 | P2P stress test | ⬜ | Multiple concurrent downloads, swarm behavior, network interruption |
| 6.4 | Security audit | ⬜ | AES verification, token storage, sandbox isolation, pen test |
| 6.5 | Staged rollout | ⬜ | 5% → 20% → 50% → 100% over 7 days |
| 6.6 | Post-launch monitoring | ⬜ | Crash reporting (Sentry), analytics, user feedback pipeline |

---

## Tech Stack Decisions

| Component | Choice | Rationale |
|-----------|--------|-----------|
| Backend Language | Go 1.26 | Performance, concurrency, `anacrolix/torrent` library |
| HTTP Router | go-chi | Lightweight, idiomatic, middleware-friendly |
| Database | PostgreSQL 16 | Full-text search, JSON support, mature ecosystem |
| Cache | Redis 7 | Trending lists, session store, rate limiting |
| Migrations | golang-migrate | Simple, CLI-friendly, supports up/down |
| Auth | golang-jwt/jwt/v5 | Standard JWT with device fingerprint binding |
| Mobile Framework | React Native CLI | Bare workflow for native module access |
| Local DB | OP-SQLite + Drizzle ORM | JSI-based (5-8x faster), full RN 0.76+ support, type-safe schema, actively maintained |
| Video Player | react-native-video | Most mature RN video player |
| Torrent Engine | librqbit (Rust) via UniFFI | High-performance, small binary (~2-6MB), DHT + streaming support |
| Native Bridge | UniFFI → JNI → Turbo Module | Auto-generated TypeScript + Kotlin bindings from Rust |
| Encryption | AES-256-GCM | Industry standard for local file encryption |
| Android Target | API 36 (Android 16) | Play Store requirement by Aug 2026 |

---

## Key Risks & Mitigations

| Risk | Impact | Mitigation |
|------|--------|------------|
| P2P library not compiling for Android | ✅ Resolved | librqbit 9.0 compiled via Rust + cargo-ndk to 3 Android architectures. 21MB arm64-v8a .so in jniLibs. |
| Play Store rejects torrent app | 🔴 Blocker | Frame as "decentralized media platform". No built-in piracy tools. Legal content only |
| WatermelonDB RN 0.76+ incompatibility | ✅ Resolved | Switched to OP-SQLite + Drizzle ORM — no compatibility issues |
| Battery drain from P2P daemon | 🟡 Medium | Foreground service with smart scheduling. Pause when battery < 20% |
| App size bloat from Go binary | 🟡 Medium | Strip debug symbols, use UPX compression, AAB dynamic delivery |

---

## Milestones

| Milestone | Target Date | Deliverable |
|-----------|-------------|-------------|
| M0: Project Scaffold | Week 2 | Running Go server + empty RN app in Docker |
| M1: Backend MVP | Week 4 | Auth + catalog API working with seeded data |
| M2: Mobile MVP | Week 6 | App with navigation, offline DB, API integration |
| M3: P2P Alpha | Week 10 | Torrent streaming working on single Android device |
| M4: Feature Complete | Week 12 | Full player, subtitles, offline vault |
| M5: Beta Release | Week 14 | Closed testing build on Play Console |
| M6: Production Launch | Week 16 | Public Play Store release |

---

*Last updated: August 27, 2026*
*Generated with Codebuff 🤖*

---

## Cleanup Needed

| Item | Priority | Details |
|------|----------|---------|
| `mobile/PeerPlayScaffold/` | ✅ | **Deleted** (August 27, 2026) |
| `mobile/App.tsx` | ✅ | Was already correct — actual app entry is `mobile/index.js` → `mobile/src/` |
| `babel.config.js` | ✅ | Fixed broken `import`/`module.exports` mix |
| Metro patches in `node_modules/` | ✅ | **Postinstall script created** (`scripts/postinstall.sh`) — patches persist across `npm install` |

## Missing Backend API Endpoints

| Endpoint | Status | Notes |
|----------|--------|-------|
| `PUT /api/v1/watch-history` | ✅ | Update watch progress (upsert) |
| `DELETE /api/v1/watch-history/:movieId` | ✅ | Delete watch history entry |
| `GET /api/v1/watch-history` | ✅ | List watch history with pagination |
| `POST /api/v1/bookmarks` | ✅ | Add bookmark |
| `DELETE /api/v1/bookmarks/:movieId` | ✅ | Remove bookmark |
| `GET /api/v1/bookmarks` | ✅ | List bookmarks with pagination |
| `GET /api/v1/movies/:id/sources` | 🟡 | Fetched inline with `GET /movies/{id}` response |
