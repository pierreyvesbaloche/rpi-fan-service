.PHONY: usage install uninstall check

usage:
	@echo "rpi-fan Python Service"
	@echo "Usage: make <target>, where target is one of:\n"
	@echo "  install:    install the fan/LED controller service"
	@echo "  uninstall:  remove the fan/LED controller service"
	@echo "  check:      perform basic integrity checks on the codebase"

install:
	./install.sh

uninstall:
	./uninstall.sh

check:
	@echo "Checking shell scripts for trailing whitespace"
	@! grep -IUrn --color "[[:blank:]]$$" install.sh uninstall.sh
	@echo "Checking required files"
	@test -f install.sh && test -f uninstall.sh && test -f rpi-fan-custom.py
