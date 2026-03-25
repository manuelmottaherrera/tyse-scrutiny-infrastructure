# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Infrastructure repository for **Tyse Scrutiny**, a microservices-based document processing system. Manages Docker compositions, deployment scripts, and configuration for three environments: local dev, containerized dev, and a dev server (192.168.0.58).

## Architecture

**Microservices** (all Java 17 / Spring Boot):
- **Gateway** (8080) — API Gateway + React frontend (webpack dev on 9000)
- **Divipol** (8081) — Microservice
- **Scrutiny** (8084) — Microservice
- **Notification** (8085) — Email/notification service

**Infrastructure services**: Consul (service discovery + config), Kafka (KRaft mode, event streaming), MinIO (S3-compatible object storage), PostgreSQL (separate DB per microservice), MailHog (dev email capture).

**Event-driven via Kafka topics**: `e14-pdf-uploaded`, `e14-ocr-completed`, `e14-data-cleaned`, `e14-anomaly-detected`, `e14-processing-status`, `notification-request`.

**Shared configuration** lives in Consul K/V store (`consul/central-server-config/application.yml`), including JWT secrets.

## Three Development Environments

### 1. Local (`/docker-compose.yml`) — Requires Java 17 + Maven locally
```bash
docker compose up -d          # Start infrastructure (Consul, Kafka, MinIO, MailHog)
docker compose down            # Stop all
```
Microservices run locally with `./mvnw` from their respective repos.

### 2. Docker-Containerized (`/docker-dev/`) — No local Java/Maven/Node needed
```bash
cd docker-dev
./start.sh                     # Start everything (~10-15 min first build)
./start.sh gateway             # Start only gateway + dependencies
./logs.sh gateway-backend      # View service logs
./stop.sh                      # Stop everything
```
Hot reload via Spring DevTools + Webpack HMR. Shared Maven/npm cache volumes.

### 3. Dev Server (`/dev/`) — Full deployment to 192.168.0.58

Deployment is managed exclusively via GitHub Actions (`Deploy to Dev Server` workflow).
- **Automatic**: push to `develop` affecting `dev/*`
- **Manual**: workflow dispatch with service selection (all, gateway, divipol, scrutiny, notification)

## CI/CD

GitHub Actions workflow (`.github/workflows/deploy-dev.yml`):
- Runs on self-hosted runner
- Triggers: manual dispatch (with service selection) or push to `develop` affecting `dev/*`
- Pulls images from `ghcr.io`, manages `.env.dev` from GitHub secrets
- Runs health checks post-deploy

## Git Conventions

- **Branches**: `main` (production), `develop` (integration), `feature/name-description`, `hotfix/name`
- **Commits**: `type(scope): description` — types: feat, fix, docs, style, refactor, test, chore
- **Protected branches**: No direct pushes to main/develop; PRs require 1+ approval + CI pass
- **Code owner**: @manuelmottaherrera reviews all changes

## Key Restrictions

- Do not modify CI configuration (`.github/workflows/`) without explicit approval
- Never commit `.env` files — only `.env.example` templates
- Never commit credentials or secrets
- No force pushes on shared branches
- Nginx config uses Docker DNS resolver (`127.0.0.11`) for dynamic upstream resolution
- Dev server nginx listens on port 8090 (to avoid conflict with host nginx)
