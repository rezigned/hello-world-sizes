.PHONY: all clean help c cpp rust zig size

# Output directory for binaries
BUILD_DIR := build

# Source directories
C_SRC := src/c
CPP_SRC := src/cpp
RUST_SRC := src/rust
ZIG_SRC := src/zig
GO_SRC := src/go

# Optimization flags
C_FLAGS := -O3 -s
CPP_FLAGS := -O3 -s
RUST_FLAGS := -C opt-level=z -C strip=symbols -C lto=true -C codegen-units=1 -C panic=abort
ZIG_FLAGS := -O ReleaseSmall -fstrip
GO_FLAGS := -s -w

# Conditional target flag (zig can't resolve dylib from nix paths)
ifeq ($(shell uname -s),Darwin)
  ZIG_TARGET = -target $(shell uname -m)-macos
else
  ZIG_TARGET =
endif

all: prepare asm c cpp rust go zig size

prepare:
	@mkdir -p $(BUILD_DIR)

help:
	@echo "Available commands:"
	@echo "  make all    - Build all language binaries and show sizes"
	@echo "  make c      - Build C binary"
	@echo "  make cpp    - Build C++ binary"
	@echo "  make rust   - Build Rust binary"
	@echo "  make zig    - Build Zig binary"
	@echo "  make size   - Show binary sizes"
	@echo "  make clean  - Remove build directory"

asm: prepare
	nasm -f macho64 src/asm/main-darwin.asm -o $(BUILD_DIR)/hello_asm.o
	ld -macosx_version_min 10.13.0 -L $(shell xcrun --show-sdk-path)/usr/lib -no_pie -lSystem -arch x86_64 $(BUILD_DIR)/hello_asm.o -o $(BUILD_DIR)/hello_asm

c: prepare
	gcc $(C_FLAGS) $(C_SRC)/main.c -o $(BUILD_DIR)/hello_c

cpp: prepare
	g++ $(CPP_FLAGS) $(CPP_SRC)/main.cpp -o $(BUILD_DIR)/hello_cpp

go: prepare
	go build -ldflags "$(GO_FLAGS)" -o $(BUILD_DIR)/hello_go $(GO_SRC)/main.go

rust: prepare
	rustc $(RUST_FLAGS) $(RUST_SRC)/main.rs -o $(BUILD_DIR)/hello_rust

zig: prepare
	zig build-exe $(ZIG_FLAGS) $(ZIG_TARGET) $(ZIG_SRC)/main.zig -femit-bin=$(BUILD_DIR)/hello_zig

size:
	@echo "\nBinary sizes:"
	@for file in $(BUILD_DIR)/*; do \
		if [ -f "$$file" ]; then \
			printf "%-10s: %8d bytes\n" "$${file##*/}" "$$(stat -f %z "$$file")"; \
		fi \
	done

clean:
	rm -rf $(BUILD_DIR)
