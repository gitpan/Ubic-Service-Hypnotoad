package Ubic::Service::Hypnotoad;
# ABSTRACT: Ubic service module for Mojolicious Hypnotoad
$Ubic::Service::Hypnotoad::VERSION = '0.2001';
use strict;
use warnings;

use parent qw(Ubic::Service::Skeleton);

use Ubic::Result qw(result);
use File::Basename;
use Time::HiRes qw(time);
use Capture::Tiny qw(:all);




sub new {
	my ($class, $opt) = @_;

	my $bin = [split /\s+/, ($opt->{'bin'} // 'hypnotoad')]		unless ref $opt->{bin} eq 'ARRAY';
	@$bin	or die "missing 'bin' parameter in new";
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
		cwd => $opt->{cwd},
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

	local %ENV = (%ENV, %{ $self->{'env'} });

	if (defined $self->{cwd}) {
		chdir $self->{cwd} or die "chdir to '$self->{cwd}' failed: $!";
	}

	system(@{$self->{'bin'}}, $self->{'app'});
	$self->{'start_time'} = time;
	$self->{'stop_time'} = undef;

	return result('starting');
}

sub stop_impl {
	my $self = shift;

	if (defined $self->{cwd}) {
		chdir $self->{cwd} or die "chdir to '$self->{cwd}' failed: $!";
	}

	local %ENV = (%ENV, %{ $self->{'env'} });
	my (undef, $stderr) = capture {
		system(@{$self->{'bin'}}, '-s', $self->{'app'});
	};
	print $stderr	if length $stderr;
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

version 0.2001

=head1 SYNOPSIS

    use Ubic::Service::Hypnotoad;
    return Ubic::Service::Hypnotoad->new({
        bin => '/usr/bin/hypnotoad', # or 'carton exec hypnotoad', or ['carton', 'exec', 'hypnotoad'], optional, defaults to 'hypnotoad'
        app => '/home/www/mysite.app',
        pid_file => '/var/log/mysite.pid', # optional, defaults to a hypnotoad.pid file lying next to "app"
        cwd => '/path/to/app/', # optional, change working directory before starting a daemon
        env => { # optional environment variables
            MOJO_FLAG_A => 1,
            MOJO_CONFIG => '...',
        },
    });

=head1 DESCRIPTION

This service is a common ubic wrap for launching your applications with Hypnotoad.

=head1 ACTIONS

=head2 status

Get status of service.

=head2 start

Start service.

=head2 stop

Stop service

=head2 reload

Send a USR2 signal to the process, to have it do an "automatic hot deployment".

=head1 BUGS

If you have a Github account, report your issues at
L<https://github.com/akarelas/ubic-service-hypnotoad/issues>.
I will be notified, and then you'll automatically be notified of progress on
your bug as I make changes.

=head1 AUTHOR

Alexander Karelas <karjala@karjala.org>

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2014 by Alexander Karelas.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=cut
