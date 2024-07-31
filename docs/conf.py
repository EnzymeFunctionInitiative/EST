# Configuration file for the Sphinx documentation builder.
#
# For the full list of built-in configuration values, see the documentation:
# https://www.sphinx-doc.org/en/master/usage/configuration.html

# -- Project information -----------------------------------------------------
# https://www.sphinx-doc.org/en/master/usage/configuration.html#project-information
import os
import sys
sys.path.insert(0, os.path.abspath('..'))
sys.path.insert(0, os.path.abspath('../pipelines/est/src/visualization'))
sys.path.insert(0, os.path.abspath('../pipelines/est/src/statistics'))


project = 'EFI'
copyright = '2024, Enzyme Function Initiative'
author = 'Nils Oberg, Hunter DeMeyer'
release = '2.0'

# -- General configuration ---------------------------------------------------
# https://www.sphinx-doc.org/en/master/usage/configuration.html#general-configuration

extensions = ["sphinx.ext.autodoc",       # parses docstrings from python code
              "sphinx.ext.intersphinx",   # allows clean linking to python/pyarrow/etc documentation
              "sphinx.ext.napoleon",      # parses google and numpy style docstrings which look nicer than native sphinx/rst
              "sphinx_autodoc_typehints", # reads types from signature and includes in description
              "sphinx.ext.coverage",      # reports percentage of functions which have documentation
              "sphinxcontrib.spelling",    # spell checking
              "sphinxarg.ext"
              ]

intersphinx_mapping = {
    "python": ("https://docs.python.org/3", None),
    "pyarrow": ("https://arrow.apache.org/docs", None),
    "pandas": ("https://pandas.pydata.org/docs/", None)
}
typehints_use_signature = True
typehints_use_signature_return  = True
typehints_document_rtype = False
typehints_use_rtype = False
add_module_names = False

exclude_patterns = ["efi-env/*"]

coverage_ignore_functions = ["main", "create_parser", "parse_args"]

# -- Options for HTML output -------------------------------------------------
# https://www.sphinx-doc.org/en/master/usage/configuration.html#options-for-html-output

html_theme = 'sphinx_rtd_theme'
html_theme_options = {
    'navigation_depth': 4
}