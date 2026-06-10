import { NextResponse } from "next/server";
import { deleteProviderConnection, deleteProviderConnectionsByProvider } from "@/models";

export const dynamic = "force-dynamic";

export async function DELETE(request) {
  try {
    const body = await request.json().catch(() => ({}));
    const { ids, providerId } = body;

    // Delete all connections for a specific provider
    if (providerId && !ids) {
      const count = await deleteProviderConnectionsByProvider(providerId);
      return NextResponse.json({ deleted: count });
    }

    // Delete specific connection IDs
    if (Array.isArray(ids) && ids.length > 0) {
      for (const id of ids) {
        await deleteProviderConnection(id);
      }
      return NextResponse.json({ deleted: ids.length });
    }

    return NextResponse.json({ error: "Provide ids[] or providerId" }, { status: 400 });
  } catch (error) {
    console.log("Error bulk deleting connections:", error);
    return NextResponse.json({ error: "Failed to delete connections" }, { status: 500 });
  }
}
