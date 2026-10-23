# To-Do App Backend (NestJS)

This folder is a **separate NestJS REST API project**. It is not connected to the
Flutter app yet. The Flutter app stores tasks locally with SQLite and works fully
offline, even when this server is stopped.

## Current purpose

- Provide the starting point for a future task-synchronization API.
- Demonstrate the NestJS module/controller/service structure.
- Stay independent from the Flutter application.

## What is deliberately not here yet

- No task endpoints or business logic.
- No database (PostgreSQL is intentionally not installed or configured).
- No authentication.
- No connection from Flutter to this server.

## Technology

- Node.js
- TypeScript
- NestJS (standard `@nestjs/platform-express` HTTP adapter — Nest code only,
  no Express routes are written directly)
- REST-style architecture, ready for future controllers

## Structure

```text
backend/
├── src/
│   ├── main.ts            # Starts the HTTP server (default port 3000)
│   ├── app.module.ts      # Root module; future feature modules go here
│   ├── app.controller.ts  # Handles incoming HTTP routes
│   ├── app.service.ts     # Business logic used by the controller
│   └── app.controller.spec.ts
├── test/
│   └── app.e2e-spec.ts    # End-to-end HTTP test
├── nest-cli.json          # Nest CLI configuration
├── package.json           # Dependencies and scripts
├── tsconfig.json          # TypeScript configuration
└── README.md
```

NestJS organizes code in three main building blocks:

- **Module** (`app.module.ts`): groups related code together.
- **Controller** (`app.controller.ts`): maps HTTP requests such as `GET /`.
- **Service** (`app.service.ts`): contains the actual logic, kept out of controllers.

## Setup

```bash
cd backend
npm install
```

## Run

```bash
npm run start          # start once
npm run start:dev      # start with file watching
```

The server listens on `http://localhost:3000`. `GET /` currently returns
`Hello World!` to confirm that the server is running.

Change the port with an environment variable:

```bash
PORT=3100 npm run start
```

## Build and test

```bash
npm run build
npm test
npm run test:e2e
npm run lint
```

## Future plan

```text
Flutter UI -> TaskService -> local SQLite (offline)
                          -> NestJS REST API (sync) -> PostgreSQL (server)
```

Synchronization is **not implemented**. When it is added, new NestJS modules and
controllers will live in `src/`, and PostgreSQL configuration will be added then.
Keep secrets in `.env` (ignored by Git) and never in Flutter source code.
