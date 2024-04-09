all: docs

clean: docs-clean

docs: docs-html docs-coverage

docs-html:
	sphinx-build -M html docs/ build/

docs-coverage:
	sphinx-build -b coverage docs/ build/

docs-spelling:
	sphinx-build -b spelling docs/ build/

docs-clean:
	rm -rf build/