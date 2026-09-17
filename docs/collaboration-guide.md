# ShramSetu Team Collaboration Guide

This document outlines the collaborative Git workflow for team members working on **ShramSetu** via GitHub.

---

## 1. Branch Structure

The repository provides designated branches for collaborative parallel development:

| Branch Name | Primary Domain | Responsibility | Owner |
|---|---|---|---|
| `main` | **Production / Source of Truth** | Stable, tested, deployable build. All PRs merge here. | Lead Engineer / All |
| `feature/ui` | **Frontend UI / UX** | Customer/Worker/Admin screens, Stitch widgets, design system tokens, responsive layouts. | Collaborator 1 (UI Lead) |
| `feature/backend` | **Backend & Supabase** | Supabase migrations, RLS policies, Edge functions, database schema, payment webhooks. | Collaborator 2 (Backend Lead) |
| `feature/ai-services` | **AI & Core Algorithms** | FairMatch algorithmic allocation, demand forecasting engines, AI service integration. | Collaborator 3 (AI / Core Lead) |

---

## 2. Collaborator Quick Start

### Step 1: Clone the Repository
```bash
git clone https://github.com/DEVESHAMBEKAR/ShramSetu.git
cd ShramSetu
```

### Step 2: Switch to Your Assigned Branch

- **For UI Developer:**
  ```bash
  git checkout feature/ui
  ```

- **For Backend Developer:**
  ```bash
  git checkout feature/backend
  ```

- **For AI / Core Developer:**
  ```bash
  git checkout feature/ai-services
  ```

### Step 3: Verify Environment
```bash
cd app
flutter pub get
flutter test
```
*(All 180 unit & integration tests should pass before starting your work)*

---

## 3. Daily Workflow

### A. Sync Latest Changes from Main
Before starting new work, pull the latest changes from `main`:
```bash
git pull origin main --rebase
```

### B. Making Changes & Committing
```bash
git add <modified-files>
git commit -m "feat(ui): add new booking status animation"
```

### C. Push to GitHub
```bash
# Push directly to your branch
git push origin <your-branch-name>
```

### D. Open a Pull Request (PR)
1. Go to GitHub: `https://github.com/DEVESHAMBEKAR/ShramSetu`
2. Click **Pull Requests** -> **New Pull Request**
3. Select `base: main` <- `compare: <your-branch-name>`
4. Review your diff and submit the PR.
5. Once reviewed and verified, merge into `main`.

---

## 4. Architectural Boundaries (AGENTS.md Rules)
- **UI Developer**: Keep database calls out of UI components; use repositories and services.
- **Backend Developer**: Use Supabase Row Level Security (RLS) on all tables; never expose `service_role` keys.
- **AI Developer**: Ensure FairMatch algorithms remain explainable and decoupled from UI.
