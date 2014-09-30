package MoveManager;

use 5.016;
use strict;
use warnings;
use autodie;
use Carp;

use File::Copy qw/move/;
use File::Path qw/make_path/;
use File::Basename qw/dirname fileparse/;

sub new {
    my ( $class, $target_directory, $trash_directory ) = @_;

    die "No $target_directory found" unless -d $target_directory;
    $target_directory .= '/' unless substr($target_directory, -1) eq '/';
    $trash_directory .= '/' unless substr($trash_directory, -1) eq '/';

    my $self = {
        target_directory => $target_directory,
        trash_directory => $trash_directory,
        source_to_target => {},
        target_to_source => {},
        source_digests => {},
        contested_targets => {},
        sources_to_delete => {},
        dirs_to_create => {}
    };
    return bless $self, $class;
}

sub plan_move {
    my ( $self, $source ) = @_;

    if ($self->_source_is_registered($source)) {
        __warn("$source: already registered");
        return;
    }

    my $target = $self->get_target($source);
    if ($target eq $source) {
        __trace("$source\n\tis already in place");
        return $source;
    }
    if (exists $self->{contested_targets}->{$target}) {
        my $target_with_digest = __insert_digest($target, $self->get_digest($source));
        return $self->_register_move_or_ignore($source, $target_with_digest);
    }

    my $conflicted_source = $self->_get_conflicted_source($target);
    if (not $conflicted_source) {
        return $self->_register_move($source, $target);
    } else {
        $self->_register_contested_target($target);

        if ($conflicted_source eq $target) {
            __log("Conflict: \n\t$source wants to be moved to\n\t$target, witch is already exist");
        } else {
            __log("Conflict: \n\t$source and \n\t$conflicted_source want to move to \n\t$target");
        }

        my ($conflicted_target_with_digest) = __insert_digest($target, $self->get_digest($conflicted_source));
        my ($target_with_digest, $digest) = __insert_digest($target, $self->get_digest($source));
        if ($conflicted_target_with_digest ne $target_with_digest) {
            __trace("Resolved conflict: files are actually differ\n\t"
              . "$conflicted_target_with_digest\n\tand\n\t$target_with_digest\n\trespectively");
            $self->_register_move_or_ignore($conflicted_source, $conflicted_target_with_digest);
            return $self->_register_move_or_ignore($source, $target_with_digest);
        } else {
            my $message = sprintf(
                '%s and %s are identical with MD5 digest $digest',
                $conflicted_source,
                $source,
                $digest
            );

            $self->_register_move_or_ignore($conflicted_source, $conflicted_target_with_digest);
            return $self->_register_delete($source, $target_with_digest);
        }
    }
}

sub target_directory {
    my ( $self ) = @_;
    return $self->{target_directory};
}

sub execute {
    my ( $self ) = @_;
    my $sources_to_delete = $self->{sources_to_delete};

    make_path(keys $self->{dirs_to_create});

    for my $file_path_to_delete (keys $sources_to_delete) {
        my $descriptor = $sources_to_delete->{$file_path_to_delete};
        say "Deleting $file_path_to_delete: " . $descriptor->{message} . "\n";
        my $trash_file_path = $descriptor->{trash_file_path};
        move($file_path_to_delete, $trash_file_path)
            or die "Unable to move trash '$file_path_to_delete' => '$trash_file_path': $!";
    }

    my $source_to_target = $self->{source_to_target};
    for my $source_file_path (keys $source_to_target) {
        my $target_file_path = $source_to_target->{$source_file_path};
        next if $target_file_path eq $source_file_path;

        say "Moving $source_file_path => $target_file_path";
        move($source_file_path, $target_file_path) or die "Unable to move: $!";
    }
}

sub get_target {
    ...
}

sub get_digest {
    ...
}

sub get_full_path {
    my $self = shift;
    return $self->{target_directory} . join '', @_;
}

sub _register_contested_target {
    my ( $self, $target ) = @_;
    $self->{contested_targets}->{$target} = 1;
}

sub _register_move_or_ignore {
    my ( $self, $source, $target ) = @_;
    my $conflicted_source = $self->{target_to_source}->{$target};
    if ($conflicted_source) {
        __warn("Ignoring move registration from $source to $target. Move already planned form " . $conflicted_source . " to $source");
        return $self->_register_delete(
            $source,
            $conflicted_source
                . " is identical to $source and will be "
                . "moved to $target. $source removal planned"
        );
    } else {
        return $self->_register_move($source, $target);
    }
}

sub _register_move {
    my ( $self, $source, $target ) = @_;

    my $target_to_source = $self->{target_to_source};
    my $source_to_target = $self->{source_to_target};

    carp "$source is already registered to move to " . $source_to_target->{$source}
        if exists $source_to_target->{$source};
    carp "$target is already registered as a target for move of " . $target_to_source->{$target}
        if exists $target_to_source->{$target};

    $source_to_target->{$source} = $target;
    $target_to_source->{$target} = $source;
    $self->{dirs_to_create}->{dirname($target)} = 1;
    return $target;
}

sub _register_delete {
    my ( $self, $source_to_delete, $message ) = @_;

    my $delete_descriptor = $self->{sources_to_delete}->{$source_to_delete};
    if ($delete_descriptor) {
        __log("$source_to_delete is already scheduled to be deleted: " . $delete_descriptor->{message});
        return $delete_descriptor->{trash_file_path};
    }

    my $trash_directory = $self->{trash_directory};
    my (undef, $relative_file_path_to_delete) = __get_common_path($source_to_delete, $trash_directory);
    my $trash_file_path = $trash_directory . $relative_file_path_to_delete;
    my ($name, $trash_directory_path) = fileparse($trash_file_path);

    $self->{sources_to_delete}->{$source_to_delete} = {
        message => $message,
        trash_file_path => $trash_file_path
    };
    $self->{dirs_to_create}->{$trash_directory_path} = 1;
    return $trash_file_path;
}

sub _source_is_registered {
    my ( $self, $source ) = @_;
    return exists $self->{source_to_target}->{$source};
}

sub _try_deregister_move {
    my ( $self, $target ) = @_;

    my $target_to_source = $self->{target_to_source};
    my $source_to_target = $self->{source_to_target};

    my $source = delete $target_to_source->{$target};
    delete $source_to_target->{$source} if $source;
    return $source;
}

sub _get_conflicted_source {
    my ( $self, $target ) = @_;

    my $conflicted_source = $self->_try_deregister_move($target);
    return $conflicted_source if $conflicted_source;

    return $target if -e $target and not exists $self->{sources_to_delete}->{$target};
    return undef;
}

sub __insert_digest {
    my ( $file_path, $digest ) = @_;

    my ($name, $directory_path, $extension) = fileparse($file_path, qr/\.[^\.\/]*/);
    return $directory_path . $name . '-' . $digest . lc($extension // '');
}

sub __get_common_path {
    my ( $pathA, $pathB ) = @_;
    "$pathA\0$pathB" =~ m/^(.*\/).*\0\1/s;
    my $common_prefix = $1;

    if($common_prefix) {
        my $prefix_length = length $common_prefix;
        return ($common_prefix, substr($pathA, $prefix_length), substr($pathB, $prefix_length));
    } else {
        return (undef, $pathA, $pathB);
    }
}

sub __trace {
    #say @_;
}

sub __log {
    #say @_;
}

sub __warn {
    say @_;
}

1;