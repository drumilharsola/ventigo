"use client";

import { useCallback, useEffect, useRef, useState } from "react";
import { useRouter } from "next/navigation";
import { useAuthStore } from "@/store/authStore";
import { api, Post, AuthError } from "@/lib/api";
import { avatarUrl } from "@/lib/avatars";
import { FlowLogo } from "@/components/FlowLogo";
import { AvatarImg } from "@/components/AvatarImg";
import { timeAgo } from "@/lib/utils";

const POST_MAX_CHARS = 400;
const REFRESH_INTERVAL_MS = 30_000;

function timeLeft(expiresAt: number): string {
  const secs = Math.max(0, expiresAt - Math.floor(Date.now() / 1000));
  const h = Math.floor(secs / 3600);
  const m = Math.floor((secs % 3600) / 60);
  if (h > 0) return `${h}h ${m}m left`;
  if (m > 0) return `${m}m left`;
  return "expiring soon";
}

export default function PostsPage() {
  const router = useRouter();
  const { token, sessionId } = useAuthStore();
  const [posts, setPosts] = useState<Post[]>([]);
  const [loading, setLoading] = useState(true);
  const [composeText, setComposeText] = useState("");
  const [posting, setPosting] = useState(false);
  const [postError, setPostError] = useState("");
  const [deleting, setDeleting] = useState<string | null>(null);
  const refreshRef = useRef<number | null>(null);

  const fetchPosts = useCallback(async () => {
    try {
      const res = await api.getPosts();
      setPosts(res.posts);
    } catch {
      /* swallow fetch errors */
    } finally {
      setLoading(false);
    }
  }, []);

  useEffect(() => {
    fetchPosts();
    refreshRef.current = window.setInterval(fetchPosts, REFRESH_INTERVAL_MS);
    return () => {
      if (refreshRef.current) window.clearInterval(refreshRef.current);
    };
  }, [fetchPosts]);

  const handlePost = async () => {
    const text = composeText.trim();
    if (!text || !token) return;
    setPosting(true);
    setPostError("");
    try {
      const res = await api.createPost(token, text);
      setPosts((prev) => [res.post, ...prev]);
      setComposeText("");
    } catch (e) {
      if (e instanceof AuthError) {
        router.push("/verify");
        return;
      }
      setPostError(e instanceof Error ? e.message : "Failed to post");
    } finally {
      setPosting(false);
    }
  };

  const handleDelete = async (postId: string) => {
    if (!token) return;
    setDeleting(postId);
    try {
      await api.deletePost(token, postId);
      setPosts((prev) => prev.filter((p) => p.post_id !== postId));
    } catch {
      /* swallow */
    } finally {
      setDeleting(null);
    }
  };

  const charsLeft = POST_MAX_CHARS - composeText.length;

  return (
    <div className="dark-canvas grain" style={{ minHeight: "100vh", display: "flex", flexDirection: "column", position: "relative" }}>
      <div className="orb orb-a" />
      <div className="orb orb-b" />

      {/* Nav */}
      <div className="top-nav" style={{ padding: "24px 32px", position: "relative", zIndex: 10 }}>
        <div style={{ display: "flex", alignItems: "center", justifyContent: "space-between", gap: 16 }}>
          <FlowLogo />
          <button onClick={() => router.push("/lobby")} className="btn btn-sm btn-ghost">← Back to lobby</button>
        </div>
      </div>

      {/* Content */}
      <div style={{ flex: 1, maxWidth: 600, width: "100%", margin: "0 auto", padding: "0 24px 64px", position: "relative", zIndex: 5 }}>
        <h1 style={{ fontFamily: "var(--font-display)", fontSize: "clamp(28px, 5vw, 40px)", fontWeight: 700, color: "var(--white)", marginBottom: 8 }}>
          Community Board
        </h1>
        <p style={{ fontSize: 14, color: "var(--slate)", fontFamily: "var(--font-ui)", fontWeight: 300, marginBottom: 28, lineHeight: 1.5 }}>
          Share a thought anonymously. Posts disappear after 24 hours.
        </p>

        {/* Compose */}
        {token && (
          <div style={{
            marginBottom: 28, padding: "18px 20px", borderRadius: "var(--r-lg)",
            background: "rgba(255,255,255,0.06)", border: "1px solid rgba(255,255,255,0.08)",
          }}>
            <textarea
              value={composeText}
              onChange={(e) => {
                if (e.target.value.length <= POST_MAX_CHARS) {
                  setComposeText(e.target.value);
                  if (postError) setPostError("");
                }
              }}
              placeholder="What's on your mind?"
              rows={3}
              style={{
                width: "100%", background: "transparent", border: "none", outline: "none",
                resize: "none", fontSize: 14, color: "var(--white)", fontFamily: "var(--font-ui)",
                lineHeight: 1.6, caretColor: "var(--accent)",
              }}
            />
            <div style={{ display: "flex", alignItems: "center", justifyContent: "space-between", marginTop: 10 }}>
              <span style={{
                fontSize: 12, fontFamily: "var(--font-ui)",
                color: charsLeft <= 50 ? "var(--danger)" : "var(--slate)",
              }}>
                {charsLeft} characters left
              </span>
              <button
                onClick={handlePost}
                disabled={!composeText.trim() || posting}
                className="btn btn-sm btn-accent"
                style={{ opacity: !composeText.trim() || posting ? 0.4 : 1 }}
              >
                {posting ? "Posting…" : "Post"}
              </button>
            </div>
            {postError && (
              <p style={{ margin: "8px 0 0", fontSize: 12, color: "var(--danger)", fontFamily: "var(--font-ui)" }}>
                {postError}
              </p>
            )}
          </div>
        )}

        {/* Posts list */}
        {loading ? (
          <div style={{ textAlign: "center", padding: 40 }}>
            <div style={{ width: 24, height: 24, borderRadius: "50%", border: "2px solid rgba(184,160,232,0.3)", borderTopColor: "var(--accent)", animation: "logo-spin 0.8s linear infinite", margin: "0 auto" }} />
          </div>
        ) : posts.length === 0 ? (
          <div style={{
            padding: "48px 24px", textAlign: "center", borderRadius: "var(--r-lg)",
            border: "1.5px dashed rgba(255,255,255,0.1)", background: "rgba(255,255,255,0.03)",
          }}>
            <p style={{ margin: 0, fontSize: 15, fontWeight: 600, color: "var(--fog)", fontFamily: "var(--font-ui)" }}>
              No posts yet.
            </p>
            <p style={{ margin: "6px 0 0", fontSize: 13, color: "var(--slate)", fontFamily: "var(--font-ui)", fontWeight: 300 }}>
              Be the first to share something.
            </p>
          </div>
        ) : (
          <div style={{ display: "flex", flexDirection: "column", gap: 12 }}>
            {posts.map((post) => (
              <div
                key={post.post_id}
                className="fade-up"
                style={{
                  padding: "16px 18px", borderRadius: "var(--r-lg)",
                  background: "rgba(255,255,255,0.06)", border: "1px solid rgba(255,255,255,0.08)",
                }}
              >
                <div style={{ display: "flex", alignItems: "center", gap: 10, marginBottom: 10 }}>
                  <AvatarImg id={post.avatar_id} size={28} />
                  <span style={{ fontSize: 13, fontWeight: 600, color: "var(--fog)", fontFamily: "var(--font-ui)" }}>
                    {post.username}
                  </span>
                  <span style={{ fontSize: 11, color: "var(--graphite)", fontFamily: "var(--font-ui)", marginLeft: "auto" }}>
                    {timeAgo(post.created_at)} · {timeLeft(post.expires_at)}
                  </span>
                  {post.session_id === sessionId && (
                    <button
                      onClick={() => handleDelete(post.post_id)}
                      disabled={deleting === post.post_id}
                      style={{
                        background: "none", border: "none", cursor: "pointer",
                        color: "var(--slate)", fontSize: 14, padding: "2px 6px",
                        opacity: deleting === post.post_id ? 0.4 : 0.6,
                      }}
                      title="Delete your post"
                    >
                      ✕
                    </button>
                  )}
                </div>
                <p style={{
                  margin: 0, fontSize: 14, color: "var(--white)", fontFamily: "var(--font-ui)",
                  lineHeight: 1.6, whiteSpace: "pre-wrap", wordBreak: "break-word",
                }}>
                  {post.text}
                </p>
              </div>
            ))}
          </div>
        )}
      </div>
    </div>
  );
}
