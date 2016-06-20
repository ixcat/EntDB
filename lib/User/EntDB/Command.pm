
package User::EntDB::Command;

# User::EntDB::Command - mico 'command' object framework
#
# synopsys:
#
# my $app = MuCMD->new({ 
#         appname => 'mucmd',
#         cmdlist => [
#                 'MuCMD::Sub1'
#         ]
# });
# 
# exit $app->main(\@ARGV);
# 
# where 'cmdlist' contains a list of classnames implementing the 
# command object protocol - e.g.:
# 
# package MuCMD::Sub1;
# 
# use strict;
# use warnings;
# 
# sub new {
#         my $class = shift;
#         my $app = shift;
#         my $self = {
#                 'app' => $app,
#                 'cmdname' => "sub1",
#                 'shorthelp' => "sub1 one-arg: do sub1 with one-arg\n",
#                 'longhelp' => "sub1 one-arg\n"
#                         . "  where: one-arg is the argument for sub1ing\n"
#         };
# 
#         bless $self,$class;
#         $app->register($self);
#         return $self;
# }
# 
# sub do {
#         my $self = shift;
#         my $args = shift;
#         foreach my $arg (@{$args}) {
#                 print "sub1 doing $arg\n";
#         }
#         return 0;
# }
#
# in otherwords, specifically required:
#
#   - contstructor takes 'app' as argument
#   - uses a hash for class data containing strings:
#
#     - cmdname
#     - shorthelp
#     - longhelp
#
#     and a reference to 'app' in 'app'
#
#   - constructor calls app->register with class data
#   - class implements a 'do' method which will perform needed action
#     when invoked
#
#
# Todo/Fixme:
#
#   - classname-> command name lookup lost via register
#   - which means help is looped over keys, implying bad sort order
#   - if classname -> commands are tracked, help can be dumped
#     in 'expected' 'cmdlist' order.
#

use strict;
use warnings;

sub new;
sub register;
sub dumpcmds;
sub shorthelp;
sub longhelp;
sub help;
sub dostatement;
sub main;

sub new {
        my $class = shift;
        my $self = shift;

        $self->{cmds} = {};
        $self->{cmdnames} = []; # actual command 'names' from cmd classes

        bless $self,$class;

        foreach my $cmd (@{$self->{cmdlist}}) {
                $cmd->new($self);
        }

        return $self;
}

sub register {
        my $self = shift;
        my $cmd = shift;
        $self->{cmds}->{$cmd->{cmdname}} = $cmd;
	push @{$self->{cmdnames}}, $cmd->{cmdname};
}

sub dumpcmds {
        my $self = shift;
        foreach (keys %{$self->{cmds}}) {
                print "cmd: $_\n";
        }
}

sub shorthelp {
        my $self = shift;
        my $app = $self->{appname};
        print "usage: " . $app . " cmd args\n";
        print "  where 'cmd args' is one of:\n";
        print "    - help: print this help\n";
        print "    - help cmd: print detailed help for 'cmd'\n";

	foreach (@{$self->{cmdnames}}) {
                print "    - " . $self->{cmds}->{$_}->{shorthelp};
        }
}

sub longhelp {
        my $self = shift;
        my $cmd = shift;
        my $app = $self->{appname};
        print "\n" . $app . " " . $cmd . " help:\n\n";
        print "usage: " . $app . " " 
                . $self->{cmds}->{$cmd}->{longhelp}
                . "\n";
} 

sub help {
        my ($self,$cmd) = @_;
        my $app = $self->{appname};
        if($cmd) {
                if (exists $self->{cmds}->{$cmd}) {
                        $self->longhelp($cmd);
                }
                else {
                        print $app . ": unknown subcommand " . $cmd . "\n\n";
                        $self->shorthelp;
                }
        }
        else {
                $self->shorthelp;
        }
        return 0;
}

sub dostatement {
        my $self = shift;
        my $args = shift;
        my $cmd = shift @{$args};

        return $self->help() unless $cmd;
        return $self->help(@{$args}) if $cmd eq 'help';
        return $self->help() unless exists $self->{cmds}->{$cmd};

        my $ref = $self->{cmds}->{$cmd};
        return $ref->do($args);
}

sub main {
        my $self = shift;
        # todo: 'shell' special case repl loop
        return $self->dostatement(@_);
}

1;
