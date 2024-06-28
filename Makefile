all: docs

clean: docs-clean

docs: docs-html docs-coverage

docs-html: docs-perlpod
	sphinx-build -M html docs/ build/ -n

docs-coverage:
	sphinx-build -b coverage docs/ build/

docs-spelling:
	sphinx-build -b spelling docs/ build/

docs-clean:
	rm -rf build/

docs-perlpod:
	find src -name "*.pl" | xargs scripts/pod2rst.sh