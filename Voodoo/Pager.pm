=pod #####################################################################################

=head1 NAME

Apache::Voodoo::Pager - Provides generic pagination controls 

=head1 SYNOPSIS

This module generates all the necessary 'next', 'previous' and page number links
typically found on any search engine results page.  This module can be used in 
any scenario where data must be paginated.

    my $pager = Apache::Voodoo::Pager->new('count'   => 25,
                                           'window'  => 10,
                                           'limit'   => 500,
                                           'persist' => [ 'url_param', ... ]);

    $pager->set_configuration('count'   => 40,
                              'window'  => 10,
                              'limit'   => 500,
                              'persist' => [ 'url_param', ... ]);

    my $template_params = $pager->paginate($all_url_params,$number_of_rows_in_results);

=cut ################################################################################
package Apache::Voodoo::Pager;

$VERSION = "3.0002";

use strict;
use POSIX qw(ceil);
use Data::Dumper;

sub new {
	my $class = shift;
	my $self = {};
	bless $self, $class;

	$self->set_configuration(@_);

	return $self;
}

sub set_configuration {
	my $self = shift;
	my %c = @_;

	$self->{'count'}  = (defined($c{'count'})  && $c{'count'}  =~ /^\d+$/)?$c{'count'}  :25;
	$self->{'window'} = (defined($c{'window'}) && $c{'window'} =~ /^\d+$/)?$c{'window'} :10;
	$self->{'limit'}  = (defined($c{'limit'})  && $c{'limit'}  =~ /^\d+$/)?$c{'limit'}  :500;

	$self->{'persist'} = $c{'persist'};
}

sub paginate {
	my $self = shift;

	my $params    = shift;
	my $res_count = shift;

	$params->{'count'}   =~ s/\D//g;
	$params->{'page'}    =~ s/\D//g;
	$params->{'showall'} =~ s/\D//g;

	my $count   = $params->{'count'}   || $self->{'count'};
	my $page    = $params->{'page'}    || 1;
	my $showall = $params->{'showall'} || 0;

	my %output;

	if ($res_count > $count) {
		my $url_params = "count=$count&amp;" . join('&amp;', map { $_ .'='. $params->{$_} } @{$self->{'persist'}});

		$output{'MODE_PARAMS'} = $url_params;

		$output{'HAS_MORE'} = 1;

		if ($res_count < $self->{'limit'} && $showall) {
			$output{'SHOW_MODE'} = 1;
			$output{'SHOW_ALL'} = 1;
			$output{'MODE_PARAMS'} .= "&amp;showall=0";
		}
		else {
			if ($res_count < $self->{'limit'}) {
				$output{'MODE_PARAMS'} .= "&amp;showall=1";
				$output{'SHOW_MODE'} = 1;
			}

			# setup the page list
			my $numpages = ceil($res_count / $count);
			$output{'PAGE_NUMBER'}  = $page;
			$output{'NUMBER_PAGES'} = $numpages;

			if ($numpages > 1) {
				# setup sliding window of page numbers
				my $start  = 0;
				my $window = $self->{'window'};
				my $end    = $window;

				if ($page >= $window) {
					$end = $page + ceil($window / 2) - 1;

					$start = $end - $window;
				}

				if ($end > $numpages) {
					$end = $numpages;
				}

				$output{'PAGES'} = [];
				for (my $x = $start; $x < $end; $x++) {
					# Put the page info into the array
					push(@{$output{'PAGES'}},
						{
							'NOT_ME'     => (($x + 1) == $page)?0:1,
							'PAGE'       => ($x + 1),
							'NOT_LAST'   => 1,
							'URL_PARAMS' => $url_params . '&amp;page='. ($x + 1)
						}
					);
				}

				# prevent access of index -1 if the page number requested is beyond the range.
				if ($#{$output{'PAGES'}} >= 0) {
					# set the last page to last
					$output{'PAGES'}->[$#{$output{'PAGES'}}]->{'NOT_LAST'} = 0;
				}

				# setup the 'more link'
				if ($end != $numpages) {
					$output{'MORE_URL_PARAMS'} =     $url_params . '&amp;page=' . ($end + 1);
					$output{'MORE_PAGE'} = $end+1;
				}

				# setup the preivous link
				if ($page > 1) {
					$output{'HAS_PREVIOUS'} = 1;
					$output{'PREVIOUS_URL_PARAMS'} = $url_params . '&amp;page=' . ($page - 1);
					$output{'PREV_PAGE'} = $page-1;
				}

				# setup the next link
				if ($page * $count < $res_count) {
					$output{'HAS_NEXT'} = 1;
					$output{'NEXT_URL_PARAMS'} =     $url_params . '&amp;page=' . ($page + 1);
					$output{'NEXT_PAGE'} = $page+1;
				}
			}
		}
	}

	return %output;
}

1;

=pod ################################################################################

=head1 PARAMETERS 

=over 4

=item count

Number of items per page

=item window 

Number of page numbers to appear at once.  window => 10 would yield links for page numbers 1 -> 10

=item limit

Maximum number of rows in the result that can be displayed at once.  In other words
if limit is set to 100 and the result set contains 101 items, then the 'Show all' link will
be disabled.

=item persist

List of url parameters that should appear in every link generated by this module.
search parameters, sort options, etc, etc.

=back

=head1 METHODS 

=over 4

=item paginate()

returns a hashref suitable for passing to L<HTML::Template> using the example template below.
The entire set of url paramaters is required so that Apache::Voodoo::Pager can get access to it's own
parameters as well as those listed in the persist => [] configuration parameter.

Apache::Voodoo::Pager uses two internal paramaters, 'page' and 'showall' to keep track of internal state.
page is the page number of the currently displayed result set (1 origin indexed) and
showall is set to 1 when the entire result set is being displayed at once.  These values can
be used by the caller to determine how to properly cut the result set.

=back

=head1 VOODOO EXAMPLE 

    use Apache::Voodoo::Pager;

    sub init {
        my $self = shift;

        $self->{'pager'} = Apache::Voodoo::Pager->new(
            'count'  => 10,
            'window' => 5,
            'limit'  => 100,
            'perisist' => [ 'value' ]
        );
    }

    sub list {
        my $self = shift;
        my $p    = shift;

        my $params = $p->{'params'};
        my $dbh    = $p->{'dbh'};

        my $value   = $params->{'value'};
        my $count   = $params->{'count'}   || 10;
        my $page    = $params->{'page'}    || 1;
        my $showall = $params->{'showall'} || 0;

        # Parameter validation and other security checks omitted for brevity

        my $stmt = "SELECT SQL_CALC_FOUND_ROWS col1,col2,col3 FROM some_table WHERE col1 = ?";
        unless ($showall) {
            $stmt .= " LIMIT $count OFFSET ". $count * ($page-1);
        }
           
        my $results = $dbh->selectall_arrayref($stmt,undef,$value);
        my $matches = $dbh->selectall_arrayref("SELECT FOUND_ROWS()");

        my $template_stuff = $self->{'pager'}->paginate($params,$matches->[0]->[0]);

        # other stuff this method does
    }


=head1 EXAMPLE HTML::Template

    <tmpl_loop PAGES>
        <tmpl_if NOT_ME>
            <a href="?<tmpl_var URL_PARAMS>"><tmpl_var PAGE></a>
        <tmpl_else>
            <tmpl_var PAGE>
        </tmpl_if>

        <tmpl_if NOT_LAST>|</tmpl_if>
    </tmpl_loop>

    <tmpl_if more_url_params>
        | <a href="?<tmpl_var MORE_URL_PARAMS>">More...</a>
    </tmpl_if>

    <tmpl_if has_more>
        <tmpl_if HAS_PREVIOUS>
            <a href="?<tmpl_var PREVIOUS_URL_PARAMS>">Previous</a> |
        </tmpl_if>
        <tmpl_if HAS_NEXT>
            <a href="?<tmpl_var NEXT_URL_PARAMS>">Next</a> |
        </tmpl_if>

        <tmpl_if MODE_PARAMS>
            <a href="?<tmpl_var MODE_PARAMS>">
                <tmpl_if SHOW_ALL>Show Page
                <tmpl_else>Show All
                </tmpl_if>
            </a>
        </tmpl_if>
    </tmpl_if>

    Page <tmpl_var PAGE_NUMBER> of <tmpl_var NUMBER_PAGES>

=cut ###########################################################################

################################################################################
# Copyright (c) 2005-2010 Steven Edwards (maverick@smurfbane.org).  
# All rights reserved.
#
# You may use and distribute Apache::Voodoo under the terms described in the 
# LICENSE file include in this package. The summary is it's a legalese version
# of the Artistic License :)
#
################################################################################
