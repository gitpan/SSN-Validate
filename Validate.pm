package SSN::Validate;

use 5.006;
use strict;
use warnings;

our $VERSION = '0.03';

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

    $self->{'SSN'}         = $SSN;
    $self->{'GROUP_ORDER'} = $GROUP_ORDER;
    $self->{'AD_SSN'}      = $ADVERTISING_SSN;
    $self->{'BAD_COMBO'}   = $BAD_COMBO;

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

	if (in_array($area . $group, $self->{'BAD_COMBO'})) {
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

    return exists $self->{'SSN'}->{$area} ? 1 : 0;
}

sub valid_group {
    my ( $self, $group ) = @_;

    if ( length $group == 9 ) {
        my $area = substr( $group, 0, 3 );
        $group = substr( $group, 3, 2 );
        return 0 if $group eq '00';

        if ( defined $self->{'SSN'}{$area}{'highgroup'} ) {
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
        return $self->{'SSN'}->{$area}->{'state'};
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
                    };
                }
            }
            else {
                $by_ssn{$min} = {
                    'state'       => $state_abbr,
                    'description' => $description,
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
known, from where the given area is issued. Invalid areas will return
false.

=item get_description($ssn);

If there is a description associated with the state or region, this will return
it.. or will return an empty string.

=back

=head2 TODO

* Change how the data is stored. I don't like how it is done now... but works.
* Find out state(s) for areas which aren't known right now.
* Incorporate SSA scraping to update module data (script from Benjamin
  R. Ginter)

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
525,585 NM  New Mexico
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
666     ?? Unknown
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
001,98
002,98
003,96
004,04
005,04
006,04
007,02
008,86
009,86
010,86
011,86
012,86
013,86
014,86
015,86
016,86
017,86
018,86
019,86
020,86
021,86
022,86
023,86
024,86
025,86
026,86
027,86
028,86
029,86
030,84
031,84
032,84
033,84
034,84
035,70
036,70
037,68
038,68
039,68
040,06
041,06
042,06
043,06
044,04
045,04
046,04
047,04
048,04
049,04
050,92
051,92
052,92
053,92
054,92
055,92
056,92
057,92
058,92
059,92
060,92
061,92
062,92
063,92
064,92
065,92
066,92
067,92
068,92
069,92
070,92
071,92
072,92
073,92
074,92
075,92
076,92
077,92
078,92
079,92
080,92
081,92
082,92
083,92
084,92
085,92
086,92
087,92
088,92
089,92
090,92
091,92
092,92
093,92
094,92
095,92
096,92
097,92
098,92
099,92
100,92
101,92
102,92
103,92
104,92
105,92
106,92
107,92
108,92
109,92
110,92
111,92
112,92
113,92
114,92
115,92
116,90
117,90
118,90
119,90
120,90
121,90
122,90
123,90
124,90
125,90
126,90
127,90
128,90
129,90
130,90
131,90
132,90
133,90
134,90
135,13
136,13
137,13
138,13
139,13
140,13
141,13
142,13
143,11
144,11
145,11
146,11
147,11
148,11
149,11
150,11
151,11
152,11
153,11
154,11
155,11
156,11
157,11
158,11
159,80
160,80
161,80
162,80
163,80
164,80
165,80
166,80
167,80
168,80
169,80
170,80
171,80
172,80
173,80
174,80
175,80
176,80
177,80
178,80
179,80
180,80
181,80
182,80
183,80
184,80
185,80
186,80
187,80
188,80
189,80
190,80
191,80
192,80
193,80
194,80
195,80
196,80
197,80
198,80
199,80
200,80
201,80
202,80
203,80
204,80
205,80
206,80
207,80
208,80
209,80
210,80
211,78
212,67
213,67
214,67
215,67
216,67
217,65
218,65
219,65
220,65
221,98
222,96
223,97
224,97
225,97
226,95
227,95
228,95
229,95
230,95
231,95
232,49
233,49
234,49
235,49
236,49
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
268,08
269,08
270,08
271,08
272,08
273,08
274,08
275,08
276,08
277,08
278,08
279,08
280,08
281,08
282,08
283,08
284,08
285,06
286,06
287,06
288,06
289,06
290,06
291,06
292,06
293,06
294,06
295,06
296,06
297,06
298,06
299,06
300,06
301,06
302,06
303,27
304,27
305,27
306,27
307,27
308,25
309,25
310,25
311,25
312,25
313,25
314,25
315,25
316,25
317,25
318,02
319,02
320,02
321,02
322,02
323,02
324,02
325,02
326,02
327,02
328,02
329,02
330,02
331,02
332,02
333,02
334,02
335,02
336,02
337,02
338,02
339,02
340,02
341,02
342,02
343,02
344,02
345,98
346,98
347,98
348,98
349,98
350,98
351,98
352,98
353,98
354,98
355,98
356,98
357,98
358,98
359,98
360,98
361,98
362,29
363,29
364,29
365,29
366,29
367,29
368,29
369,29
370,29
371,29
372,29
373,29
374,29
375,29
376,27
377,27
378,27
379,27
380,27
381,27
382,27
383,27
384,27
385,27
386,27
387,23
388,23
389,23
390,23
391,23
392,23
393,23
394,23
395,23
396,23
397,23
398,23
399,21
400,61
401,61
402,61
403,59
404,59
405,59
406,59
407,59
408,95
409,95
410,95
411,95
412,95
413,95
414,93
415,93
416,55
417,55
418,55
419,55
420,55
421,55
422,55
423,55
424,53
425,93
426,93
427,93
428,93
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
440,19
441,17
442,17
443,17
444,17
445,17
446,17
447,17
448,17
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
468,43
469,43
470,43
471,43
472,43
473,41
474,41
475,41
476,41
477,41
478,33
479,33
480,33
481,33
482,33
483,31
484,31
485,31
486,21
487,21
488,21
489,19
490,19
491,19
492,19
493,19
494,19
495,19
496,19
497,19
498,19
499,19
500,19
501,29
502,29
503,35
504,33
505,47
506,45
507,45
508,45
509,23
510,23
511,21
512,21
513,21
514,21
515,21
516,39
517,37
518,67
519,65
520,47
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
531,53
532,51
533,51
534,51
535,51
536,51
537,51
538,51
539,51
540,65
541,65
542,63
543,63
544,63
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
574,39
575,97
576,95
577,35
578,35
579,35
580,35
581,99
582,99
583,99
584,99
585,99
586,51
587,91
589,99
590,99
591,99
592,99
593,99
594,99
595,99
596,74
597,72
598,72
599,72
600,99
601,99
602,39
603,39
604,39
605,39
606,39
607,39
608,39
609,39
610,39
611,39
612,39
613,39
614,39
615,39
616,39
617,39
618,39
619,39
620,39
621,39
622,39
623,39
624,39
625,39
626,39
627,88
628,88
629,86
630,86
631,86
632,86
633,86
634,86
635,86
636,86
637,86
638,86
639,86
640,86
641,86
642,86
643,86
644,86
645,86
646,72
647,70
648,32
649,30
650,28
651,28
652,26
653,26
654,16
655,16
656,14
657,14
658,14
659,07
660,07
661,07
662,07
663,07
664,07
665,07
667,20
668,20
669,18
670,18
671,18
672,18
673,18
674,18
675,18
676,05
677,05
678,05
679,03
680,50
681,01
682,01
683,01
684,01
685,01
686,01
687,03
688,01
689,01
690,01
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
729,01
730,01
764,32
765,32
766,22
767,22
768,22
769,22
770,20
900,70-80 ## Individual Taxpayer Identification Number
900,93-93 ## Adoption Taxpayer Identification Number
