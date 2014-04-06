package FileDescriptor;

use 5.016;
use strict;
use warnings;
use autodie;

use overload
    '""' => \&to_string;

sub new {
    my ($class, $path) = @_;
    die "No path provided" unless $path;

    $class = ref $class if ref $class;
    my $self =
        bless {
            path => $path
        },
        $class;
    return $self;
}

sub key {
    return $_[0]->{path};
}

sub to_string {
    return $_[0]->{path};
}

1;