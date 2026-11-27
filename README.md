# idac-haruka-bot (Haruka)

A Discord bot for Initial D The Arcade (IDAC). Haruka focuses purely on the game's
`/idac` command surface — it is structurally modeled on `idac-amane-bot` and carries
the `/idac` feature set ported from `mcqueens_tea_cup` (the shitpost / anonymous-message
commands are intentionally left out).

## Features

`/idac` subcommands:
- **time-attack** — Time Attack rankings by track, with optional car / spec / country filters.
- **time-attack-compare** — Compare two players' times on a course.
- **team** — Team class & rankings, optionally filtered by country.
- **profile** — A player's rank on a specific course.
- **ob-ranking** — Online Battle rankings, filterable by rank / country / round.
- **ob-meta** — Current Online Battle meta cars.
- **player-info-tournament** — Tournament-oriented player info.
- **track-details** — A track's rank time thresholds.
- **help** — Per-command usage guides (ephemeral).

Plus `/status` (health check), area / car / track **autocomplete**, and
**button pagination** on long result sets.

Background workers (goroutines in `main.go`):
- **OB meta cars sync** — crawls most-used OB cars and posts to a configured channel.
- **OB active players sync** — crawls active OB players and posts to a configured channel.

(Both honor configurable downtime windows; the car/style data sync is present but
commented out — enable in `main.go` if needed.)

## Technical Info
- Go, [discordgo](https://github.com/bwmarrin/discordgo), PostgreSQL.
- Game data is fetched from SEGA / All.Net either **directly over HTTP** (default) or
  via the **`sega-idac-client` gRPC service** when `SEGA_IDAC_GRPC_ADDR` is set.

> **Dependency note:** `go.mod` pins `github.com/Duke40199/sega-idac-client` through a
> local `replace => ../sega-idac-client` for pre-publish development. Before deploying,
> publish/tag that module and drop the replace (see the comment in `go.mod`).

## Getting Started
```sh
cp .env.example .env   # fill in Discord token, DB creds, SEGA/All.Net paths
go mod tidy
go run ./cmd/haruka
```

## Project Structure
- Design Pattern: Clean / Hexagonal Architecture. Dependencies point inward:
  `adapter` → `domain/port` ← `domain/service`. The domain never imports an
  adapter; `cmd/haruka/main.go` is the composition root that wires everything.
- File structure:
```
idac-haruka-bot/
├── .env.example                 # sample env (real .env is gitignored)
├── Dockerfile / .dockerignore
├── go.mod / go.sum
├── README.md
├── cmd/
│   └── haruka/
│       └── main.go              # entry point / dependency wiring + cron workers
├── internal/
│   ├── adapter/                 # outward edges (DB, HTTP/gRPC clients, Discord)
│   │   ├── client/
│   │   │   ├── all_net/         # All.Net HTTP client
│   │   │   ├── all_net_grpc/    # All.Net gRPC client (sega-idac-client)
│   │   │   ├── sega_idac/       # SEGA IDAC HTTP client
│   │   │   └── sega_idac_grpc/  # SEGA IDAC gRPC client (sega-idac-client)
│   │   ├── database/
│   │   │   └── postgres.go      # connection pool (NewPostgresDBConn)
│   │   ├── discord/
│   │   │   ├── discord_session.go
│   │   │   ├── dispatch.go      # slash-command lifecycle (defer → run → reply)
│   │   │   ├── handler_idac*.go # /idac command handlers
│   │   │   ├── handler_help*.go # /idac help + helpers
│   │   │   ├── notifier.go      # port.Notifier impl (channel publishing)
│   │   │   ├── pagination.go    # button-paged messages
│   │   │   ├── router.go / router_definition.go
│   │   │   └── resource/        # embedded assets (unauthorized.gif)
│   │   └── repository/          # port.*Repository impls (Postgres)
│   ├── config/
│   │   └── config.go            # env-driven config (incl. table names, gRPC addr)
│   └── domain/                  # core — no adapter imports
│       ├── entity/              # domain types (idac, cars, views, …)
│       ├── port/                # interfaces: client, repository, notifier, service
│       └── service/             # business logic (sync, meta, player, team, …)
└── pkg/                         # shared, project-agnostic helpers
    ├── logger/                  # slog wrapper (JSON / colored dev console)
    ├── tracer/                  # context-propagated trace IDs
    └── utils/                   # generic helpers (ChunkSlice, …)
```
