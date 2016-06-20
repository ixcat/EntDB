
# User::EntDB::KeyValue
#
# arbitrary key:value table class
#
# FIXME: sloppy - abstraction gets a bit obtuse here with nested kv objects, 
#   etc, dup(), etc.
#
#   again thinking the EntDB::<FOO> classes should simply be procedural 
#   libraries for storing/retrieving other items, or 'serializer' 
#   classes in their own right, which would solve alot of mess..
#
# things to consider on rework:
#
#   - key/value OO orientation in this and Util setup
#     e.g. proper use of KeyValue as a base for other modules,
#     good inheretence model w/r/t base datatype classes,
#     database classes, etc.
#   - best use of 'skipping' rx or similar facility to filter out
#     comments, etc. in a coherent way
#   - pre/post subs in dump logic
#
# $Id$

package User::EntDB::KeyValue;

use strict;
use warnings;

use User::EntDB;
use User::EntDB::Util::KeyValue;

sub new;
sub next;
sub key;
sub val;
sub toSQLite;
sub toString;

# aggregate class?

sub getDBKeyValueList;
sub getFileKeyValueList;

sub loadAllKeyValuesFromFile;

sub convertKeyValueListToSQL;
sub dumpAllKeyValues;

sub new {
	my $class = shift;
	my $args = shift;

	my $rx = $args->{rx};
	my $skiprx = $args->{skiprx};
	my $multi = $args->{multi};
	my $fname = $args->{fname};
	my $tname = $args->{tname};
	my $txtfn = $args->{txtfn};
	my $kv = $args->{kv};

	$skiprx = undef unless $skiprx;
	$tname = 'kv' unless $tname;

	if(!$kv) {
		$kv = User::EntDB::Util::KeyValue->new({ 
			rx => $rx, 
			multi => $multi,
			skiprx => $skiprx
		}) or return undef;
	}

	my $self = {
		kv => $kv,
		fname => $fname,
		tname => $tname,
		txtfn => $txtfn,
		fh => undef
	};

	bless $self,$class;
	return $self;

}

sub dup {
	my $kv = shift;
	return User::EntDB::KeyValue->new({
		rx => $kv->{rx},
		multi => $kv->{multi},
		skiprx => $kv->{skiprx},
		fname => $kv->{fname},
		tname => $kv->{tname},
		txtfn => $kv->{txtfn},
		kv => $kv->{kv},
	});
}

sub next {
	my $self = shift;
	my $fh = $self->{fh};
	my $kv = $self->{kv};
	my $line;

	if(!$fh) {
		open($fh, '<', $self->{fname})
			or return undef;
		$self->{fh} = $fh;
	}
	do {
		$line = <$fh>;
		return undef unless $line;
	} while ($kv->skip($line));
	
	my $m = $kv->match($line);
	$self->{kv} = $m;
	return $m;
}

sub key {
	my $self = shift;
	my $new = shift; 
	if($new) {
		$self->{kv}->{key} = $new;
	}
	return $self->{kv}->{key};
}

sub val {
	my $self = shift;
	my $new = shift; 
	if($new) {
		$self->{kv}->{val} = $new;
	}
	return $self->{kv}->{val};
}

sub toSQLite {
	my $self = shift;
	my $kvrec = shift;
	my $tname = exists $self->{tname} ? $self->{tname} : 'kv';

	my $k = $kvrec->{key};
	my $v = $kvrec->{val};

	my $sql;

	if(ref($v) eq 'ARRAY') {
		foreach my $i (@{$v}) {	
			$sql .= "insert into $tname values ('$k','$i');\n";
		}
		chomp $sql;
	}
	else {
		$sql = "insert into $tname values ('$k','$v');";
	}
	return $sql;
}

# problematic for multi case since we have no way to 
# determine begin/end of generated string, which is needed for
# some record types

sub toString {
	my $self = shift;

	my $txtfn = $self->{txtfn};

	my $k = $self->key();
	my $v = $self->val();

	$txtfn = sub {
		my ($k,$v) = @_;
		my $r = '';
	        if(ref($v) eq 'ARRAY') {
			foreach my $i (@{$v}) {
				$r .= "$k $i\n";
			}
		}
		else {
			$r = "$k $v";
		}
		chomp $r;
		return $r;
	} unless $txtfn;

	return $txtfn->($k, $v);
}

sub getDBKeyValueList {
	my $dbkv = shift;
	my $entdb = shift;

	my $tname = $dbkv->{tname};

	my $tmpkv = {};
	my $kvseq = [];
	my $kvlist = [];

	# Synthesize multis from the data if passed-in kv is a 'multi',
	# tracking discovery sequence. discards multiple values from table 
	# if mismatched.

	my $kvs = $entdb->_kv_fetchall($tname);

	foreach my $r (@{$kvs}) {

		my $k = $r->{key};
		my $v = $r->{val};

		if($dbkv->{kv}->{multi}) {
			if(exists $tmpkv->{$k}) {
				push @{$tmpkv->{$k}}, $v;
			}
			else {
				push @{$kvseq}, $k;
				$tmpkv->{$k} = [ $v ];
			}
		}
		else {
			push @{$kvseq}, $k;
			$tmpkv->{$k} = $v;
		}
	}

	# and return array of kv objects in order of discovery

	foreach my $k (@{$kvseq}) {
		my $r = $dbkv->dup();
		$r->{kv} = User::EntDB::Util::KeyValue->new({
			key => $k,
			val => $tmpkv->{$k},
			rx => $r->{kv}->{rx},
			multi => $r->{kv}->{multi},
		});
		push @{$kvlist}, $r;
	}

	return $kvlist;
}

sub getFileKeyValueList {
	my $self = shift;
	my $kvlist = [];
	my $i;
	while ($i = $self->next()) {
		$self->{kv} = $i;
		my $ikv = $self->dup();
		push @{$kvlist}, $ikv;
	}
	return $kvlist;
}

sub convertKeyValueListToSQL {
	my $self = shift;
	my $kvlist = shift;
	my $sqlist = [];
	foreach my $k (@{$kvlist}) {
		my $sql = $self->toSQLite($k->{kv});
		push @{$sqlist}, $sql;
	}
	return $sqlist;
}

sub loadAllKeyValuesFromFile {
	my $kv = shift;
	my $dbfname = shift;

	my $entdb = User::EntDB->new($dbfname);
	my $kvlist = $kv->getFileKeyValueList();
	my $sqlist = $kv->convertKeyValueListToSQL($kvlist);

	$entdb->begintxn();
	foreach my $sql (@{$sqlist}) {
		$entdb->do($sql);
	}
	$entdb->endtxn();
}

sub dumpAllKeyValues {
	my $kv = shift;
	my $dbfname = shift;

	my $entdb = User::EntDB->new($dbfname) or return undef;
	my $kvlist = $kv->getDBKeyValueList($entdb);
	foreach my $i (@{$kvlist}) {
		print $i->toString();
	}
	return 0;
}

1;

