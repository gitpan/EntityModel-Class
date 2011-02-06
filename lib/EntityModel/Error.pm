package EntityModel::Error;
BEGIN {
  $EntityModel::Error::VERSION = '0.002';
}
use strict;
use warnings FATAL => 'all', NONFATAL => 'redefine';
use 5.010;

use EntityModel::Log ':all';

use overload
	'bool' => sub {
		my $self = shift;
		use Data::Dumper;
		logWarning('Error: [%s], chain was [%s]',
			Dumper($self->{message}),
			join(',', map {
				$_->{method} // 'unknown'
			} @{ $self->{chain} })
		);
		return 0;
	},
	'ne' => sub { 1 },
	'eq' => sub { 0 },
	'fallback' => 1;

sub new {
	my ($class, $parent, $msg, $opt) = @_;
	$opt ||= { };

	logWarning($msg) if $opt->{warning};
	logError($msg) if $opt->{error};
	logStack("Had error [%s]", $msg);

	my $self = bless {
		message		=> $msg,
		parent		=> $parent,
		chain		=> [ ]
	}, $class;
	return $self;
}

our $AUTOLOAD;

sub AUTOLOAD {
	my $self = shift;
	my ($method) = $AUTOLOAD;
	$method =~ s/^.*:://g;
	return if $method eq 'DESTROY';

	logWarning('Bad method [%s] called in error, original message [%s] with object [%s]',
		$method,
		$self->{message},
		$self->{parent}
	) unless eval { $self->{parent}->can($method) };

	push @{$self->{chain}}, {method => $method };
	return $self;
}

1;

