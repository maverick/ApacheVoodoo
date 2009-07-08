use strict;
use warnings;

use Apache::Voodoo::Validate;

use Test::More tests => 25;
use Data::Dumper;

my %u_int_old = (
	'type' => 'unsigned_int',
	'max' => 4294967295
);

my %u_int_new = (
	'type'  => 'unsigned_int',
	'bytes' => 4
);

my %s_int_old = (
	'type' => 'unsigned_int',
	'min'  => -4294967296,
	'max'  => 4294967295
);

my %s_int_new = (
	'type'  => 'unsigned_int',
	'bytes' => 4,
);

my %vchar = ( type => 'varchar', 'length' => 64 );
my %text  = ( type => 'varchar', 'length' =>  -1 );

my %email  = ( type => 'varchar', 'length' => 64, 'valid'  => 'email'   );
my %url    = ( type => 'varchar', 'length' => 64, 'valid'  => 'url'     );
my %regexp = ( type => 'varchar', 'length' => 64, 'regexp' => '^aab+a$' );

my $full_monty = {
	'u_int_old_r'   => { %u_int_old, required => 1 },
	'u_int_new_r'   => { %u_int_new, required => 1 },
	'u_int_old_o'   => { %u_int_old, required => 0 },
	'u_int_new_o'   => { %u_int_new, required => 0 },

	'varchar_req' => { %vchar,     required => 1 },
	'varchar_opt' => { %vchar,     required => 0 },

	'email_req' => { %email, required => 1 },
	'email_opt' => { %email, required => 0 },

	'url_req' => { %url, required => 1 },
	'url_opt' => { %url, required => 0 },

	'regexp_req' => { %regexp, required => 1 },
	'regexp_opt' => { %regexp, required => 0 },

	'valid' => {
		%vchar,
		'valid' => sub {
			my $v = shift;
			
			my %vals = (
				'ok' => 1,
				'notok' => 0,
				'bogus' => 'BOGUS'
			);
			return $vals{$v};
		}
	},
};

my $V;

eval {
  $V = Apache::Voodoo::Validate->new($full_monty);
};
if ($@) {
	fail("Config Syntax failed when it shouldn't have\n$@");
	BAIL_OUT("something is terribly wrong");
}
else {
	pass("Config Syntax");
}

my ($v,$e) = $V->validate({});

# Catches missing required params
ok(defined $e->{MISSING_u_int_old_r},'unsigned int required 1'); 
ok(defined $e->{MISSING_u_int_new_r},'unsigned int required 2'); 
ok(defined $e->{MISSING_url_req},    'url required'); 
ok(defined $e->{MISSING_varchar_req},'varchar required'); 
ok(defined $e->{MISSING_email_req},  'email required'); 
ok(defined $e->{MISSING_regexp_req}, 'regexp required'); 

# Doesn't yell about missing optional params
ok(!defined $e->{MISSING_u_int_old_o},'unsigned int optional 1'); 
ok(!defined $e->{MISSING_u_int_new_o},'unsigned int optional 2'); 
ok(!defined $e->{MISSING_url_opt},    'url optional'); 
ok(!defined $e->{MISSING_varchar_opt},'varchar optional'); 
ok(!defined $e->{MISSING_email_opt},  'email optional'); 
ok(!defined $e->{MISSING_regexp_opt}, 'regexp optional'); 

# bogus values
($v,$e) = $V->validate({
	u_int_new_r => 'abc',
	u_int_new_o => 'abc',
	u_int_old_r => 'abc',
	u_int_old_o => 'abc',
	email_req => 'abc!',
	email_opt => 'abc@abcabcabcabcabc.com',	# valid form, non-existant domain
	url_req => 'abc',
	url_opt => 'http://127.0.0.0.1/foo',	# too many dots.
	regexp_req => 'c',
	regexp_opt => 'aba',
	valid => 'notok',
});

ok(scalar keys %{$v} == 0,'v is empty');
ok(defined $e->{BAD_u_int_new_r},'bad unsigned int 1');
ok(defined $e->{BAD_u_int_new_o},'bad unsigned int 2');
ok(defined $e->{BAD_u_int_old_r},'bad unsigned int 3');
ok(defined $e->{BAD_u_int_old_o},'bad unsigned int 4');
ok(defined $e->{BAD_email_req},  'bad email 1');
ok(defined $e->{BAD_email_opt},  'bad email 2');
ok(defined $e->{BAD_url_req},    'bad url 1');
ok(defined $e->{BAD_url_opt},    'bad url 2');
ok(defined $e->{BAD_regexp_req}, 'bad regexp 1');
ok(defined $e->{BAD_regexp_opt}, 'bad regexp 2');
ok(defined $e->{BAD_valid},      'bad valid sub');

# valid values
($v,$e) = $V->validate({
	varchar_req => ' abc ',		# also sneek in trim test
	varchar_opt => 'abcdef ',	# also sneek in trim test
	u_int_new_r => '1234',
	u_int_new_o => '1234',
	u_int_old_r => '1234',
	u_int_old_o => '1234',
	email_req => 'abc@mailinator.com',
	email_opt => 'abc@yahoo.com',
	url_req => 'http://www.google.com',
	url_opt => 'http://yahoo.com/foo',
	regexp_req => 'aabbbba',
	regexp_opt => 'aaba',
	valid => 'ok',
});

ok(scalar keys %{$e} == 0,'e is empty');
ok($v->{varchar_req} eq 'abc',                  'good varchar 1');
ok($v->{varchar_opt} eq 'abcdef',               'good varchar 2');
ok($v->{u_int_new_r} == 1234,                   'good unsigned int 1');
ok($v->{u_int_new_o} == 1234,                   'good unsigned int 1');
ok($v->{u_int_old_r} == 1234,                   'good unsigned int 1');
ok($v->{u_int_old_o} == 1234,                   'good unsigned int 1');
ok($v->{email_req}   eq 'abc@mailinator.com',   'good email 1');
ok($v->{email_opt}   eq 'abc@yahoo.com',        'good email 2');
ok($v->{url_req}     eq 'http://www.google.com','good url 1');
ok($v->{url_opt}     eq 'http://yahoo.com/foo', 'good url 2');
ok($v->{regexp_req}  eq 'aabbbba',              'good regexp 1');
ok($v->{regexp_opt}  eq 'aaba',                 'good regexp 2');
ok($v->{valid}       eq 'ok',                   'good valid sub');

# fence post values
($v,$e) = $V->validate({
	varchar_req => 'a' x 64,
	varchar_opt => '  '.('a' x 64).'   ',	# also sneek in trim test
	u_int_new_r => 4294967295,
	u_int_new_o => 4294967295,
	u_int_old_r => 4294967295,
	u_int_old_o => 4294967295,
	email_req => 'a' x 54 . '@yahoo.com',
	email_opt => 'a' x 54 . '@yahoo.com  ',
	url_req => 'http://www.google.com/'. ('a' x (64-22)),
	regexp_req => 'aa'. ('b'x 61) . 'a'
});

ok(scalar keys %{$e} == 0,'e is empty');

# and over the line values
($v,$e) = $V->validate({
	varchar_req => 'a' x 65,
	varchar_opt => '  '.('a' x 100).'   ',	# also sneek in trim test
	u_int_new_r => 4294967296,
	u_int_new_o => 4294967296,
	u_int_old_r => 4294967296,
	u_int_old_o => 4294967296,
	email_req => 'a' x 100 . '@yahoo.com',
	email_opt => 'a' x 100 . '@yahoo.com  ',
	url_req => 'http://www.google.com/'. ('a' x 100),
	url_opt => 'http://www.google.com/'. ('a' x 100),
	regexp_req => 'aa'. ('b'x 100) . 'a',
	regexp_opt => 'aa'. ('b'x 200) . 'a',
	valid => 'a' x 65,
});

ok(scalar keys %{$v} == 0,'v is empty');
ok(defined $e->{BIG_varchar_req},'big varchar 1');
ok(defined $e->{BIG_varchar_req},'big varchar 2');
ok(defined $e->{MAX_u_int_new_r},'big unsigned int 1');
ok(defined $e->{MAX_u_int_new_o},'big unsigned int 2');
ok(defined $e->{MAX_u_int_old_r},'big unsigned int 3');
ok(defined $e->{MAX_u_int_old_o},'big unsigned int 4');
ok(defined $e->{BIG_email_req},  'big email 1');
ok(defined $e->{BIG_email_opt},  'big email 2');
ok(defined $e->{BIG_url_req},    'big url 1');
ok(defined $e->{BIG_url_opt},    'big url 2');
ok(defined $e->{BIG_regexp_req}, 'big regexp 1');
ok(defined $e->{BIG_regexp_opt}, 'big regexp 2');
ok(defined $e->{BIG_valid},      'big valid sub');
