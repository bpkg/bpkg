# bpkg Makefile

BIN    ?= bpkg
PREFIX ?= /usr/local

# All 'bpkg' supported commands
CMDS = json install package term suggest init utils update list

install: uninstall
	@echo "  info: Installing $(PREFIX)/bin/$(BIN)..."
	@install $(BIN) $(PREFIX)/bin
	@for cmd in $(CMDS); do cp $(BIN)-$${cmd} $(PREFIX)/bin; done

uninstall:
	@echo "  info: Uninstalling $(PREFIX)/bin/$(BIN)..."
	@rm -f $(PREFIX)/bin/$(BIN)
	@for cmd in $(CMDS); do rm -f $(PREFIX)/bin/$(BIN)-$${cmd}; done

link: uninstall
	@ln -s $(BIN) $(PREFIX)/bin/$(BIN)
	@for cmd in $(CMDS); do ln -s $(BIN)-$${cmd} $(PREFIX)/bin; done

unlink: uninstall

