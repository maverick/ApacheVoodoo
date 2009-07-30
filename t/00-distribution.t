use Test::More;

# Not every module is supposed to be publicly used, so we need to disable the pod converage checks. 
# There are also optional modules, so we have to conditionally decide which ones to check for compilation
# in a separate test.
my $not = ['pod','use'];

eval {
	require Test::Distribution not => 'pod';
};
plan(skip_all => 'Text::Distribution not installed') if $@;

