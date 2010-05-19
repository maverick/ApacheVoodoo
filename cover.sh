#!/bin/bash

#
# Convience script to run the test suite under devel cover skipping pod coverage.
#
cover -delete
HARNESS_PERL_SWITCHES=-MDevel::Cover=-db,cover_db,-coverage,statement,subroutine,branch,condition,time make test
cover
