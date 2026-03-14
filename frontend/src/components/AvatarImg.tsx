"use client";

import { avatarUrl } from "@/lib/avatars";

export function AvatarImg({ id, size = 40 }: { id: string | number | undefined; size?: number }) {
  return (
    <img
      src={avatarUrl(id, size * 2)}
      alt=""
      width={size}
      height={size}
      style={{ borderRadius: "50%", objectFit: "cover", flexShrink: 0 }}
    />
  );
}
