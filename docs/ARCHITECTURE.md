# Clip Deck: architecture

Created with the `iphone-app-setup-skill` skill.

## Overview

{{FILL: one paragraph plus a mermaid diagram of the iPhone app, backend services, database and external APIs, and how requests flow between them.}}

## Frontend

- Framework: SwiftUI, iOS 17.0+, XcodeGen
- {{FILL: entry point, navigation structure, feature folders, state management, design system location, API layer, persistence.}}

## Backend

{{FILL: backend tier and why; services (auth, database, storage, functions/routes); how business logic and validation are organised. If there is no backend, say so and why.}}

## Data and access control

{{FILL: where data lives, the main entities, and how access is enforced (RLS / rules / middleware / on-device only).}}

## Communication

{{FILL: how the app reaches the backend (SDK or APIClient), configuration per build (Debug → local, Release → hosted), auth token handling, error handling, timeouts.}}

## Configuration and secrets

| Value | Where it lives | Public? |
|---|---|---|
{{FILL: one row per configuration value or secret, e.g. API_BASE_URL | ios/Config/Debug.xcconfig | yes.}}

## Decisions

| Area | Decision | Why | Alternatives considered |
|---|---|---|---|
{{FILL: one row per major decision: frontend, project generation, persistence, backend, auth, payments, testing.}}

## Deployment (not yet done)

{{FILL: what TestFlight / App Store and hosted backend deployment will need: accounts, signing, hosting, migration commands.}}
