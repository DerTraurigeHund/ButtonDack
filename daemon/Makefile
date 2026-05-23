.PHONY: all build build-linux build-windows clean run

VERSION := 1.0.0-dev
BUILD_DIR := build

all: build

build:
	@mkdir -p $(BUILD_DIR)
	go build -ldflags "-X main.version=$(VERSION)" -o $(BUILD_DIR)/buttondackd ./cmd/buttondackd/

build-linux: build

build-windows:
	@mkdir -p $(BUILD_DIR)
	GOOS=windows GOARCH=amd64 go build -ldflags "-X main.version=$(VERSION)" -o $(BUILD_DIR)/buttondackd.exe ./cmd/buttondackd/

build-linux-amd64:
	@mkdir -p $(BUILD_DIR)
	GOOS=linux GOARCH=amd64 go build -ldflags "-X main.version=$(VERSION)" -o $(BUILD_DIR)/buttondackd-linux-amd64 ./cmd/buttondackd/

build-linux-arm64:
	@mkdir -p $(BUILD_DIR)
	GOOS=linux GOARCH=arm64 go build -ldflags "-X main.version=$(VERSION)" -o $(BUILD_DIR)/buttondackd-linux-arm64 ./cmd/buttondackd/

clean:
	rm -rf $(BUILD_DIR)

run: build
	./$(BUILD_DIR)/buttondackd

run-config:
	./$(BUILD_DIR)/buttondackd -config ./config.yaml
