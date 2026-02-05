all: docs build-pyEFI build-docker

clean: docs-clean tests-clean

build-pyEFI:
	python -m build lib/pyEFI

build-docker:
	docker build -t efi-est:latest .

docs: docs-html docs-coverage

docs-html: docs-perlpod
	sphinx-build -M html docs/ build/ -n

docs-coverage:
	sphinx-build -b coverage docs/ build/

docs-spelling: docs-spelling-perlpod
	sphinx-build -b spelling docs/ build/

docs-clean:
	rm -rf build/

docs-perlpod:
	find pipelines -name "*.pl" | xargs -d\\n -n1 scripts/pod2rst.sh
	perl scripts/color_palette_to_table.pl

docs-spelling-perlpod:
	perl scripts/podcheck --search pipelines --wordlist docs/spelling_wordlist.txt

test: test-pyefi test-pipelines

test-pipelines:
	bash tests/runtests.sh

test-pyefi:
	pytest lib/pyEFI

tests-clean:
	rm -rf .nextflow/
	rm -rf tests/test_results/

