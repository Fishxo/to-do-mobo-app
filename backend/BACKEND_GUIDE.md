# Backend Guide (NestJS)

This guide explains the actual NestJS project in this `backend/` folder.

## 1. What the backend does

**NestJS** is a framework for building server applications with Node.js and
TypeScript. It organizes code into **modules**, **controllers**, and **services**.

Our Flutter app currently stores tasks locally with SQLite. The backend is a
**separate future REST API** for sharing/synchronizing tasks between devices.
Today it does only one thing:

- It answers `GET /` with the text `Hello World!`.

The Flutter app is **not connected** to this backend. The app makes no HTTP
requests and works fully offline.

Current status:

| Area | Status |
|---|---|
| Basic NestJS server | Implemented |
| `GET /` greeting route | Implemented |
| Task CRUD endpoints | Not implemented |
| Database (SQLite, PostgreSQL, etc.) | Not configured |
| Authentication | Not implemented |
| Flutter-to-backend connection | Not implemented |

NestJS uses its standard `@nestjs/platform-express` HTTP adapter. We do not write
Express routes directly.

## 2. Folder structure

```text
backend/
├── src/
│   ├── main.ts                  # Starts the server
│   ├── app.module.ts            # Root module
│   ├── app.controller.ts        # Handles HTTP routes
│   ├── app.service.ts           # Contains the greeting logic
│   └── app.controller.spec.ts   # Unit test for the controller
├── test/
│   └── app.e2e-spec.ts          # End-to-end test for GET /
├── dist/                        # Generated build output (not source)
├── node_modules/                # Installed packages (not source)
├── nest-cli.json                # Nest CLI and build settings
├── package.json                 # Scripts and dependencies
├── package-lock.json            # Exact installed dependency versions
├── tsconfig.json                # TypeScript compiler settings
├── tsconfig.build.json          # TypeScript settings for building
├── tsconfig.build.tsbuildinfo   # Generated TypeScript build cache
├── vitest.config.ts             # Unit test configuration
├── vitest.config.e2e.ts         # End-to-end test configuration
├── .oxlintrc.json               # Linter rules
├── .prettierrc                  # Formatting rules
├── .npmrc                       # npm install setting (legacy peer deps)
├── .gitignore                   # Files Git should ignore
├── .gitattributes               # Git line-ending settings
├── README.md                    # Short backend setup notes
└── BACKEND_GUIDE.md             # This guide
```

### Important source files

| File | Purpose |
|---|---|
| `src/main.ts` | Creates the NestJS app and starts it on port `3000` by default. |
| `src/app.module.ts` | The root module. It registers `AppController` and `AppService`. |
| `src/app.controller.ts` | Maps incoming HTTP requests to methods. It has one route: `GET /`. |
| `src/app.service.ts` | Contains `getHello()`, which returns `Hello World!`. |
| `src/app.controller.spec.ts` | Tests that the controller returns `Hello World!`. |
| `test/app.e2e-spec.ts` | Starts the app and checks that `GET /` returns HTTP 200. |

### Files that do **not** exist yet

- **DTO files:** none. There are no request bodies because there are no POST/PUT
  endpoints.
- **Database files:** none. There is no TypeORM, Prisma, SQLite, or PostgreSQL
  configuration in this backend.
- **Feature modules:** none. Only the root `AppModule` exists.

### Configuration files

| File | Purpose |
|---|---|
| `package.json` | Lists dependencies and commands such as `start:dev`, `build`, and `test`. |
| `package-lock.json` | Locks dependency versions so installs are repeatable. |
| `nest-cli.json` | Tells the Nest CLI that source code lives in `src/`. |
| `tsconfig.json` | TypeScript compiler options for the project. |
| `tsconfig.build.json` | Build-only TypeScript config; excludes tests. |
| `vitest.config.ts` / `vitest.config.e2e.ts` | Configures unit and end-to-end tests. |
| `.oxlintrc.json` / `.prettierrc` | Lint and formatting rules. |
| `.npmrc` | Sets `legacy-peer-deps=true` so installs work with this npm version. |
| `.gitignore` | Excludes `node_modules`, `dist`, logs, and `.env` secrets from Git. |

## 3. How a request works

This is the actual flow for the only implemented endpoint:

```text
Client (curl now, Flutter later)
        ↓  HTTP GET /
NestJS router
        ↓
AppController.getHello()
        ↓
AppService.getHello()
        ↓  returns "Hello World!"
AppController
        ↓  HTTP 200 response with text "Hello World!"
Client
```

Step by step:

1. The client sends `GET /` to `http://localhost:3000`.
2. The `@Get()` decorator in `app.controller.ts` matches that route.
3. `AppController` calls `AppService.getHello()`.
4. `AppService` returns the string `Hello World!`.
5. NestJS sends that string back as an HTTP response.

There is **no database step** because no database is configured.

## 4. Implemented APIs

| Method | Endpoint | Purpose | Request Body | Response |
|---|---|---|---|---|
| `GET` | `/` | Confirm the server is running | None | `200 OK`, body: `Hello World!` |

### Other endpoint categories

| Category | Status |
|---|---|
| Health check | Not implemented. `GET /` is only a simple greeting, not a health-check route. |
| Authentication | Not implemented. |
| Task CRUD | Not implemented. No task routes exist. |
| Planned endpoints | Future task-synchronization endpoints are planned, but their methods and paths are **not defined in the code yet**. |

## 5. How to run the backend

Run these commands from the Flutter project root:

```bash
# 1. Enter the backend folder
cd backend

# 2. Install dependencies
npm install

# 3. Start the development server
npm run start:dev
```

The server address is:

```text
http://localhost:3000
```

Port `3000` is the default in `src/main.ts`:

```ts
await app.listen(process.env.PORT ?? 3000);
```

You can choose another port with the `PORT` environment variable:

```bash
PORT=3100 npm run start:dev
```

### Test the endpoint

With the server running, open another terminal and run:

```bash
curl -i http://localhost:3000/
```

Expected important parts of the response:

```text
HTTP/1.1 200 OK
Content-Type: text/html; charset=utf-8

Hello World!
```

### Run checks

```bash
npm run build       # Compile TypeScript
npm test            # Unit tests
npm run test:e2e    # End-to-end HTTP test
npm run lint        # Lint the code
```

## 6. How Flutter will connect later

Planned flow:

```text
Flutter Mobile App
        ↓  HTTP requests
NestJS REST API
        ↓
Database (not configured yet)
```

This is **not connected today**. The Flutter app has no backend URL, no HTTP
client, and no API calls. It stores tasks only in its own local SQLite database.

To connect them later, we would need to:

1. Add task endpoints (for example, list/create/update/delete) in NestJS.
2. Add a database and task storage on the server.
3. Add an HTTP data source in Flutter and point it at the server.
4. Handle synchronization between SQLite and the server.

### Important: `localhost` on a phone

On a **physical Android phone**, `localhost` means **the phone itself**, not the
Ubuntu computer running NestJS.

For a real phone, Flutter would need the computer's local network IP address,
such as:

```text
http://192.168.1.50:3000
```

The phone and computer must be on the same network. For the Android emulator, the
special address `10.0.2.2` usually refers to the host computer instead.

## 7. Summary

- This is a minimal NestJS server with one route: `GET /`.
- It has no database, no authentication, and no task endpoints yet.
- It is independent from the Flutter app.
- The Flutter app currently uses local SQLite only.
- The backend is ready to grow into a task-synchronization API later.
