
# Testing Suite

Testing documentation is provided at [docs/source/guides/testing.rst](https://github.com/EnzymeFunctionInitiative/EST/blob/9ff15f087a4f94a37bb43ebe0bd82979757fb0ae/docs/source/guides/testing.rst). 
The `runtests.sh` script will run all testing modules defined in the `modules/` subdirectory. 
The 'test_env.sh` script exports environment variables that are used across all testing modules. 

To develop new testing modules, create the bash script in the modules subdirectory, following the `{zero_padded_index}_{test_descriptor}.sh` naming format.
This formatting enables the full test suite to be run when `runtests.sh` is called.

