# AI Tooling

How Claude is wired into this project for development assistance.

---

## CLAUDE.md

A `CLAUDE.md` file at the project root gives Claude context about the project whenever it is invoked — stack, conventions, data sources, current pipeline state, and key design decisions. This means Claude does not need to re-derive context from scratch each session.

A second `CLAUDE.md` lives in the `diet_dbt/` subfolder and points to `docs/dbt_conventions.md` as the authoritative source for dbt model conventions.

---

## dbt MCP

The project includes `.mcp.json` at the root, which connects the [dbt MCP server](https://github.com/dbt-labs/dbt-mcp) to Claude Code in VS Code. This allows Claude to run dbt commands (`dbt build`, `dbt test`, `dbt compile`, etc.) directly from chat without switching to the terminal.

### Setup

**1. Check uv is installed**
```bash
uv --version
```
If not installed:
```bash
brew install uv
```

**2. Install dbt-mcp** (first run installs automatically)
```bash
uvx dbt-mcp --help
```

**3. Create `.env.dbt`** in the project root with your local paths
```bash
source venv/bin/activate
which dbt   # copy this output for DBT_PATH below
```
```
DBT_PROJECT_DIR=/absolute/path/to/diet-analytics-engineer/diet_dbt
DBT_PATH=/absolute/path/to/dbt
```
`.env.dbt` is gitignored — each user creates their own. Use `.env.dbt.example` as a reference.

**4. Test it works**
```bash
uvx --env-file .env.dbt dbt-mcp
```
No `WARNING` about CLI features means it is working. `DBT_HOST` warnings are expected — dbt Cloud is not used. Hit `Ctrl+C` to stop.

**5. Open in VS Code**

VS Code picks up `.mcp.json` automatically when you open the project folder. Claude Code will use it from there — no further config needed.

---

## Skills

Three Claude skills live in `.claude/skills/`. Skills are invoked by Claude when the user's request matches their description, and provide step-by-step instructions for completing a task consistently with project conventions.

| Skill | Description |
|---|---|
| `new-model` | Scaffolds a new dbt model SQL file + YAML entry following all project conventions |
| `new-seed` | Creates a seed CSV + `_seeds.yml` entry + optional staging model |
| `check-model` | Reviews an existing model against conventions and reports violations |

### Status and improvements

These skills were created as a first pass and cover the core workflow. Areas to improve:

- **Richer examples** — add example SQL and YAML snippets inside each skill so Claude has a concrete reference, not just rules
- **check-model coverage** — extend to also check seed YAML entries and snapshot conventions
- **Error recovery** — add guidance on common mistakes and how to fix them (e.g. wrong materialization, missing `relationships` test)

### Reference: skills in other repos

Custom skills were created for this project. For reference, official skills also exist for the tools used here:

- [dbt agent skills](https://github.com/dbt-labs/dbt-agent-skills) — skills from dbt Labs covering model creation, testing, documentation, and more
- [Streamlit Claude skills](https://github.com/streamlit/streamlit/tree/develop/.claude/skills) — skills from the Streamlit team for building and debugging Streamlit apps
