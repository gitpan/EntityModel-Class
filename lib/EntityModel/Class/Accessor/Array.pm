package EntityModel::Class::Accessor::Array;
BEGIN {
  $EntityModel::Class::Accessor::Array::VERSION = '0.002';
}
use strict;
use warnings FATAL => 'all', NONFATAL => 'redefine';
use 5.010;
use feature ();

use parent qw{EntityModel::Class::Accessor};
use EntityModel::Array;
use EntityModel::Log ':all';
use Class::ISA;

my %watcher;

=pod

=cut

=head2 C<methodList>

Returns a hash of method definitions.

=cut

sub methodList {
	my ($class, %opt) = @_;
	my $k = $opt{k};
	return sub {
		my $self = shift;
		if($opt{pre}) {
			$opt{pre}->($self, @_)
			 or return;
		}
		$self->{$k} ||= [ ];
		my @watchers = map { @{ $watcher{$_}->{$k} // [] } } Class::ISA::self_and_super_path(ref $self);
		logDebug("Watcher for [%s] method [%s] has %d entries", ref $self, $k, scalar @watchers);
		return new EntityModel::Array::($self->{$k},
			  (@watchers)
			? (onchange => sub {
				logDebug("Check [%s] for [%s]", ref $self, $k);
				# Pass value only
				$_->($self, @_) foreach @watchers;
			}) : ()
		);
	};
}

sub addWatcher {
	my ($class, $pkg, $meth, @sub) = @_;
	logDebug("Watching [%s] for [%s]", $meth, $pkg);
	push @{$watcher{$pkg}->{$meth}}, @sub;
	return 1;
}

1;
