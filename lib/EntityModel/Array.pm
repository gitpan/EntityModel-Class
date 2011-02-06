package EntityModel::Array;
BEGIN {
  $EntityModel::Array::VERSION = '0.002';
}
use strict;
use warnings;
use 5.010;
use EntityModel::Log ':all';

=pod

=cut

use overload
	'@{}' => sub {
		my $self = shift;
		return $self->{data};
	},
	fallback => 1;

sub new {
	my ($class, $data, %opt) = @_;
	bless {
		%opt,
		data => ($data // [ ]),
	}, $class;
}

sub count {
	my $self = shift;
	return scalar @{$self->{data}};
}

sub list {
	my $self = shift;
	return unless $self->{data};
	return @{$self->{data}};
}

sub push : method {
	my $self = shift;
	push @{$self->{data}}, @_;
	if($self->{onchange}) {
		logDebug("We have change");
		$self->{onchange}->(add => $_) foreach @_;
	}
	return $self;
}

sub shift : method {
	my $self = shift;
	my $v = shift(@{$self->{data}});
	if($self->{onchange}) {
		logDebug("We have change");
		$self->{onchange}->(drop => $v);
	}
	return $v;
}

sub pop : method {
	my $self = shift;
	my $v = pop(@{$self->{data}});
	if($self->{onchange}) {
		logDebug("We have change");
		$self->{onchange}->(drop => $v);
	}
	return $v;
}

sub unshift : method {
	my $self = shift;
	my $v = unshift @{$self->{data}}, @_;
	if($self->{onchange}) {
		logDebug("We have change");
		$self->{onchange}->(add => $_) foreach @_;
	}
	return $v;
}

sub join : method {
	my $self = shift;
	return join(shift, @{$self->{data}});
}

sub each : method {
	my ($self, $code) = @_;
	foreach my $v (@{$self->{data}}) {
		$code->($v);
	}
	return $self;
}

sub first {
	my ($self, $match) = @_;
	return $self->{data}[0] unless defined $match;
	if(ref $match eq 'CODE') {
		my ($first) = grep { $match->($_) } @{$self->{data}};
		return $first;
	}
	my ($first) = grep $match, @{$self->{data}};
	return $first;
}

sub last {
	my ($self, $match) = @_;
	return $self->{data}[-1] unless defined $match;
	if(ref $match eq 'CODE') {
		my ($last) = reverse grep { $match->($_) } @{$self->{data}};
		return $last;
	}
	my ($last) = reverse grep $match, @{$self->{data}};
	return $last;
}

sub grep : method {
	my ($self, $match) = @_;
	return grep { $match->($_) } @{$self->{data}};
}

=head2 C<remove>

Remove entries from the array.

Avoid rebuilding the array in case we have weak refs, just splice out the values
indicated.

=cut

sub remove : method {
	my ($self, $check) = @_;
	my $idx = 0;
	while($idx < scalar @{$self->{data}}) {
		my $match;
		if(ref $check eq 'CODE') {
			$match = $check->($self->{data}->[$idx]);
		} else {
			$match = ($self->{data}->[$idx]) ~~ $check;
		}
		if($match) {
			splice @{$self->{data}}, $idx, 1;
		} else {
			++$idx;
		}
	}
	return $self;
}

sub clear : method {
	my $self = shift;
	$self->{data} = [ ];
	return $self;
}

sub arrayref {
	my ($self) = @_;
	return $self->{data};
}

sub is_empty {
	my $self = shift;
	return !$self->count;
}

1;
