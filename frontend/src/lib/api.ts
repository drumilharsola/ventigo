const HTTP_API = "/api";
const SOCKET_API = process.env.NEXT_PUBLIC_WS_URL ?? process.env.NEXT_PUBLIC_API_URL ?? "http://127.0.0.1:8000";
const REQUEST_TIMEOUT_MS = 8000;

export class AuthError extends Error {
  constructor(detail = "Not authenticated") {
    super(detail);
    this.name = "AuthError";
  }
}

async function request<T>(
  path: string,
  options: RequestInit = {},
  token?: string
): Promise<T> {
  const headers: Record<string, string> = {
    "Content-Type": "application/json",
    ...(options.headers as Record<string, string>),
  };
  if (token) headers["Authorization"] = `Bearer ${token}`;

  let res: Response;
  const controller = new AbortController();
  const timeoutId = window.setTimeout(() => controller.abort(), REQUEST_TIMEOUT_MS);

  try {
    res = await fetch(`${HTTP_API}${path}`, { ...options, headers, signal: controller.signal });
  } catch (error) {
    if (error instanceof DOMException && error.name === "AbortError") {
      throw new Error("The server took too long to respond. Please try again.");
    }
    throw new Error("Cannot reach the server right now. Please try again in a moment.");
  } finally {
    window.clearTimeout(timeoutId);
  }

  if (!res.ok) {
    const err = await res.json().catch(() => ({ detail: res.statusText }));
    if (res.status === 401) throw new AuthError(err.detail ?? "Not authenticated");
    throw new Error(err.detail ?? "Request failed");
  }
  return res.json() as Promise<T>;
}

export interface SpeakerRequest {
  request_id: string;
  session_id: string;
  username: string;
  avatar_id: string;
  posted_at: string;
}

export interface RoomSummary {
  room_id: string;
  status: string;          // "active" | "ended"
  matched_at: string;     // unix timestamp string when the match was created
  started_at: string;     // unix timestamp string
  duration: string;       // session duration in seconds
  ended_at: string;       // unix timestamp string, or ""
  peer_session_id: string;
  peer_username: string;
  peer_avatar_id: number;
}

export interface RoomMessages extends RoomSummary {
  messages: Array<{
    type: "message";
    from: string;
    text: string;
    ts: number;
    client_id?: string;
  }>;
  reactions?: Array<{
    message_client_id: string;
    emoji: string;
    from: string;
    from_session?: string;
    ts: number;
  }>;
}

export interface CurrentSpeakerRequest {
  request_id: string;
  session_id?: string;
  username?: string;
  avatar_id?: string;
  posted_at?: string;
  status?: string;
  room_id?: string;
}

export interface BlockedUser {
  peer_session_id: string;
  username: string;
  avatar_id: number;
  blocked_at: string;
}

export interface ConnectionItem {
  id: number;
  peer_session_id: string;
  peer_username: string;
  peer_avatar_id: number;
  status: string;
  requested_by: string;
  created_at: number;
}

export interface Post {
  post_id: string;
  text: string;
  username: string;
  avatar_id: number;
  session_id: string;
  created_at: number;
  expires_at: number;
}

export const api = {
  register: (email: string, password: string) =>
    request<{ token: string; session_id: string; has_profile: boolean; email_verified: boolean }>(
      "/auth/register",
      { method: "POST", body: JSON.stringify({ email, password }) }
    ),

  login: (email: string, password: string) =>
    request<{ token: string; session_id: string; has_profile: boolean; email_verified: boolean }>(
      "/auth/login",
      { method: "POST", body: JSON.stringify({ email, password }) }
    ),

  sendVerification: (token: string) =>
    request<{ message: string }>("/auth/send-verification", { method: "POST" }, token),

  verifyEmail: (verifyToken: string) =>
    request<{ token: string; session_id: string; has_profile: boolean; email_verified: boolean }>(
      `/auth/verify-email?token=${encodeURIComponent(verifyToken)}`
    ),

  setProfile: (token: string, data: { dob: string; avatar_id: number }) =>
    request<{ username: string; avatar_id: number }>(
      "/auth/profile",
      { method: "POST", body: JSON.stringify(data) },
      token
    ),

  getMe: (token: string) =>
    request<{ username: string; avatar_id: number; speak_count: number; listen_count: number; member_since: string }>(
      "/auth/me",
      {},
      token
    ),

  updateProfile: (token: string, data: { avatar_id?: number; reroll_username?: boolean }) =>
    request<{ username: string; avatar_id: number }>(
      "/auth/profile",
      { method: "PATCH", body: JSON.stringify(data) },
      token
    ),

  getUserProfile: (token: string, username: string) =>
    request<{ username: string; avatar_id: number; speak_count: number; listen_count: number; member_since: string }>(
      `/auth/user/${encodeURIComponent(username)}`,
      {},
      token
    ),

  // Speaker board
  postSpeak: (token: string) =>
    request<{ request_id: string; status: string }>("/board/speak", { method: "POST" }, token),

  cancelSpeak: (token: string) =>
    request("/board/speak", { method: "DELETE" }, token),

  getBoard: (token: string) =>
    request<{ requests: SpeakerRequest[]; my_request_id: string | null }>(
      "/board/requests",
      {},
      token
    ),

  getSpeakerRequest: (token: string, requestId: string) =>
    request<CurrentSpeakerRequest>(
      `/board/request/${encodeURIComponent(requestId)}`,
      {},
      token
    ),

  acceptSpeaker: (token: string, requestId: string) =>
    request<{ room_id: string }>(`/board/accept/${encodeURIComponent(requestId)}`, { method: "POST" }, token),

  submitReport: (token: string, reason: string, detail?: string, roomId?: string) =>
    request("/report/", { method: "POST", body: JSON.stringify({ reason, detail: detail ?? "", ...(roomId ? { room_id: roomId } : {}) }) }, token),

  // Block
  blockUser: (token: string, peerSessionId: string, username: string, avatarId: number) =>
    request<{ message: string }>("/block/", { method: "POST", body: JSON.stringify({ peer_session_id: peerSessionId, username, avatar_id: avatarId }) }, token),

  unblockUser: (token: string, peerSessionId: string) =>
    request<{ message: string }>(`/block/${encodeURIComponent(peerSessionId)}`, { method: "DELETE" }, token),

  getBlockedUsers: (token: string) =>
    request<{ blocked: BlockedUser[] }>("/block/", {}, token),

  // Chat history
  getActiveRoom: (token: string) =>
    request<{ room_id: string | null }>("/chat/active", {}, token),

  getChatRooms: (token: string) =>
    request<{ rooms: RoomSummary[] }>("/chat/rooms", {}, token),

  getRoomMessages: (token: string, roomId: string) =>
    request<RoomMessages>(
      `/chat/rooms/${encodeURIComponent(roomId)}/messages`,
      {},
      token
    ),

  // Feedback
  postFeedback: (token: string, roomId: string, mood: string, text?: string) =>
    request<{ message: string }>(
      `/chat/rooms/${encodeURIComponent(roomId)}/feedback`,
      { method: "POST", body: JSON.stringify({ mood, text: text ?? "" }) },
      token
    ),

  // Connections
  sendConnectionRequest: (token: string, peerSessionId: string) =>
    request<{ connection: ConnectionItem }>(
      `/chat/connect/${encodeURIComponent(peerSessionId)}`,
      { method: "POST" },
      token
    ),

  acceptConnectionRequest: (token: string, peerSessionId: string) =>
    request<{ message: string }>(
      `/chat/connect/${encodeURIComponent(peerSessionId)}/accept`,
      { method: "POST" },
      token
    ),

  removeConnection: (token: string, peerSessionId: string) =>
    request<{ message: string }>(
      `/chat/connect/${encodeURIComponent(peerSessionId)}`,
      { method: "DELETE" },
      token
    ),

  getConnections: (token: string) =>
    request<{ connections: ConnectionItem[]; pending_requests: ConnectionItem[] }>(
      "/chat/connections",
      {},
      token
    ),

  directChat: (token: string, peerSessionId: string) =>
    request<{ room_id: string }>(
      `/chat/connect/${encodeURIComponent(peerSessionId)}/chat`,
      { method: "POST" },
      token
    ),

  // Posts
  getPosts: () =>
    request<{ posts: Post[] }>("/posts", {}),

  createPost: (token: string, text: string) =>
    request<{ post: Post }>("/posts", { method: "POST", body: JSON.stringify({ text }) }, token),

  deletePost: (token: string, postId: string) =>
    request<void>(`/posts/${encodeURIComponent(postId)}`, { method: "DELETE" }, token),

  // Account
  exportData: (token: string) =>
    request<Record<string, unknown>>("/auth/export", {}, token),

  deleteAccount: (token: string) =>
    request<{ message: string }>("/auth/account", { method: "DELETE" }, token),
};

export const wsUrl = {
  board: (token: string) =>
    `${SOCKET_API.replace("http", "ws")}/board/ws?token=${encodeURIComponent(token)}`,
  chat: (token: string, roomId: string) =>
    `${SOCKET_API.replace("http", "ws")}/chat/ws?token=${encodeURIComponent(token)}&room_id=${encodeURIComponent(roomId)}`,
};
