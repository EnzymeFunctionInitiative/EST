all: docs build-pyEFI build-docker

clean: docs-clean

build-pyEFI:
	python -m build lib/pyEFI

build-docker:
	docker build -t efi-est:latest .

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
	find pipelines -name "*.pl" | xargs -d\\n -n1 scripts/pod2rst.sh

test: test-pyefi test-pipelines

test-pipelines:
	bash tests/runtests.sh

test-pyefi:
	pytest lib/pyEFI

