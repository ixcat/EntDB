
# User::EntDB Makefile.PL
# $Id$

use ExtUtils::MakeMaker;

WriteMakefile(
	NAME => 'User::EntDB',
	VERSION_FROM => 'lib/User/EntDB.pm',
	EXE_FILES => [ 
		"bin/entdb",
	],
	PREREQ_PM => {
		'DBI' => 0, # tested against 1.633
		'DBD::SQLite' => 0, # tested against 1.46
		'Crypt::Eksblowfish' => 0, # tested against 0.009
		'Crypt::PasswdMD5' => 0, # tested against 1.3
	}
);

