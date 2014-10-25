package Ubic::Service::Hypnotoad;
{
  $Ubic::Service::Hypnotoad::VERSION = '0.002';
}
# ABSTRACT: Ubic service module for Mojolicious Hypnotoad

use strict;
use warnings;

use parent qw(Ubic::Service::Skeleton);

use Ubic::Result qw(result);
use File::Basename;
use Time::HiRes qw(time);


sub new {
	my ($class, $opt) = @_;

	my $bin = $opt->{'bin'} // 'hypnotoad';
	length $bin	or die "missing 'bin' parameter in new";
	my $app = $opt->{'app'} // '';
	length $app	or die "missing 'app' parameter in new";
	my $pid_file = $opt->{'pid_file'} // dirname($app).'/hypnotoad.pid';
	length $pid_file	or die "missing 'pid_file' parameter in new";

	my %env = %{ $opt->{'env'} // {} };

	return bless {
		bin => $bin,
		app => $app,
		env => \%env,
		pid_file => $pid_file,
		start_time => undef,
		stop_time => undef,
	}, $class;
}

sub _read_pid {
	my $self = shift;

	return eval {
		open my $fh, $self->{'pid_file'}	or die;
		my $pid = (scalar(<$fh>) =~ /(\d+)/g)[0];
		close $fh;
		$pid;
	};
}

sub status_impl {
	my $self = shift;

	my $pid = $self->_read_pid;

	if ($self->{'start_time'} and $self->{'start_time'} + 5 > time) {
		return result('broken')		if ! $pid;
	}
	$self->{'start_time'} = undef;

	if (! $pid) {
		$self->{'stop_time'} = undef;
		return result('not running');
	}

	if ($self->{'stop_time'} and $self->{'stop_time'} + 5 > time) {
		return result('broken');
	}

	my ($i, $running, $old_pid) = (0);
	do {
		$i++;
		$old_pid = $pid;
		$running = kill 0, $old_pid;
		$pid = $self->_read_pid		or return result('not running');
	} until ($pid == $old_pid or $i > 5);

	$pid == $old_pid	or return result('broken');

	return $running ? result('running', 'pid '.$pid) : result('not running');
}

sub start_impl {
	my $self = shift;

	local %ENV = (%ENV, %{ $self->{'env'} // {} });
	system($self->{'bin'}, $self->{'app'});
	$self->{'start_time'} = time;
	$self->{'stop_time'} = undef;

	return result('starting');
}

sub stop_impl {
	my $self = shift;

	local %ENV = (%ENV, %{ $self->{'env'} // {} });
	system($self->{'bin'}, '-s', $self->{'app'});
	$self->{'stop_time'} = time;
	$self->{'start_time'} = undef;

	return result('stopping');
}

sub reload {
	my $self = shift;

	my $pid = $self->_read_pid	or return 'not running';
	my $ret = kill "USR2", $pid;
	return $ret ? 'reloaded' : 'not running';
}

sub timeout_options {
	return {
		start => {
			step => 0.1,
			trials => 10,
		},
		stop => {
			step => 0.1,
			trials => 10,
		},
	};
}


1;

__END__

=pod

=head1 NAME

Ubic::Service::Hypnotoad - Ubic service module for Mojolicious Hypnotoad

=head1 VERSION

version 0.002

=head1 AUTHOR

Alexander Karelas <karjala@cpan.org>

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2013 by Alexander Karelas.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=cut
