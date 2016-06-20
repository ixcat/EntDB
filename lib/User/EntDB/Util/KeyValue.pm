
# User::EntDB::Util::KeyValue
#
# Generic regexp based key:value parser.
#
# The 'match' method is used to match a given line, setting the
# internal hash 'key' and 'vale' to the values of the match,
# and returning a reference to a new object of the same parameters, 
# or undefined if no match occurs.
#
# Constructor args: 
#
# rx: 
#
#   Optional regular expression to split fields should contain 2
#   match groups for key and value, defaults to space-based separation:
#
#     '(.*?)\s+(.*)'
#
# multi:
#
#   Optional regular expression to further split 'value' fields
#   for 1:M mappings. Undefined by default, implying values will
#   simply be the result of the second match group in 'rx'.
#   
#   If given, all returned 'value' return items will be contained within
#   an array, even if the 'multi' matcher does not match. That is,
#   in cases where the 'multi' expression does not match, the result 
#   will be equivelent to returning '[ $2 ]' from the result of 
#   matching 'rx', and otherwise will be '[ split /$multi/, $2 ]'.
#
# $Id$

package User::EntDB::Util::KeyValue;

sub new {
	my $class = shift;

	my $args = shift;

	my $rx = $args->{rx}; 
	my $skiprx = $args->{skiprx}; 
	my $multi = $args->{multi};
	my $key = $args->{key};
	my $val = $args->{val};

	$rx = '(.*?)\s+(.*)' unless defined $rx;

	my $self = {};

	$self->{rx} = $rx;
	$self->{multi} = $multi;
	$self->{skiprx} = $skiprx;
	$self->{key} = $key;
	$self->{val} = $val;

	bless $self,$class;
	return $self;
}

sub skip {
	my $self = shift;
	my $arg = shift;

	my $skiprx = $self->{skiprx};

	if($skiprx) {
		return 1 if $arg =~ m:$skiprx:;
	}

	return undef;
}

sub match {
	my $self = shift;

	my $rx = $self->{rx};
	my $multi = $self->{multi};

	my $arg = shift;
	if($arg =~ m:$rx:) {
		my $key = $1;
		my $val = $2;

		if ($multi) {
			my $nval = [ split /$multi/, $val ];
			if (scalar $nval > 0 ) {
				$val = $nval;
			}
			else {
				$val = [ $val ];
			}
		}

		return User::EntDB::Util::KeyValue->new({
			rx => $self->{rx},
			multi => $self->{multi},
			skiprx => $self->{skiprx},
			key => $key,
			val => $val
		});
	}
	else {
		return undef;
	}
}

1;

