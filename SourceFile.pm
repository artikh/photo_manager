package Source;

use base qw(FileDescriptor);

use Image::ExifTool qw(:Public);
use DateTime;
use Digest::MD5;

use constant EXIF_FIELDS => qw(DateTimeOriginal DateTimeDigitized DateTime FileModifyDate);

my $exifTool = Image::ExifTool->new;
$exifTool->Options(DateFormat => '%Y,%m,%d,%H,%M,%S,%z');

sub new {
    my ($class, $path, $source) = @_;
    my $self = $class->SUPER::new($path);
    $self->{source} = $source;
    return $self;
}

sub target_path {
    my ( $self) = @_;
    return $self->{target_path} //=
        $self->_get_full_path(
            $self->_get_datetime_relative_path($self->{path}),
            __get_extension($self->{path})
        );
}

sub target_path_with_digest {
    my ( $self ) = @_;
    return __get_file_digest($self->{path});
}

sub _get_full_path {
    my $self = shift;
    return join '', $self->{source}{target_directory}, @_;
}

sub _get_datetime_relative_path {
    my ( $self ) = @_;
    my $canonical_datetime = $self->_get_canonical_datetime();
    die $self->{path} . " have not date info" unless $canonical_datetime;

    return  $canonical_datetime->strftime('%Y/%m.%B/%Y%m%d%H%M%S');
}

sub _get_canonical_datetime {
    my ( $self ) = @_;

    my $info = $exifTool->ImageInfo($self->{file_path}, EXIF_FIELDS);

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