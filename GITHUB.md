# GitHub Features & Best Practices

A research report on native GitHub capabilities worth using in this repo — what each does, why it matters, and any important caveats. Assumes a public repository.

---

## Table of Contents

1. [CI/CD with GitHub Actions](#1-cicd-with-github-actions)
2. [Branch Protection & Rulesets](#2-branch-protection--rulesets)
3. [Pull Request & Issue Templates](#3-pull-request--issue-templates)
4. [CODEOWNERS](#4-codeowners)
5. [Security: Dependabot](#5-security-dependabot)
6. [Security: Secret Scanning](#6-security-secret-scanning)
7. [Security: Code Scanning (CodeQL)](#7-security-code-scanning-codeql)
8. [GitHub Releases](#8-github-releases)
9. [Commit Signing (Verified Commits)](#9-commit-signing-verified-commits)
10. [Auto-Merge](#10-auto-merge)
11. [GitHub Projects](#11-github-projects)
12. [GitHub Copilot](#12-github-copilot)
13. [GitHub CLI (`gh`)](#13-github-cli-gh)
14. [Community Health Files](#14-community-health-files)
15. [Things with Important Caveats](#15-things-with-important-caveats)

---

## 1. CI/CD with GitHub Actions

> **Setup:** Workflow YAML files are committed to `.github/workflows/` — no web UI needed, and version-controlled like any other code. Toggle individual workflows on/off via `gh workflow enable/disable`. **Self-hosted runner** is the exception: it requires physical access to the Mac, running `./config.sh` interactively on that machine (the registration token can be generated via `gh api`, but the runner setup itself is manual, ~1 hour one-time).
>
> **Done:** `.github/workflows/test.yml` — builds and runs unit tests on every push and PR to `main`, using `macos-15` and `iPhone 16 Pro` simulator. The CI job is named `test` (referenced by the ruleset in section 2).

### What it is
A workflow automation system built into GitHub. You define workflows as YAML files in `.github/workflows/`. Workflows trigger on events (push, PR opened, schedule, etc.) and run sequences of jobs on GitHub-hosted or self-hosted machines.

### Value for this project
Even for a solo project, CI is valuable because it catches regressions before they accumulate. Specifically:

- **Run unit tests on every push** — confirms the test suite passes without requiring you to manually run them locally before pushing
- **Enforce the build compiles** — catches Swift syntax or type errors that might not surface until you open Xcode
- **Run on PR, block merge if failing** — keeps `main` always green (pairs with branch protection)

### Workflow file structure
```
.github/
  workflows/
    ci.yml          # build and test
    lint.yml        # SwiftLint or similar
```

### Example workflow
```yaml
name: CI
on:
  push:
    branches: [main]
  pull_request:

jobs:
  test:
    runs-on: macos-15
    steps:
      - uses: actions/checkout@v4
      - name: Build and Test
        run: |
          xcodebuild -scheme lifetrak \
            -destination 'platform=iOS Simulator,name=iPhone 14' \
            test
```

### SwiftLint
SwiftLint (open source, no external service needed) can run as an Actions step to enforce code style. Worth adding early so you don't build up style debt.

---

## 2. Branch Protection & Rulesets

> **Setup — branch protection rules:** No dedicated `gh` command. Use the web UI (Settings → Branches) or script it via `gh api repos/{owner}/{repo}/branches/{branch}/protection` with the REST API. The REST payload is complex JSON; the web UI is much easier for initial setup.
>
> **Setup — rulesets:** Fully supported via `gh ruleset` — `gh ruleset create`, `gh ruleset list`, `gh ruleset view`, `gh ruleset check`, `gh ruleset delete`. No web UI required. Rulesets are the better choice if you want automation.
>
> **Done:** Ruleset `protect-main` (ID 14170816) created via `gh api`. Rules enforced on `main`: requires a PR before merging, requires the `test` CI job to pass, requires review thread resolution, blocks force pushes, prevents branch deletion. `required_approving_review_count` is 0 (appropriate for solo — the CI gate is the meaningful check).

### What it is
Rules that govern what can be pushed to specific branches. GitHub has two overlapping systems:

- **Branch protection rules** (older, per-branch)
- **Rulesets** (newer, more flexible — the recommended approach going forward)

Rulesets can apply to multiple branch patterns, tags, and the full fork network. Multiple rulesets can stack, with the most restrictive rule winning. They also support an "evaluate" mode so you can see what would be enforced before enabling enforcement.

### Value for this project
Even solo, branch protection on `main` is valuable:
- Prevents accidental direct pushes to `main` when you meant to push to a feature branch
- Requires PRs to go through the process you've already established (review, tests passing)
- Blocks force-pushes that would destroy history

### Recommended settings for `main`
- Require pull request before merging
- Require status checks to pass (i.e., CI must be green)
- Require conversation resolution before merging (no unaddressed review comments)
- Block force pushes
- Prevent branch deletion

### Rulesets vs. branch protection
Rulesets are strictly more capable and GitHub is investing in them as the future. If you're setting this up fresh, use rulesets.

---

## 3. Pull Request & Issue Templates

> **Setup:** Commit the files to `.github/` — GitHub detects them automatically. No web UI, no CLI commands needed.
>
> **Done:** `.github/pull_request_template.md` committed.

### What it is
Markdown templates stored in `.github/` that pre-populate the body of new PRs or issues. GitHub automatically uses them when someone opens a PR or issue.

### Value for this project
Templates encode your process so you don't have to remember it. For PRs:
- What does this change do?
- How was it tested?
- Checklist: tests written, build passes, no hardcoded values

For issues:
- Bug report template (steps to reproduce, expected vs. actual)
- Feature request template (motivation, proposed behavior)

### File locations
```
.github/
  pull_request_template.md
  ISSUE_TEMPLATE/
    bug_report.md
    feature_request.md
```

Multiple issue templates are supported; GitHub shows a chooser when opening a new issue.

---

## 4. CODEOWNERS

> **Setup:** Commit `.github/CODEOWNERS` — no web UI needed.

### What it is
A file (`.github/CODEOWNERS`) that maps file paths or directories to GitHub users or teams. When a PR touches those paths, the named owners are automatically added as reviewers.

### Value for this project
Primarily useful in multi-person projects. For a solo project, less immediately applicable — but worth knowing:
- If you ever add collaborators, CODEOWNERS ensures the right people review changes to specific subsystems
- Can be used to auto-assign yourself as reviewer to make the review flow explicit
- Pairs with branch protection to *require* a CODEOWNERS review before merge

### File format
```
# .github/CODEOWNERS
*                    @danfoygel          # default: everything
lifetrak/Data/       @danfoygel          # data layer
```

---

## 5. Security: Dependabot

> **Setup:** Commit `.github/dependabot.yml` — GitHub detects it automatically and begins monitoring. No web UI needed.

### What it is
A GitHub bot that automatically opens PRs to update your dependencies when new versions are released or when a dependency has a known vulnerability.

### Value for this project
This project currently has no third-party dependencies (Apple frameworks only), so Dependabot has limited utility right now. However:
- If you ever add Swift packages (SPM dependencies), Dependabot will monitor them automatically
- Configuring it now costs nothing and means you'll get alerts immediately if dependencies are added later
- The GitHub Actions dependency (action versions like `actions/checkout@v4`) can also be monitored

### Configuration
```yaml
# .github/dependabot.yml
version: 2
updates:
  - package-ecosystem: "swift"
    directory: "/"
    schedule:
      interval: "weekly"
  - package-ecosystem: "github-actions"
    directory: "/"
    schedule:
      interval: "weekly"
```

Dependabot alerts and security updates are free.

---

## 6. Security: Secret Scanning

> **Setup:** Auto-enabled for public repos. Nothing to do.

### What it is
GitHub automatically scans commits for patterns that look like secrets — API keys, tokens, credentials, private keys — and alerts you (and sometimes the affected service) if found.

### Value for this project
Protects against accidentally committing credentials. Even on a personal project, you might at some point add a HealthKit API key, a backend token, or similar. Secret scanning acts as a safety net.

### Push protection
A more proactive mode: GitHub blocks the push entirely if it detects a secret, before it ever enters the repository history. This is significantly better than after-the-fact detection, because once a secret is in git history it's in the history even after you delete it.

Secret scanning and push protection are both free and enabled by default on public repos.

---

## 7. Security: Code Scanning (CodeQL)

> **Setup:** Commit the workflow YAML to `.github/workflows/` — no web UI needed. (GitHub's Security tab also offers a point-and-click wizard that generates the same file, but committing it directly is cleaner and keeps it in version control.)
>
> **Done:** `.github/workflows/codeql.yml` committed. Runs on push/PR to `main` and weekly on Mondays.

### What it is
Static analysis that finds security vulnerabilities and code quality issues in your source code. GitHub's engine is called CodeQL; it understands code semantics, not just patterns, so it catches subtle bugs.

### Value for this project
CodeQL supports Swift as of 2023. It can find issues like:
- Force-unwrapping that could crash
- Improper input validation
- Use of deprecated/insecure APIs
- Common Swift anti-patterns

For an iOS app, the security risk surface is smaller than a server app (no SQL injection, etc.), but CodeQL is still valuable for correctness.

### How it works
You add a workflow that runs CodeQL analysis. Results appear in the Security tab of your repo, with file/line annotations on PRs.

```yaml
# .github/workflows/codeql.yml
name: CodeQL
on:
  push:
    branches: [main]
  pull_request:
  schedule:
    - cron: '0 8 * * 1'  # weekly

jobs:
  analyze:
    runs-on: macos-15  # Swift requires macOS runner
    permissions:
      security-events: write
    steps:
      - uses: actions/checkout@v4
      - uses: github/codeql-action/init@v3
        with:
          languages: swift
      - uses: github/codeql-action/autobuild@v3
      - uses: github/codeql-action/analyze@v3
```

CodeQL is free for public repos.

---

## 8. GitHub Releases

> **Setup:** Fully via CLI — `gh release create v1.0 --generate-notes`. Can also be automated inside an Actions workflow triggered on tag push. No web UI needed.

### What it is
A structured way to publish named versions of your software, with release notes and attached binary artifacts. Releases are built on top of git tags.

### Value for this project
Even for a personal app, releases are useful for:
- Marking meaningful milestones (v1.0 water tracking complete, v2.0 generalized activity tracking)
- Attaching a build artifact (.ipa or .xcarchive) to each release so you can roll back
- Writing changelogs that document what changed and when
- Triggering release-specific workflows (e.g., automatically archive the app when you create a release)

### Workflow integration
You can automate release creation with `gh release create` in a workflow, triggered when a tag is pushed. This is the standard CD pattern.

---

## 9. Commit Signing (Verified Commits)

> **Setup:** Mostly CLI. Key generation is interactive (`gpg --full-generate-key` or `ssh-keygen`). Upload to GitHub: `gh gpg-key add <keyfile>` for GPG, or `gh ssh-key add <keyfile> --type signing` for SSH signing keys. Local git config is CLI commands (`git config --global user.signingkey ...`). The only "manual" part is the interactive key generation prompt — no web UI required.

### What it is
Signing git commits with a GPG or SSH key, which proves the commit actually came from you and wasn't tampered with. GitHub shows a green "Verified" badge on signed commits.

### Value for this project
For a personal project, the primary value is:
- **Learning the practice**: commit signing is increasingly standard in security-conscious projects
- **Supply chain integrity**: if this ever becomes a more serious project, having signed commits from the start establishes provenance
- **Peace of mind**: if your account were ever compromised, unsigned commits from an attacker would be distinguishable from your signed history

### Caveats
There are known friction points: GitHub's web UI signs merges with its own `web-flow` GPG key (which is fine), but the "Rebase and Merge" option on PRs does not preserve commit signatures. If you require signed commits via branch protection, this can block merges. The simplest approach: use "Squash and Merge" or "Merge commit" instead of rebase.

### Setup
```bash
# Generate a key
gpg --full-generate-key

# Tell git to use it
git config --global user.signingkey <KEY_ID>
git config --global commit.gpgsign true

# Add the public key to GitHub: Settings → SSH and GPG keys
```

---

## 10. Auto-Merge

> **Setup — two steps, different methods:**
> 1. **Enable the feature on the repo** (one-time): Web UI required — Settings → General → "Allow auto-merge" checkbox. No `gh` command for this.
> 2. **Enable on a specific PR** (per-PR): CLI — `gh pr merge --auto --squash`.

### What it is
A feature that automatically completes a PR merge once all required status checks pass and required reviews are approved. You enable it per-PR with a button or via `gh pr merge --auto`.

### Value for this project
Removes the manual step of returning to a PR after CI finishes to click merge. Open the PR, mark it for auto-merge, move on. It merges itself when it's ready.

### Caveats
Auto-merge can conflict with required commit signing (see section 9). If you require signed commits on `main`, auto-merge may be automatically disabled by GitHub. Don't combine the two unless you've tested that it works in your setup.

---

## 11. GitHub Projects

> **Setup:** Substantially CLI-driven. Create: `gh project create --owner @me --title "LifeTrak"`. Manage fields: `gh project field-create/list/delete`. Add/edit items: `gh project item-add/edit/list`. The web UI is useful for configuring custom views and drag-and-drop organization, but the core setup doesn't require it.

### What it is
A flexible kanban/spreadsheet project management tool built into GitHub. Issues and PRs can be tracked as cards, with custom fields, views, and workflows. It replaced the older "GitHub Projects Classic."

### Value for this project
The PLAN.md already tracks the roadmap in markdown. GitHub Projects can complement this by:
- Tracking the status of individual issues (backlog → in progress → done)
- Filtering by priority, milestone, or label
- Providing a board view of what's currently in flight

For a solo project, this may be more overhead than it's worth unless you find the visual board helpful. Worth trying when the feature backlog grows large enough that a flat list becomes hard to navigate.


---

## 12. GitHub Copilot

> **Setup:** Web UI required — github.com/settings/copilot. No `gh` command for account-level activation. Once active, the `gh copilot` CLI tool works from the terminal, but enabling the subscription is web-only.

### What it is
An AI pair programmer integrated into your editor. Provides inline code completions, chat, and increasingly agentic capabilities (it can open PRs autonomously when assigned an issue).

### Free tier (as of 2025)
GitHub Copilot Free exists for individuals with limited completions per month. The paid plan (Pro, $10/month) provides unlimited completions and premium model access. Verified students get Pro for free.

### Value for this project
- **Inline completions** work in Xcode (officially supported since 2024)
- **Copilot Chat** can explain Swift APIs, suggest SwiftData patterns, and help debug
- **Copilot coding agent**: You can assign a GitHub issue to Copilot and it will attempt to implement the feature and open a PR — still early but improving rapidly

The free tier is worth enabling and evaluating. If you find yourself frequently using it, the paid plan is inexpensive relative to its productivity benefit.

---

## 13. GitHub CLI (`gh`)

> **Setup:** Already installed on your Mac at `/opt/homebrew/bin/gh`. Authenticate once by running `gh auth login` in Terminal (opens a browser flow). Nothing else needed.

### What it is
The official GitHub command-line tool (`gh`). Already in use in this project. Lets you manage PRs, issues, releases, workflows, and more without leaving the terminal.

### Useful commands to know
```bash
# Work with PRs
gh pr create --title "..." --body "..."
gh pr list
gh pr merge --auto --squash

# Work with issues
gh issue create
gh issue list --label "bug"
gh issue close 42

# Monitor CI
gh run list
gh run watch        # live stream a workflow run
gh run view --log   # full logs

# Create releases
gh release create v1.0 --generate-notes

# GitHub Actions secrets
gh secret set MY_SECRET

# Open anything in the browser
gh browse
gh pr view 12 --web
```

### Scripting and automation
`gh` can be used inside GitHub Actions workflows themselves (it's pre-installed on all runners), so you can do things like automatically label PRs, comment on issues, or trigger other workflows.

---

## 14. Community Health Files

> **Setup:** Commit the files to the repo root or `.github/` — no web UI needed.
>
> **Done:** `SECURITY.md` committed.

### What they are
Standard markdown files that GitHub recognizes and surfaces in the UI. They communicate expectations to anyone visiting the repository.

### Relevant files
- **`SECURITY.md`**: Documents how to report a security vulnerability. GitHub surfaces a "Report a vulnerability" button when this file exists. Establishes responsible disclosure expectations.
- **`CONTRIBUTING.md`**: Documents how to contribute (coding standards, PR process, etc.). Less critical for a solo project but useful if you ever open-source the app or take contributors.
- **`CHANGELOG.md`**: Conventional commit history of user-facing changes, separate from raw git log. Tools like `git-cliff` can generate this automatically from commit messages.
- **`.github/FUNDING.yml`**: Adds a "Sponsor" button to your repo. Probably not relevant for a personal app.

For a personal project, `SECURITY.md` is the one worth adding even now — it's low effort and demonstrates the habit.

---

## 15. Things with Important Caveats

### Merge Queue
> **Setup:** Configured via rulesets (`gh ruleset create`) or branch protection (`gh api`). CLI-scriptable.

A system that batches PRs together and runs CI on the combined result before merging, preventing "works on branch, breaks main" problems. Useful for high-velocity teams. For a solo project, this adds overhead with no real benefit — auto-merge (section 10) is sufficient.

### GitHub Pages
> **Setup:** `gh api` scriptable (`gh api -X PUT /repos/{owner}/{repo}/pages -f build_type=workflow`), or web UI — Settings → Pages.

Free hosting for static websites from a repo. Could host documentation or a landing page for the app. Not relevant until there's something to publish publicly.

### GitHub Discussions
> **Setup:** CLI — `gh repo edit --enable-discussions`. No web UI needed.

A forum built into the repo. Valuable for open-source projects to separate support questions from bug reports. No value for a personal project.

### GitHub Packages
> **Setup:** No special configuration needed. Publishing happens via an Actions workflow (`GITHUB_TOKEN` is automatically available).

A registry for publishing packages (Swift packages, Docker images, etc.). Relevant if this app's shared code ever becomes a reusable library. Not applicable now.

### GitHub Environments and Deployment Protection
> **Setup:** Web UI required to create environments — Settings → Environments. Once created, secrets can be managed via CLI: `gh secret set MY_SECRET --env production`.

Lets you define deployment targets (staging, production) with protection rules and required approvers. Valuable in team settings for controlling who can deploy what. Not applicable for a personal iOS app that distributes via TestFlight/App Store.

### GitHub Wikis
> **Setup:** Web UI required — Settings → Features → Wikis checkbox.

A built-in wiki for documentation. The existing PLAN.md and CLAUDE.md approach in markdown files checked into the repo is generally better — it's versioned, diff-able, and appears in code search. Avoid wikis unless you have a specific need for a separate documentation space.

---

## Recommended Priority Order

**High value, low effort — do these:**
1. Branch protection (via ruleset) on `main`: require PRs and status checks
2. GitHub Actions CI — add `.github/workflows/ci.yml` to build and test on every PR
3. PR template (`.github/pull_request_template.md`)
4. `dependabot.yml` — pays off when any packages are added
5. `SECURITY.md` — good habit, low effort

**Medium value, worth exploring:**
6. SwiftLint as an additional CI check
7. CodeQL — add the workflow file, results appear in the Security tab
8. GitHub Releases — as you hit milestones, start tagging versions
9. GitHub Projects — if/when the issue list gets hard to manage
10. GitHub Copilot free tier — try it, see if completions in Xcode help

**Learn these practices, apply when relevant:**
11. Commit signing — adopt when setting up a new machine
12. Auto-merge — useful quality-of-life once CI is set up
