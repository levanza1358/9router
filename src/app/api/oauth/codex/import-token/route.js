import { NextResponse } from "next/server";
import { createProviderConnection } from "@/models";
import { extractCodexAccountInfo } from "@/lib/oauth/providers";

/**
 * POST /api/oauth/codex/import-token
 * Import a ChatGPT access token or exported Codex JSON as a provider connection.
 *
 * Body: { accessToken: string, refreshToken?: string, idToken?: string, email?: string, tokenSource?: string, name?: string }
 * Also accepts snake_case fields from exported JSON.
 */
export async function POST(request) {
  try {
    const body = await request.json();
    const accessToken = body.accessToken || body.access_token;
    const refreshToken = body.refreshToken || body.refresh_token;
    const idToken = body.idToken || body.id_token;
    const tokenSource = body.tokenSource || body.token_source;
    const name = body.name;
    const importedEmail = body.email;
    const savedAt = body.savedAt || body.saved_at;

    if (!accessToken || typeof accessToken !== "string") {
      return NextResponse.json(
        { error: "Access token is required" },
        { status: 400 }
      );
    }

    const token = accessToken.trim();

    // Extract account info from the JWT (email, workspace, plan)
    let email = importedEmail || null;
    let expiresAt = null;
    const authMethod = refreshToken ? "imported_oauth_json" : "access_token";
    let providerSpecificData = { authMethod };
    if (tokenSource) providerSpecificData.tokenSource = tokenSource;
    if (savedAt) providerSpecificData.sourceSavedAt = savedAt;
    providerSpecificData.importedAt = new Date().toISOString();

    const applyJwtClaims = (jwt) => {
      if (!jwt || typeof jwt !== "string") return;
      const parts = jwt.split(".");
      if (parts.length !== 3) return;
      const base64 = parts[1].replace(/-/g, "+").replace(/_/g, "/");
      const missingPadding = (4 - (base64.length % 4)) % 4;
      const padded = base64 + "=".repeat(missingPadding);
      const payload = JSON.parse(Buffer.from(padded, "base64").toString("utf8"));

      const auth = payload["https://api.openai.com/auth"] || {};
      const profile = payload["https://api.openai.com/profile"] || {};
      email = email || profile.email || payload.email || payload.preferred_username || null;

      if (auth.chatgpt_account_id) {
        providerSpecificData.chatgptAccountId = auth.chatgpt_account_id;
      }
      if (auth.chatgpt_plan_type) {
        providerSpecificData.chatgptPlanType = auth.chatgpt_plan_type;
      }

      if (payload.exp) {
        providerSpecificData.jwtExp = payload.exp;
        expiresAt = expiresAt || new Date(payload.exp * 1000).toISOString();
      }
    };

    // Try decoding as JWT to extract email + workspace
    try {
      applyJwtClaims(idToken || token);
    } catch {
      // Not a JWT or malformed — still allow import as raw token
    }

    // Also try extractCodexAccountInfo via id_token-style extraction
    // (the access token itself may contain the same claims)
    if (!email) {
      const info = extractCodexAccountInfo(idToken || token);
      if (info.email) email = info.email;
      if (info.chatgptAccountId) providerSpecificData.chatgptAccountId = info.chatgptAccountId;
      if (info.chatgptPlanType) providerSpecificData.chatgptPlanType = info.chatgptPlanType;
    }

    const connectionName = name || email || (refreshToken ? "ChatGPT Imported Account" : "ChatGPT Access Token");

    const connection = await createProviderConnection({
      provider: "codex",
      authType: refreshToken ? "oauth" : "access_token",
      accessToken: token,
      refreshToken,
      idToken,
      expiresAt,
      name: connectionName,
      email: email,
      providerSpecificData,
      testStatus: "active",
    });

    return NextResponse.json({
      success: true,
      connection: {
        id: connection.id,
        provider: connection.provider,
        email: connection.email,
        name: connection.name,
        workspace: providerSpecificData.chatgptAccountId || null,
        plan: providerSpecificData.chatgptPlanType || null,
      },
    });
  } catch (error) {
    console.log("Codex access token import error:", error);
    return NextResponse.json({ error: error.message }, { status: 500 });
  }
}
