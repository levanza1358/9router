import { execFile } from "node:child_process";
import path from "node:path";
import { NextResponse } from "next/server";

export const dynamic = "force-dynamic";
export const revalidate = 0;

const HEADERS = { "Cache-Control": "no-store" };

function getAppDir() {
  return process.env.NINEROUTER_APP_DIR || process.cwd();
}

function getScriptCommand(command) {
  const appDir = getAppDir();
  if (process.platform === "win32") {
    return {
      file: "powershell.exe",
      args: ["-NoProfile", "-ExecutionPolicy", "Bypass", "-File", path.join(appDir, "scripts", "9router.ps1"), command],
      cwd: appDir,
    };
  }
  return {
    file: "bash",
    args: [path.join(appDir, "scripts", "9router.sh"), command],
    cwd: appDir,
  };
}

function runCommand(command) {
  const { file, args, cwd } = getScriptCommand(command);
  return new Promise((resolve) => {
    execFile(file, args, {
      cwd,
      env: {
        ...process.env,
        NINEROUTER_APP_DIR: cwd,
      },
      timeout: 30000,
    }, (error, stdout, stderr) => {
      resolve({
        ok: !error,
        code: error?.code || 0,
        output: String(stdout || "").trim(),
        error: String(stderr || error?.message || "").trim(),
      });
    });
  });
}

function parseEnabled(output) {
  return /Autorun enabled/i.test(output || "");
}

function getPlatformLabel() {
  if (process.platform === "win32") return "windows";
  if (process.platform === "linux") return "linux";
  return process.platform;
}

export async function GET() {
  const result = await runCommand("autorun-status");
  return NextResponse.json({
    success: result.ok,
    enabled: parseEnabled(result.output),
    platform: getPlatformLabel(),
    output: result.output,
    error: result.error,
  }, { headers: HEADERS, status: result.ok ? 200 : 500 });
}

export async function POST(request) {
  const body = await request.json().catch(() => ({}));
  const enabled = body.enabled === true;
  const result = await runCommand(enabled ? "autorun-on" : "autorun-off");
  const status = await runCommand("autorun-status");

  return NextResponse.json({
    success: result.ok,
    enabled: status.ok ? parseEnabled(status.output) : enabled,
    platform: getPlatformLabel(),
    output: [result.output, status.output].filter(Boolean).join("\n"),
    error: [result.error, status.error].filter(Boolean).join("\n"),
  }, { headers: HEADERS, status: result.ok ? 200 : 500 });
}
