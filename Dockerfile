# ==========================================
# STAGE 1: Build Frontend (React + Vite)
# ==========================================
FROM node:20-alpine AS frontend-builder

WORKDIR /app

# Install dependencies
COPY package*.json ./
RUN npm ci

# Copy configuration and source files
COPY index.html vite.config.ts tsconfig*.json ./
COPY src/ ./src/
COPY public/ ./public/

RUN npm run build

# ==========================================
# STAGE 2: Build Backend (Go Executable)
# ==========================================
FROM golang:1.24-alpine AS backend-builder

ENV GOTOOLCHAIN=auto
WORKDIR /app

# Download dependencies (go.mod & go.sum berada di root proyek)
COPY go.mod go.sum ./
RUN go mod download

# Copy backend source
COPY backend/ ./backend/

# Compile standalone Linux binary (CGO disabled for alpine compatibility)
RUN CGO_ENABLED=0 GOOS=linux go build -ldflags="-s -w" -o /app/server ./backend

# ==========================================
# STAGE 3: Final Production Runtime Container
# ==========================================
FROM alpine:3.20

# Install timezone and SSL certificates
RUN apk --no-cache add ca-certificates tzdata
ENV TZ=Asia/Jakarta

WORKDIR /app

# Copy binary from backend builder
COPY --from=backend-builder /app/server /app/server

# Copy static frontend build from frontend builder
COPY --from=frontend-builder /app/dist /app/dist

# Create uploads directory for persistent asset photos & APK
RUN mkdir -p /app/uploads

# Expose backend port
EXPOSE 8080

# Run the unified Go server
CMD ["/app/server"]
