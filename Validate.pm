package SSN::Validate;

use 5.006;
use strict;
use warnings;

our $VERSION = '0.15';

# Preloaded methods go here.

# Data won't change, no need to _init() for every object
my $SSN = _init();

## "Within each area, the group number (middle two (2) digits) 
##  range from 01 to 99 but are not assigned in consecutive 
##  order. For administrative reasons, group numbers issued 
##  first consist of the ODD numbers from 01 through 09 and 
##  then EVEN numbers from 10 through 98, within each area 
##  number allocated to a State. After all numbers in group 98 
##  of a particular area have been issued, the EVEN Groups 02 
##  through 08 are used, followed by ODD Groups 11 through 99."
##
##  ODD - 01, 03, 05, 07, 09 
##  EVEN - 10 to 98
##  EVEN - 02, 04, 06, 08 
##  ODD - 11 to 99
my $GROUP_ORDER = [
    '01', '03', '05', '07', '09', 10,   12, 14, 16, 18, 20, 22,
    24,   26,   28,   30,   32,   34,   36, 38, 40, 42, 44, 46,
    48,   50,   52,   54,   56,   58,   60, 62, 64, 66, 68, 70,
    72,   74,   76,   78,   80,   82,   84, 86, 88, 90, 92, 94,
    96,   98,   '02', '04', '06', '08', 11, 13, 15, 17, 19, 21,
    23,   25,   27,   29,   31,   33,   35, 37, 39, 41, 43, 45,
    47,   49,   51,   53,   55,   57,   59, 61, 63, 65, 67, 69,
    71,   73,   75,   77,   79,   81,   83, 85, 87, 89, 91, 93,
    95,   97,   99
];

my $ADVERTISING_SSN = [
	'042103580', 
	'062360749', 
	'078051120', 
	'095073645', 
	128036045, 
	135016629, 
	141186941, 
	165167999, 
	165187999, 
	165207999, 
	165227999, 
	165247999, 
	189092294, 
	212097694, 
	212099999, 
	306302348, 
	308125070, 
	468288779, 
	549241889, 
  987654320,
  987654321,
  987654322,
  987654323,
  987654324,
  987654325,
  987654326,
  987654327,
  987654328,
  987654329,
];

my $BAD_COMBO = [
	55019,
	58619,
	58629,
	58659,
	58659,
	58679..58699
];

sub new {
    my ( $proto, $args ) = @_;

    my $class = ref($proto) || $proto;
    my $self = {};
    bless( $self, $class );

    $self->{'SSN'}                = $SSN;
    $self->{'GROUP_ORDER'}        = $GROUP_ORDER;
    $self->{'AD_SSN'}             = $ADVERTISING_SSN;
    $self->{'BAD_COMBO'}          = $BAD_COMBO;
    $self->{'BAD_COMBO_IGNORE'}   = $args->{'ignore_bad_combo'} || 0;

    return $self;
}

sub valid_ssn {
    my ( $self, $ssn ) = @_;

    $ssn =~ s!\D!!g;

    if ( length $ssn != 9 ) {
        $self->{'ERROR'} = "Bad SSN length";
        return 0;
    }

	# Check for known invalid SSNs
	# Start with Advertising SSNs. The SSA suggests the range of
	# 987-65-4320 thru 987-65-4329 but these have also been used
	# in ads.

	if (in_array($ssn, $self->{'AD_SSN'})) {
		$self->{'ERROR'} = 'Advertising SSN';
		return 0;
	}

    my $area   = substr( $ssn, 0, 3 );
    my $group  = substr( $ssn, 3, 2 );
    my $serial = substr( $ssn, 5, 4 );

	# Some groups are invalid with certain areas.
	# Rhyme and reason are not a part of the SSA.

	if (!$self->{'BAD_COMBO_IGNORE'} && in_array($area . $group, $self->{'BAD_COMBO'})) {
		$self->{'ERROR'} = 'Invalid area/group combo';
		return 0;
	}
				
    if ( !$self->valid_area($area) ) {
        $self->{'ERROR'} = "Bad Area";
        return 0;
    }
    elsif ( !$self->valid_group($ssn) ) {
        $self->{'ERROR'} = "Bad Group";
        return 0;
    }
    elsif ( !$self->valid_serial($serial) ) {
        $self->{'ERROR'} = "Bad Serial";
        return 0;
    }
    else {
        return 1;
    }

}

sub valid_area {
    my ( $self, $area ) = @_;

		$area = substr( $area, 0, 3) if length $area > 3;

    return exists $self->{'SSN'}->{$area}->{valid} ? 1 : 0;
}

sub valid_group {
    my ( $self, $group ) = @_;

		$group =~ s!\D!!g;

    #if ( length $group == 9 ) {
    if ( length $group > 2 ) {
        my $area = substr( $group, 0, 3 );
        $group = substr( $group, 3, 2 );
        return 0 if $group eq '00';

				if (!$self->{'BAD_COMBO_IGNORE'} && in_array($area . $group, $self->{'BAD_COMBO'})) {
					$self->{'ERROR'} = 'Invalid area/group combo';
					return 0;
				}

        if ( defined $self->{'SSN'}{$area}{'highgroup'} ) {
						# We're igno
					  if ($self->{'BAD_COMBO_IGNORE'} && in_array($area . $group, $self->{'BAD_COMBO'})) {
							return 1;
						}

            return in_array( $group,
                $self->get_group_range( $self->{'SSN'}{$area}{'highgroup'} ) );
        }
        elsif ( defined $self->{'SSN'}{$area}{'group_range'} ) {
            return in_array( $group, $self->{'SSN'}{$area}{'group_range'} );
        }
        else {
            return 1;
        }

    }
    return $group eq '00' ? 0 : 1;
}

sub valid_serial {
    my ( $self, $serial ) = @_;

    return $serial eq '0000' ? 0 : 1;
}

sub get_state {
    my ( $self, $ssn ) = @_;

    my $area = substr( $ssn, 0, 3 );

    if ( $self->valid_area($area) ) {
        return defined $self->{'SSN'}->{$area}->{'state'} 
        	     ? $self->{'SSN'}->{$area}->{'state'} : '';
    }
    else {
        return '';
    }
}

sub get_description {
    my ( $self, $ssn ) = @_;

    my $area = substr( $ssn, 0, 3 );

    if ( $self->valid_area($area) ) {
        return $self->{'SSN'}->{$area}->{'description'};
    }
    else {
        return 0;
    }
}

## given a high group number, generate a list of valid
## group numbers using that wild and carazy SSA algorithm.
sub get_group_range {
    my ( $self, $highgroup ) = @_;

    for ( my $i = 0 ; $i < 100 ; $i++ ) {
        if (
            sprintf( "%02d", $self->{'GROUP_ORDER'}[$i] ) ==
            sprintf( "%02d", $highgroup ) )
        {
            return [ @{ $self->{'GROUP_ORDER'} }[ 0 .. $i + 1 ] ]; # array slice
        }
    }

    return [];
}

sub in_array {
    my ( $needle, $haystack ) = @_;

    foreach my $hay (@$haystack) {
        return 1 if $hay == $needle;
    }
    return 0;
}

sub _init {
    my %by_ssn;

    no warnings 'once';

    # parse data into memory...
    while (<DATA>) {
        chomp;

        # skip stuff that doesn't "look" like our data
        next unless m/^[0-9]{3}/;

        if (/^(\d{3}),(\d{2})\-*(\d*)\D*$/) {
            if ( !defined $3 || $3 eq '' ) {
                $by_ssn{$1}->{'highgroup'} = $2;
            }
            else {
                if ( defined $by_ssn{$1}->{'group_range'} ) {
                    push @{ $by_ssn{$1}->{'group_range'} }, ( $2 .. $3 );
                }
                else {
                    $by_ssn{$1}->{'group_range'} = [ $2 .. $3 ];
                }
            }
            next;
        }

        my ( $numeric, $state_abbr, $description ) = split /\s+/, $_, 3;

        # deal with the numeric stuff...
        $numeric =~ s/[^0-9,-]//;    # sanitize for fun

        # loop over , groups, if any...
        for my $group ( split ',', $numeric ) {

					  # Skip over invalid ranges. Although they may be assigned
						# if they are not yet issued, then no one has an area from
						# it, so it is invalid by the SSA. 
						# May make a 'loose' bit to allow these to validate
						next if $description =~ /not yet issued/i;

            # pull apart hypened ranges
            my ( $min, $max ) = split '-', $group;

            # see whether a range to deal with exists...
            if ( defined $max ) {
                for my $number ( $min .. $max ) {
                    $by_ssn{$number} = {
                        'state'       => $state_abbr,
                        'description' => $description,
												'valid'			  => 1,
                    };
                }
            }
            else {
                $by_ssn{$min} = {
                    'state'       => $state_abbr,
                    'description' => $description,
										'valid'			  => 1,
                };
            }
        }
    }

    return \%by_ssn;
}

# Autoload methods go after =cut, and are processed by the autosplit program.

1;

=pod

=head1 NAME

SSN::Validate - Perl extension to do SSN Validation

=head1 SYNOPSIS

  use SSN::Validate;

  my $ssn = new SSN::Validate;

  or 

  my $ssn = SSN::Validate->new({'ignore_bad_combo' => 1});

  if ($ssn->valid_ssn("123-45-6789")) {
    print "It's a valid SSN";
  }

  my $state = $ssn->get_state("123456789");	
  my $state = $ssn->get_state("123");	

	print $ssn->valid_area('123') ? "Valid" : "Invalid";
	print $ssn->valid_area('123-56-7890') ? "Valid" : "Invalid";

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

=item new();

You can pass an arg of 'ignore_bad_combo' as true if you wish to ignore
any defined bad AAAA-GG combinations. Things will be on the list until
I see otherwise on the SSA website or some other means of proof.

=item valid_ssn($ssn);

The SSN can be of any format (111-11-1111, 111111111, etc...). All non-digits
are stripped.

This method will return true if it is valid, and false if it isn't. It
uses the below methods to check the validity of each section.

=item valid_area($ssn);

This will see if the area is valid by using the ranges in use by the SSA. You
can pass this method a full SSN, or just the 3 digit area.

=item valid_group($group);

Will make sure that the group isn't "00", as well as check the
AREA/GROUP combo for known invalid ones, and the SSA High Groups.

If given a 2 digit GROUP, it will only make sure that that GROUP isn't
"00".

If given a number in length above 2 digits, it will attempt to split
into an AREA and GROUP and do further validation.

=item valid_serial($serial);

This is currently only making sure the serial isn't "0000", and that's all it
will ever do. From my reading, "0000" is the only non-valid serial.

This is also semi-useful right now, as it expects only 4 digits. Later it will
take both 4 digits or a full serial.

=item get_state($ssn);

You can give this a full SSN or 3 digit area. It will return the state, if
known, from where the given area is issued. Invalid areas will return
false.

=item get_description($ssn);

If there is a description associated with the state or region, this will return
it.. or will return an empty string.

=back

=head2 TODO

* Change how the data is stored. I don't like how it is done now... but works.

* Find out state(s) for areas which aren't known right now.

* Automate this module almost as completely as possible for
  distribution. 

* Consider SSN::Validate::SSDI for Social Security Death Index (SSDI)

* Possibly change how data is stored (first on TODO), and provide my
	extract script for people to run on their own. This way, maybe they
	could update the SSA changes on their own, instead of being dependant
	on the module for this, or having to update the module when the SSA
	makes changes. I think I like this idea.

=head2 EXPORT

None by default.

=head1 BUGS

Please let me know if something doesn't work as expected.

You can report bugs via the CPAN RT:
L<http://rt.cpan.org/NoAuth/Bugs.html?Dist=SSN-Validate>

If you are feeling nice, and would like quicker fixes, please provide a
diff against F<Validate.pm> and the appropriate test file(s). If you
are making something invalid which is currently valid, or vice versa,
please provide a reference to why the change is needed. Thanks!

Patches Welcome!

=head1 AUTHOR

Kevin Meltzer, E<lt>kmeltz@cpan.orgE<gt>

=head1 LICENSE

SSN::Validate is free software which you can redistribute and/or
modify it under the same terms as Perl itself.

=head1 SEE ALSO

L<http://www.ssa.gov/foia/stateweb.html>,
L<http://www.irs.gov/pub/irs-utl/1346atta.pdf>,
L<http://www.ssa.gov/employer/highgroup.txt>.

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
232 NC  North Carolina
232-236 WV West Virginia
237-246	??	Unknown
247-251 SC  South Carolina
252-260 GA  Georgia
261-267 FL  Florida
268-302 OH  Ohio
303-317 IN  Indiana
318-361 IL  Illinois
362-386 MI  Michigan
387-399 WI  Wisconsin
400-407 KY  Kentucky
408-415 TN  Tennessee
416-424 AL  Alabama
425-428 MS  Mississippi
429-432 AR  Arkansas
433-439 LA  Louisiana
440-448 OK  Oklahoma
449-467 TX  Texas
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
525 NM  New Mexico
585 NM  New Mexico
526-527 AZ  Arizona
528-529 UT  Utah
530 NV  Nevada
531-539 WA  Washington
540-544 OR  Oregon
545-573 CA  California
574 AK  Alaska
575-576 HI  Hawaii
577-579 DC  District of Columbia
580     VI Virgin Islands or Puerto Rico
581-584 PR  Puerto Rico
#586     GU Guam
#586     AS American Somoa
#586     PI Philippine Islands
586     ?? Guam, American Samoa, or Philippine Islands
587	?? Unknown
588     ?? New area allocated, but not yet issued
589-595	?? Unknown
596-599	??	Unknown
600-601	?? Unknown
602-626	?? Unknown
627-645	?? Unknown
646-647	?? Unknown
648-649	?? Unknown
650-653 ?? New area allocated, but not yet issued
654-658	?? Unknown
659-665 ?? New area allocated, but not yet issued
#666     ?? Unknown
667-675	?? Unknown
676-679 ?? New area allocated, but not yet issued
680	?? Unknown
681-690 ?? New area allocated, but not yet issued
691-699 ?? New area allocated, but not yet issued
700-728  RB   Railroad Board (discontinued July 1, 1963)
750-751 ?? New area allocated, but not yet issued
752-755 ?? New area allocated, but not yet issued
756-763 ?? New area allocated, but not yet issued
764-899	?? Unknown
#765	?? Unknown
900-999 ?? Taxpayer Identification Number
## high groups
# This is scraped directly from
# http://www.ssa.gov/employer/highgroup.txt
001,04
002,04
003,04
004,08
005,06
006,06
007,06
008,90
009,88
010,90
011,90
012,90
013,90
014,90
015,90
016,90
017,90
018,88
019,88
020,88
021,88
022,88
023,88
024,88
025,88
026,88
027,88
028,88
029,88
030,88
031,88
032,88
033,88
034,88
035,72
036,72
037,70
038,70
039,70
040,11
041,11
042,11
043,08
044,08
045,08
046,08
047,08
048,08
049,08
050,96
051,96
052,96
053,96
054,96
055,96
056,96
057,96
058,96
059,96
060,96
061,96
062,96
063,96
064,96
065,96
066,96
067,96
068,96
069,96
070,96
071,96
072,96
073,96
074,96
075,96
076,96
077,94
078,94
079,94
080,94
081,94
082,94
083,94
084,94
085,94
086,94
087,94
088,94
089,94
090,94
091,94
092,94
093,94
094,94
095,94
096,94
097,94
098,94
099,94
100,94
101,94
102,94
103,94
104,94
105,94
106,94
107,94
108,94
109,94
110,94
111,94
112,94
113,94
114,94
115,94
116,94
117,94
118,94
119,94
120,94
121,94
122,94
123,94
124,94
125,94
126,94
127,94
128,94
129,94
130,94
131,94
132,94
133,94
134,94
135,17
136,17
137,17
138,17
139,17
140,17
141,17
142,17
143,17
144,17
145,17
146,17
147,17
148,17
149,17
150,17
151,15
152,15
153,15
154,15
155,15
156,15
157,15
158,15
159,84
160,84
161,84
162,84
163,82
164,82
165,82
166,82
167,82
168,82
169,82
170,82
171,82
172,82
173,82
174,82
175,82
176,82
177,82
178,82
179,82
180,82
181,82
182,82
183,82
184,82
185,82
186,82
187,82
188,82
189,82
190,82
191,82
192,82
193,82
194,82
195,82
196,82
197,82
198,82
199,82
200,82
201,82
202,82
203,82
204,82
205,82
206,82
207,82
208,82
209,82
210,82
211,82
212,77
213,77
214,75
215,75
216,75
217,75
218,75
219,75
220,75
221,04
222,04
223,99
224,99
225,99
226,99
227,99
228,99
229,99
230,99
231,99
232,53
233,53
234,53
235,51
236,51
237,99
238,99
239,99
240,99
241,99
242,99
243,99
244,99
245,99
246,99
247,99
248,99
249,99
250,99
251,99
252,99
253,99
254,99
255,99
256,99
257,99
258,99
259,99
260,99
261,99
262,99
263,99
264,99
265,99
266,99
267,99
268,13
269,13
270,11
271,11
272,11
273,11
274,11
275,11
276,11
277,11
278,11
279,11
280,11
281,11
282,11
283,11
284,11
285,11
286,11
287,11
288,11
289,11
290,11
291,11
292,11
293,11
294,11
295,11
296,11
297,11
298,11
299,11
300,11
301,11
302,11
303,31
304,31
305,31
306,31
307,31
308,31
309,29
310,29
311,29
312,29
313,29
314,29
315,29
316,29
317,29
318,06
319,06
320,06
321,06
322,06
323,06
324,06
325,06
326,06
327,06
328,06
329,04
330,04
331,04
332,04
333,04
334,04
335,04
336,04
337,04
338,04
339,04
340,04
341,04
342,04
343,04
344,04
345,04
346,04
347,04
348,04
349,04
350,04
351,04
352,04
353,04
354,04
355,04
356,04
357,04
358,04
359,04
360,04
361,04
362,33
363,33
364,33
365,33
366,33
367,33
368,33
369,33
370,33
371,33
372,33
373,33
374,33
375,33
376,31
377,31
378,31
379,31
380,31
381,31
382,31
383,31
384,31
385,31
386,31
387,27
388,27
389,27
390,27
391,27
392,27
393,27
394,27
395,27
396,27
397,27
398,27
399,25
400,65
401,65
402,65
403,65
404,65
405,65
406,65
407,65
408,99
409,99
410,99
411,99
412,99
413,99
414,99
415,99
416,61
417,61
418,61
419,59
420,59
421,59
422,59
423,59
424,59
425,99
426,99
427,99
428,99
429,99
430,99
431,99
432,99
433,99
434,99
435,99
436,99
437,99
438,99
439,99
440,23
441,21
442,21
443,21
444,21
445,21
446,21
447,21
448,21
449,99
450,99
451,99
452,99
453,99
454,99
455,99
456,99
457,99
458,99
459,99
460,99
461,99
462,99
463,99
464,99
465,99
466,99
467,99
468,49
469,49
470,49
471,49
472,47
473,47
474,47
475,47
476,47
477,47
478,37
479,37
480,37
481,35
482,35
483,35
484,35
485,35
486,25
487,25
488,23
489,23
490,23
491,23
492,23
493,23
494,23
495,23
496,23
497,23
498,23
499,23
500,23
501,33
502,31
503,39
504,37
505,51
506,51
507,49
508,49
509,27
510,27
511,25
512,25
513,25
514,25
515,25
516,43
517,41
518,75
519,73
520,51
521,99
522,99
523,99
524,99
525,99
526,99
527,99
528,99
529,99
530,99
531,59
532,59
533,59
534,59
535,59
536,59
537,59
538,59
539,57
540,71
541,71
542,71
543,71
544,71
545,99
546,99
547,99
548,99
549,99
550,99
551,99
552,99
553,99
554,99
555,99
556,99
557,99
558,99
559,99
560,99
561,99
562,99
563,99
564,99
565,99
566,99
567,99
568,99
569,99
570,99
571,99
572,99
573,99
574,47
575,99
576,99
577,43
578,41
579,41
580,37
581,99
582,99
583,99
584,99
585,99
586,59
587,97
589,99
590,99
591,99
592,99
593,99
594,99
595,99
596,82
597,82
598,80
599,80
600,99
601,99
602,59
603,59
604,59
605,59
606,59
607,59
608,59
609,59
610,59
611,59
612,59
613,59
614,59
615,59
616,59
617,59
618,57
619,57
620,57
621,57
622,57
623,57
624,57
625,57
626,57
627,06
628,04
629,04
630,04
631,04
632,04
633,04
634,04
635,04
636,04
637,04
638,04
639,04
640,04
641,04
642,04
643,04
644,04
645,04
646,90
647,88
648,42
649,40
650,42
651,40
652,40
653,40
654,24
655,24
656,24
657,22
658,22
659,14
660,12
661,12
662,12
663,12
664,12
665,12
667,30
668,30
669,30
670,30
671,30
672,30
673,30
674,30
675,30
676,12
677,10
678,10
679,10
680,80
681,10
682,10
683,10
684,10
685,10
686,10
687,10
688,10
689,09
690,09
691,05
692,05
693,05
694,05
695,05
696,05
697,03
698,03
699,03
700,18
701,18
702,18
703,18
704,18
705,18
706,18
707,18
708,18
709,18
710,18
711,18
712,18
713,18
714,18
715,18
716,18
717,18
718,18
719,18
720,18
721,18
722,18
723,18
724,28
725,18
726,18
727,10
728,14
729,07
730,07
731,07
732,07
733,07
750,07
751,05
756,03
757,03
758,03
759,03
760,01
761,01
762,01
763,01
764,70
765,68
766,54
767,54
768,54
769,52
770,52
771,52
772,52
900,70-80 ## Individual Taxpayer Identification Number
900,93-93 ## Adoption Taxpayer Identification Number
