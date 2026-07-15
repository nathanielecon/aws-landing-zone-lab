#!/usr/bin/env node
/**
 * Cursor Cloud worker / orchestrator launcher.
 * Invoked by scripts/Invoke-CursorCloudWorker.ps1 — do not commit secrets.
 */
import { readFileSync, writeFileSync, mkdtempSync, rmSync } from "node:fs";
import { tmpdir } from "node:os";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";
import { Agent, CursorAgentError } from "@cursor/sdk";

const __dirname = dirname(fileURLToPath(import.meta.url));

function usage() {
  console.error(`Usage: node launch.mjs --prompt <text> --repo <url> --ref <branch|sha> [--model <id>] [--role worker|orchestrator] [--auth-gzb64 <b64>] [--wait|--no-wait]

Env:
  CURSOR_API_KEY   required (Cursor Dashboard → Integrations)
`);
}

function parseArgs(argv) {
  const out = {
    prompt: null,
    repo: null,
    ref: null,
    model: "composer-2.5",
    role: "worker",
    authGzb64: null,
    wait: true,
  };
  for (let i = 0; i < argv.length; i++) {
    const a = argv[i];
    const next = () => {
      const v = argv[++i];
      if (v === undefined) throw new Error(`Missing value after ${a}`);
      return v;
    };
    switch (a) {
      case "--prompt":
        out.prompt = next();
        break;
      case "--prompt-file":
        out.prompt = readFileSync(next(), "utf8");
        break;
      case "--repo":
        out.repo = next();
        break;
      case "--ref":
        out.ref = next();
        break;
      case "--model":
        out.model = next();
        break;
      case "--role":
        out.role = next().toLowerCase();
        break;
      case "--auth-gzb64":
        out.authGzb64 = next();
        break;
      case "--auth-gzb64-file":
        out.authGzb64 = readFileSync(next(), "utf8").trim();
        break;
      case "--wait":
        out.wait = true;
        break;
      case "--no-wait":
        out.wait = false;
        break;
      case "--help":
      case "-h":
        usage();
        process.exit(0);
        break;
      default:
        throw new Error(`Unknown argument: ${a}`);
    }
  }
  for (const key of ["prompt", "repo", "ref"]) {
    if (!out[key] || !String(out[key]).trim()) {
      throw new Error(`Required: --${key}`);
    }
  }
  if (out.role !== "worker" && out.role !== "orchestrator") {
    throw new Error(`--role must be worker|orchestrator (got ${out.role})`);
  }
  if (out.role === "orchestrator") {
    if (!out.authGzb64 || !out.authGzb64.trim()) {
      throw new Error("Orchestrator role requires --auth-gzb64 or --auth-gzb64-file");
    }
    if (out.authGzb64.length > 4096) {
      throw new Error(
        `auth gzb64 length ${out.authGzb64.length} exceeds Cursor SDK envVars 4096-byte limit`
      );
    }
  }
  return out;
}

function loadMarkdown(name) {
  return readFileSync(join(__dirname, name), "utf8").trim();
}

function buildMessage(role, userPrompt) {
  if (role === "orchestrator") {
    const constraints = loadMarkdown("ORCHESTRATOR_CONSTRAINTS.md");
    return `${constraints}

---

## Task

First, bootstrap Codex auth (do not print secrets):

\`\`\`powershell
pwsh -NoLogo -NoProfile -File scripts/codex-cloud-worker/Install-CodexAuthFromEnv.ps1
\`\`\`

Then execute:

${userPrompt.trim()}

When finished, if you used Codex auth:

\`\`\`powershell
pwsh -NoLogo -NoProfile -File scripts/codex-cloud-worker/Export-CodexAuthArtifact.ps1
\`\`\`
`;
  }
  const constraints = loadMarkdown("WORKER_CONSTRAINTS.md");
  return `${constraints}\n\n---\n\n## Task\n\n${userPrompt.trim()}\n`;
}

function printJson(obj) {
  process.stdout.write(`${JSON.stringify(obj, null, 2)}\n`);
}

function dashboardUrlFor(agentId) {
  return agentId
    ? `https://cursor.com/agents?id=${encodeURIComponent(agentId)}`
    : "https://cursor.com/agents";
}

async function maybeImportWriteback(agent, agentId) {
  try {
    if (typeof agent.listArtifacts !== "function") return null;
    const arts = await agent.listArtifacts();
    const list = Array.isArray(arts) ? arts : arts?.artifacts || [];
    const match = list.find((a) => {
      const p = a.path || a.name || a.uri || "";
      return String(p).includes("codex-auth-writeback.gzb64");
    });
    if (!match) return { imported: false, reason: "no write-back artifact" };
    if (typeof agent.downloadArtifact !== "function") {
      return { imported: false, reason: "downloadArtifact unsupported" };
    }
    const path = match.path || match.name;
    const buf = await agent.downloadArtifact(path);
    const text =
      typeof buf === "string"
        ? buf.trim()
        : Buffer.isBuffer(buf)
          ? buf.toString("utf8").trim()
          : Buffer.from(buf).toString("utf8").trim();
    const outDir = mkdtempSync(join(tmpdir(), "codex-auth-wb-"));
    const outFile = join(outDir, "codex-auth-writeback.gzb64");
    writeFileSync(outFile, text, "utf8");
    return {
      imported: true,
      agentId,
      artifactPath: path,
      localTempPath: outFile,
      note: "Apply via Import-CodexAuthWriteback.ps1 or replace ~/.codex/auth.json from this gzb64.",
    };
  } catch (err) {
    return { imported: false, reason: String(err?.message || err) };
  }
}

async function main() {
  const args = parseArgs(process.argv.slice(2));
  const apiKey = process.env.CURSOR_API_KEY?.trim();
  if (!apiKey) {
    console.error(
      "CURSOR_API_KEY is not set. Create a user key at https://cursor.com/dashboard/integrations and export it (never commit the key)."
    );
    process.exit(1);
  }

  const message = buildMessage(args.role, args.prompt);
  const cloud = {
    repos: [{ url: args.repo, startingRef: args.ref }],
    autoCreatePR: false,
    skipReviewerRequest: true,
  };
  if (args.role === "orchestrator") {
    cloud.envVars = {
      CODEX_AUTH_JSON_GZB64: args.authGzb64.trim(),
    };
  }

  const options = {
    apiKey,
    model: { id: args.model },
    cloud,
  };

  let agent;
  try {
    agent = await Agent.create(options);
    const run = await agent.send(message);
    const agentId = agent.agentId;
    const runId = run.id;
    const dashboardUrl = dashboardUrlFor(agentId);

    if (!args.wait) {
      printJson({
        status: "launched",
        role: args.role,
        agentId,
        runId,
        dashboardUrl,
        model: args.model,
        repo: args.repo,
        startingRef: args.ref,
        wait: false,
        authInjected: args.role === "orchestrator",
        note: "Filter Source → SDK on cursor.com/agents if the run is not listed by default.",
      });
      return;
    }

    const result = await run.wait();
    let writeback = null;
    if (args.role === "orchestrator" && result.status === "finished") {
      writeback = await maybeImportWriteback(agent, agentId);
    }

    printJson({
      status: result.status,
      role: args.role,
      agentId,
      runId: result.id ?? runId,
      dashboardUrl,
      model: result.model?.id ?? args.model,
      repo: args.repo,
      startingRef: args.ref,
      durationMs: result.durationMs ?? null,
      result: result.result ?? null,
      error: result.error ?? null,
      git: result.git ?? null,
      authInjected: args.role === "orchestrator",
      writeback,
      note: "Filter Source → SDK on cursor.com/agents if the run is not listed by default.",
    });
    if (result.status === "finished") process.exitCode = 0;
    else if (result.status === "cancelled") process.exitCode = 3;
    else process.exitCode = 2;
  } catch (err) {
    if (err instanceof CursorAgentError) {
      printJson({
        status: "startup_failed",
        role: args.role,
        message: err.message,
        isRetryable: err.isRetryable ?? null,
        repo: args.repo,
        startingRef: args.ref,
        model: args.model,
      });
      process.exitCode = 1;
      return;
    }
    throw err;
  } finally {
    if (agent && typeof agent[Symbol.asyncDispose] === "function") {
      await agent[Symbol.asyncDispose]();
    } else if (agent && typeof agent.close === "function") {
      await Promise.resolve(agent.close());
    }
  }
}

main().catch((err) => {
  console.error(String(err?.stack || err));
  process.exit(1);
});
