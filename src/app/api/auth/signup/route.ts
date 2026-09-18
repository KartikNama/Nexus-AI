import { NextResponse } from "next/server";
import { z } from "zod";
import { createAdminClient } from "@/lib/supabase/admin";
import { isDemoMode } from "@/lib/app-config";

const signupSchema = z.object({
  name: z.string().min(1).max(120),
  email: z.string().email(),
  password: z.string().min(8).max(128),
  invite: z.string().optional(),
});

export async function POST(request: Request) {
  try {
    if (isDemoMode()) {
      return NextResponse.json({ success: true, message: "Account created (demo mode)" });
    }

    const body = await request.json();
    const { name, email, password } = signupSchema.parse(body);
    const supabase = createAdminClient();

    // 1. Create user in Supabase auth
    const { data, error } = await supabase.auth.admin.createUser({
      email,
      password,
      email_confirm: true,
      user_metadata: {
        full_name: name,
      },
    });

    if (error) {
      const message = error.message.toLowerCase();
      if (message.includes("already") || message.includes("registered")) {
        return NextResponse.json(
          { error: "An account with this email already exists. Try signing in instead." },
          { status: 409 },
        );
      }
      throw error;
    }

    const userId = data.user?.id;
    if (!userId) {
      return NextResponse.json({ error: "Failed to create account" }, { status: 500 });
    }

    // 2. Create user profile
    try {
      await supabase.from("profiles").upsert(
        {
          id: userId,
          email,
          name,
          avatar_url: null,
        },
        { onConflict: "id" },
      );
    } catch (e) {
      console.error("Profile insert failed:", e);
    }

    // 3. Create default workspace and assign user as owner
    try {
      const workspaceName = `${name}'s Workspace`;
      const slug = `${name.toLowerCase().replace(/[^a-z0-9]/g, "-").replace(/-+/g, "-")}-${userId.slice(0, 6)}`;
      
      const { data: ws } = await supabase
        .from("workspaces")
        .insert({
          name: workspaceName,
          slug,
          plan: "free",
        })
        .select("id")
        .single();

      if (ws?.id) {
        await supabase.from("workspace_members").insert({
          workspace_id: ws.id,
          user_id: userId,
          role: "owner",
        });
      }
    } catch (e) {
      console.error("Workspace initialization failed:", e);
    }

    return NextResponse.json({
      success: true,
      message: "Account created successfully! You can now sign in.",
    });
  } catch (error) {
    if (error instanceof z.ZodError) {
      return NextResponse.json({ error: "Invalid request" }, { status: 400 });
    }
    console.error("Signup failed:", error);
    const message = error instanceof Error ? error.message : "Signup failed";
    return NextResponse.json({ error: message }, { status: 500 });
  }
}
