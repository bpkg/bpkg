SETUP := ./setup.sh
COMMANDS := install uninstall link unlink

.PHONY: default
default:
	@echo "make: Nothing to make."
	@echo "make: Try one of the following:"
	@for c in $(COMMANDS); do printf '\t%s\n' "make $$c"; done

$(COMMANDS):
	@$(SETUP) $@

setup:
	$(SETUP)

test:
	./test.sh
