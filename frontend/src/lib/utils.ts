import { RoomSummary } from "./api";

export function timeAgo(postedAt: string | number): string {
  const secs = Math.floor(Date.now() / 1000) - Number(postedAt);
  if (secs < 60) return "just now";
  if (secs < 3600) return `${Math.floor(secs / 60)}m ago`;
  return `${Math.floor(secs / 3600)}h ago`;
}

export function formatTime(ts: number): string {
  return new Date(ts * 1000).toLocaleTimeString([], { hour: "2-digit", minute: "2-digit" });
}

export function groupRoomsByPeer(rooms: RoomSummary[]) {
  const grouped = new Map<string, { latest: RoomSummary; count: number }>();
  for (const room of rooms) {
    const key = room.peer_session_id || room.peer_username || room.room_id;
    const existing = grouped.get(key);
    if (existing) {
      existing.count += 1;
      const existingTs = Number(existing.latest.started_at || existing.latest.matched_at || 0);
      const roomTs = Number(room.started_at || room.matched_at || 0);
      if (roomTs > existingTs) {
        existing.latest = room;
      }
      continue;
    }
    grouped.set(key, { latest: room, count: 1 });
  }
  return Array.from(grouped.values());
}
