# Build stage
FROM golang:1.22-alpine AS builder
WORKDIR /app
COPY go.mod go.sum ./
RUN go mod download
COPY . .
RUN CGO_ENABLED=0 GOOS=linux go build -o hello-world .

# Final stage
FROM alpine:3.19
RUN apk --no-cache add ca-certificates
WORKDIR /root/
COPY --from=builder /app/hello-world .
RUN adduser -D -u 1000 -g "" appuser && chown -R appuser:appuser /root/hello-world
USER appuser
EXPOSE 8080
CMD ["./hello-world"]