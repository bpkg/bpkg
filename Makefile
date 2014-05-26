
BIN ?= bpkg
PREFIX ?= /usr/local
CMDS = json install package term suggest

install: uninstall
  cd ./lib/term && make install
  cp ./lib/json/JSON.sh $(PREFIX)/bin/JSON.sh
  install $(BIN) $(PREFIX)/bin
  for cmd in $(CMDS); do cp $(BIN)-$${cmd} $(PREFIX)/bin; done

uninstall:
  cd ./lib/term && make uninstall
  rm -f $(PREFIX)/bin/JSON.sh
  rm -f $(PREFIX)/bin/$(BIN)
  for cmd in $(CMDS); do rm -f $(PREFIX)/bin/$(BIN)-$${cmd}; done

link: uninstall
  ln -s $(BIN) $(PREFIX)/bin/$(BIN)
  for cmd in $(CMDS); do ln -s $(BIN)-$${cmd} $(PREFIX)/bin; done

unlink: uninstall
