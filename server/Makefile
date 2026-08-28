.PHONY: lint build test run clean

# Lint runs golangci-lint on all packages
lint:
	@golangci-lint run ./...

# Build compiles the server binary
build:
	@go build -o peerplay-server ./cmd/server

# Test runs all tests
test:
	@go test -v -race ./...

# Run starts the server (requires env vars or .env file)
run:
	@go run ./cmd/server

# Clean removes build artifacts
clean:
	@rm -f peerplay-server

# Check runs lint + build + test (CI shortcut)
check: lint build test
