package SSN::Validate;

use 5.006;
use strict;
use warnings;

#require Exporter;
#use AutoLoader qw(AUTOLOAD);

#our @ISA = qw(Exporter);

# Items to export into callers namespace by default. Note: do not export
# names by default without a very good reason. Use EXPORT_OK instead.
# Do not simply export all your public functions/methods/constants.

our $VERSION = '0.01';

# Preloaded methods go here.

# Data won't change, no need to _init() for every object
my $SSN = _init();

sub new {
        my $proto = shift;
        my $args = shift;

        my $class = ref($proto) || $proto;
        my $self = {};
        bless ($self, $class);

        $self->{'SSN'}      = $SSN;

        return $self;
}

sub valid_ssn {
    my $self = shift;
    my $ssn  = shift;
   
    $ssn =~ s!\D!!g;
   
    if (length $ssn != 9) {
        $self->{'ERROR'} = "Bad SSN length";
        return 0;
    }
   
    my $area = substr($ssn, 0, 3);
    my $group = substr($ssn, 3, 2);
    my $serial = substr($ssn, 5, 4);
   
    if (!$self->valid_area($area)) {
        $self->{'ERROR'} = "Bad Area";
        return 0;
    } elsif(!$self->valid_group($group)) {
        $self->{'ERROR'} = "Bad Group";
        return 0;
    } elsif(!$self->valid_serial($serial)) {
        $self->{'ERROR'} = "Bad Serial";
        return 0;
    } else {
        return 1;
    }

}

sub valid_area {
    my $self = shift;
    my $area = shift;

    return exists $self->{'SSN'}->{$area} ? 1 : 0;
}

sub valid_group {
    my $self = shift;
    my $group = shift;

    return $group eq '00' ? 0 : 1;
}

sub valid_serial {
    my $self = shift;
    my $serial = shift;

    return $serial eq '0000' ? 0 : 1;
}
   
sub get_state {
    my $self = shift;
    my $ssn = shift;

    my $area = substr($ssn, 0, 3);

    if ($self->valid_area($area)) {
        return $self->{'SSN'}->{$area}->{'state'};
    } else {
        return '';
    }
}

sub get_description {
    my $self = shift;
    my $ssn = shift;

    my $area = substr($ssn, 0, 3);

    if ($self->valid_area($area)) {
        return $self->{'SSN'}->{$area}->{'description'};
    } else {
        return 0;
    }
}

sub _init {
    my %by_ssn;

	no warnings 'once';

    # parse data into memory...
    while(<DATA>) {
        chomp;

        # skip stuff that doesn't "look" like our data
        next unless m/[^0-9]{3}/;

        #my ($numeric, $state_abbr, $description) = split "\t", $_, 3;
        my ($numeric, $state_abbr, $description) = split /\s+/, $_, 3;

        # deal with the numeric stuff...
        $numeric =~ s/[^0-9,-]//;   # sanitize for fun

        # loop over , groups, if any...
        for my $group (split ',', $numeric) {
            # pull apart hypened ranges
            my ($min, $max) = split '-', $group;

            # see whether a range to deal with exists...
            if (defined $max) {
                for my $number ($min .. $max) {
                    $by_ssn{$number} = {
                        'state' => $state_abbr,
                        'description' => $description,
                    };
                }
            } else {
                $by_ssn{$min} = {
                    'state' => $state_abbr,
                    'description' => $description,
                };
            }
        }
    }

    return \%by_ssn;
}

# Autoload methods go after =cut, and are processed by the autosplit program.

1;

# Below is stub documentation for your module. You better edit it!

=pod

=head1 NAME

SSN::Validate - Perl extension do SSN Validation

=head1 SYNOPSIS

  use SSN::Validate;

  my $ssn = new SSN::Validate;

  if ($ssn->valid_ssn("123-45-6789")) {
    print "It's a valid SSN";
  }

  my $state = $ssn->get_state("123456789");	
  my $state = $ssn->get_state("123");	

=head1 DESCRIPTION

This module is intented to do some Social Security Number validation (not
verification) beyond just seeing if it contains 9 digits and isn't all 0s. The
data is taken from the Social Security Admin. website, specifically:

http://www.ssa.gov/foia/stateweb.html

As of this initial version, SSNs are validated by ensuring it is 9 digits, the
area, group and serial are not all 0s, and that the area is within a valid
range used by the SSA.

It will also return the state which the SSN was issues, if that data is known
(state of "??" for unknown states/regions).

A SSN is formed by 3 parts, the area (A), group (G) and serial (S):

AAAA-GG-SSSS

=head2 METHODS

=over 4

=item valid_ssn($ssn);

The SSN can be of any format (111-11-1111, 111111111, etc...). All non-digits
are stripped.

This method will return true if it is valid, and false if it isn't.

=item valid_area($ssn);

This will see if the area is valid by using the ranges in use by the SSA. You
can pass this method a full SSN, or just the 3 digit area.

=item valid_group($group);

This is currently only making sure the group isn't "00". It will later check
the High Groups in use by the SSA for areas.

Right now, this method expects an actual 2 digit group. Later versions will
take a full SSN since groups tie together with areas, and the area will be
needed to validate the group more than just checking for "00".

So, this method is only semi-useful right now to you. High Groups are shown
here:

http://www.ssa.gov/foia/highgroup.htm

Patches welcome!

=item valid_serial($serial);

This is currently only making sure the serial isn't "0000", and that's all it
will ever do. From my reading, "0000" is the only non-valid serial.

This is also semi-useful right now, as it expects only 4 digits. Later it will
take both 4 digits or a full serial.

=item get_state($ssn);

You can give this a full SSN or 3 digit area. It will return the state, if
known, from where the given area is issued. 

=item get_description($ssn);

If there is a description associated with the state or region, this will return
it.. or will return an empty string.

=back

=head2 TODO

* Change how the data is stored. I don't like how it is done now... but works.
* Add verification of valid High Groups.
* Find out state(s) for areas which aren't known right now.

=head2 EXPORT

None by default.


=head1 AUTHOR

Kevin Meltzer, E<lt>kmeltz@cpan.org<gt>

=head1 SEE ALSO

L<perl>.

=cut

# store SSN information inside the script down here...
#
# format is simple, three bits of data separated by tabs:
# numeric_range   state_abbr   description
#
# Leave state_abbr empty if not applicable.  numeric_range consits
# of three-digit numbers, with -'s to denote ranges and ,'s to denote
# series of numbers or ranges.
__DATA__
001-003 NH  New Hampshire
004-007 ME  Maine
008-009 VT  Vermont
010-034 MA  Massachusetts
035-039 RI  Rhode Island
040-049 CT  Connecticut
050-134 NY  New York
135-158 NJ  New Jersey
159-211 PA  Pennsylvania
212-220 MD  Maryland
221-222 DE  Delaware
223-231 VA  Virginia
691-699     New area allocated, but not yet issued
232-236 WV  West Virginia
232 NC  North Carolina
237-246	??	Unknown
681-690     New area allocated, but not yet issued
247-251 SC  South Carolina
654-658	??	Unknown
252-260 GA  Georgia
667-675	??	Unknown
261-267 FL  Florida
589-595	??	Unknown
268-302 OH  Ohio
303-317 IN  Indiana
318-361 IL  Illinois
362-386 MI  Michigan
387-399 WI  Wisconsin
400-407 KY  Kentucky
408-415 TN  Tennessee
756-763     New area allocated, but not yet issued
416-424 AL  Alabama
425-428 MS  Mississippi
587	??	Unknown
588     New area allocated, but not yet issued
752-755     New area allocated, but not yet issued
429-432 AR  Arkansas
676-679     New area allocated, but not yet issued
433-439 LA  Louisiana
659-665     New area allocated, but not yet issued
440-448 OK  Oklahoma
449-467 TX  Texas
627-645	??	Unknown
468-477 MN  Minnesota
478-485 IA  Iowa
486-500 MO  Missouri
501-502 ND  North Dakota
503-504 SD  South Dakota
505-508 NE  Nebraska
509-515 KS  Kansas
516-517 MT  Montana
518-519 ID  Idaho
520 WY  Wyoming
521-524 CO  Colorado
650-653     New area allocated, but not yet issued
525,585 NM  New Mexico
648-649	??	Unknown
526-527 AZ  Arizona
600-601	??	Unknown
764	??	Unknown
765	??	Unknown
528-529 UT  Utah
646-647	??	Unknown
530 NV  Nevada
680	??	Unknown
531-539 WA  Washington
540-544 OR  Oregon
545-573 CA  California
602-626	??	Unknown
574 AK  Alaska
575-576 HI  Hawaii
750-751     New area allocated, but not yet issued
577-579 DC  District of Columbia
580 VI  Virgin Islands
581-584 PR  Puerto Rico
596-599	??	Unknown
586 GU  Guam
586 AS  American Somoa
586 PI    Philippine Islands
700-728  RB   Railroad Board (discontinued July 1, 1963)
