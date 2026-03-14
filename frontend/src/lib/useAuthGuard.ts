"use client";

import { useEffect } from "react";
import { useRouter } from "next/navigation";
import { useAuthStore } from "@/store/authStore";

/**
 * Redirect to /verify if not authenticated, or /profile if profile not set.
 * Returns { ready, token, sessionId, username } — `ready` is true once
 * hydration is complete and the user has a valid session + profile.
 */
export function useAuthGuard({ requireUsername = true } = {}) {
  const router = useRouter();
  const { token, sessionId, username, _hasHydrated } = useAuthStore();

  useEffect(() => {
    if (!_hasHydrated) return;
    if (!token) { router.push("/verify"); return; }
    if (requireUsername && !username) { router.push("/profile"); return; }
  }, [_hasHydrated, token, username, requireUsername, router]);

  const ready = _hasHydrated && !!token && (!requireUsername || !!username);
  return { ready, token: token!, sessionId: sessionId!, username: username! };
}
