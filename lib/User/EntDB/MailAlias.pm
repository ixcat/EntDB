
# User::EntDB::MailAlias
#
# simple wrapper around User::EntDB::KeyValue to support /etc/mail/alias
# loading/dumping
#
# $Id$

package User::EntDB::MailAlias;

use strict;
use warnings;

use parent 'User::EntDB::KeyValue';

sub new;
sub toString;
# sub dumpAllAliases;

sub new {
	my $class = shift;
	my $args = shift;

	my $fname = $args->{fname};

	$fname = '/etc/mail/aliases' unless $fname;

	my $self = User::EntDB::KeyValue->new({
		'rx' => '(.*):\s+(.*)',
		'multi' => '\s+',
		'skiprx' => '^\s*(#|$)',
		'tname' => 'aliases_kv',
		'fname' => $fname,
	});

	bless $self,$class;
	return $self;	
}

sub dup {
	my $self = shift;
	my $dup = $self->SUPER::dup();
	bless $dup,ref($self);
	return $dup;
}

sub toString {
	my $self = shift;

	my $k = $self->key();
	my $v = $self->val();

	my $r = "$k:";

	foreach my $u (@{$v}) {
		$r .= " $u";
	}
	return "$r\n";
}


1;
