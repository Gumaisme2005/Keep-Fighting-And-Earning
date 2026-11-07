# Git Workflow and Repository Guidelines

## 1. Branching Strategy

### 1.1. Development Branch (`development` / `dev`)
- **Role:** Main integration and development branch for the entire project. All new features and bug fixes must be integrated here first.
- **Workflow:**
  - Direct push to the development branch is strictly prohibited.
  - Create working branches branched from `development`:
    - New feature: `feat/<feature-name>` (e.g., `feat/user-auth`)
    - Bug fix: `fix/<bug-name>` (e.g., `fix/login-crash`)
  - Once completed, submit a Pull Request (PR) targeting the `development` branch.
  - The `development` branch may contain test suites, mock data, unit tests, and internal testing fixtures.

### 1.2. Production Branch (`main`)
- **Role:** Production branch containing stable, verified, release-ready code.
- **Strict Rules:**
  - Direct commit or push to `main` is strictly prohibited.
  - **Source Code Only - No Tests:** Test files (unit tests, mock data, temporary test scripts, debug files) must not be pushed to `main`. Prior to merging into `main`, audit and separate/exclude test files from the production release.
  - Merge into `main` only from `development` through a Pull Request that has been reviewed and approved by the Tech Lead / Maintainer.
  - Every merge into `main` must be tagged with a semantic version (e.g., `v1.0.0`, `v1.0.1`).

---

## 2. Commit Message Conventions

Commit messages must follow the standard Conventional Commits format:

```text
<type>: <short description>
```

- `feat`: Add a new feature (e.g., `feat: integrate payment gateway`)
- `fix`: Bug fix (e.g., `fix: resolve crash on character select`)
- `refactor`: Code refactoring without changing functionality
- `style`: Formatting, whitespace, minor UI/CSS styling
- `docs`: Documentation updates, README changes
- `chore`: Build configuration, dependencies, routine maintenance

---

## 3. Pull Request (PR) Workflow

1. Prior to creating a PR, pull the latest changes from `development` into the working branch and resolve any conflicts.
2. Create a PR targeting `development` with a concise description explaining what changes were made and key considerations for reviewers.
3. At least one team member must review and approve before merging.
4. Delete feature or fix branches (`feat/*`, `fix/*`) after successful merge to keep the repository clean.
5. Always inspect staged files using `git status` and `git diff` before committing to prevent committing untracked artifacts, environment files (`.env`), credentials, or test files to critical branches.

