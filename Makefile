.PHONY: build install uninstall test icon clean

build:
	./scripts/build.sh

install:
	./scripts/install.sh

uninstall:
	./scripts/uninstall.sh

test:
	cargo test -p zmt-core

icon:
	./scripts/make-icon.sh

clean:
	rm -rf build target

