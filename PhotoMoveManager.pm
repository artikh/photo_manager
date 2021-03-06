package PhotoMoveManager;

use 5.016;
use strict;
use warnings;
use autodie;

use base 'MoveManager';

use Image::ExifTool qw(:Public);
use DateTime;
use Digest::MD5;

use constant EXIF_FIELDS => qw(DateTimeOriginal DateTimeDigitized DateTime FileModifyDate);

sub new {
    my $class = shift;
    my $self = $class->SUPER::new(@_);

    my $exifTool = Image::ExifTool->new;
    $exifTool->Options(DateFormat => '%Y,%m,%d,%H,%M,%S,%z');
    $self->{exifTool} = $exifTool;
    return $self;
}

sub get_target {
    my ( $self, $source_file_path ) = @_;
    return $self->get_full_path(
        $self->_get_datetime_relative_path($source_file_path),
        __get_extension($source_file_path)
    );
}

sub get_digest {
    my ( $self, $file_path ) = @_;
    return __get_file_digest($file_path);
}

sub _get_datetime_relative_path {
    my ( $self, $file_path ) = @_;

    my $canonical_datetime = $self->_get_canonical_datetime($file_path);
    die "$file_path have not date info" unless $canonical_datetime;

    return  $canonical_datetime->strftime('%Y/%m.%B/%Y%m%d%H%M%S');
}

sub _get_canonical_datetime {
    my ( $self, $file_path ) = @_;

    my $info = $self->{exifTool}->ImageInfo($file_path, EXIF_FIELDS);

    my $canonical_datetime;
    for my $field_name (EXIF_FIELDS) {
        $canonical_datetime = __parse_exif_date($info->{$field_name});
        return $canonical_datetime if $canonical_datetime;
    }
}

sub __get_file_digest {
    my ( $file_path ) = @_;

    my $md5 = Digest::MD5->new;
    open (my $file_handle, '<', $file_path);
    binmode($file_handle);
    $md5->addfile($file_handle);
    return $md5->hexdigest;
}

sub __get_extension {
    my ( $file_path ) = @_;
    my ($extension) = $file_path =~ /(\.[^.]+)$/;
    return lc($extension) // '';
}

sub __parse_exif_date {
    my ( $date_string ) = @_;
    return unless $date_string;
    my ($year, $month, $day, $hour, $minute, $second, $timezone) =
        split /,/, $date_string;
    return undef unless $year and $month and $day and $hour;
    return DateTime->new(
        year       => $year,
        month      => $month,
        day        => $day,
        hour       => $hour,
        minute     => $minute,
        second     => $second,
        time_zone  => $timezone
    );
}

1;