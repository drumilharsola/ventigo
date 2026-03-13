# ── Stage 1: Build Flutter web ────────────────────────────────────────────────
FROM ghcr.io/cirruslabs/flutter:stable AS build

WORKDIR /app
COPY . .

# Accept the API_BASE_URL build arg (empty = same-origin in production)
ARG API_BASE_URL=""

RUN flutter pub get
RUN flutter build web --release --dart-define=API_BASE_URL=$API_BASE_URL

# ── Stage 2: Serve with nginx ────────────────────────────────────────────────
FROM nginx:alpine

# Copy built web assets
COPY --from=build /app/build/web /usr/share/nginx/html

# SPA fallback + reverse-proxy API routes to the backend service
RUN printf 'server {\n\
  listen 80;\n\
  root /usr/share/nginx/html;\n\
  index index.html;\n\
\n\
  # Proxy API and WebSocket routes to the backend container\n\
  location ~ ^/(auth|admin|block|board|chat|match|report|health)(/|$) {\n\
    proxy_pass         http://backend:8000;\n\
    proxy_http_version 1.1;\n\
    proxy_set_header   Upgrade $http_upgrade;\n\
    proxy_set_header   Connection "upgrade";\n\
    proxy_set_header   Host $host;\n\
    proxy_set_header   X-Real-IP $remote_addr;\n\
    proxy_set_header   X-Forwarded-For $proxy_add_x_forwarded_for;\n\
    proxy_set_header   X-Forwarded-Proto $scheme;\n\
    proxy_read_timeout 300s;\n\
  }\n\
\n\
  # SPA fallback for all other routes\n\
  location / {\n\
    try_files $uri $uri/ /index.html;\n\
  }\n\
}\n' > /etc/nginx/conf.d/default.conf

EXPOSE 80
CMD ["nginx", "-g", "daemon off;"]
