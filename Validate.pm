package SSN::Validate;

use 5.006;
use strict;
use warnings;

our $VERSION = '0.07';

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

SSN::Validate - Perl extension do SSN Validation

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

* Add 'invalid' param to new() to allow showing assigned, but not
issued, AREAs as valid. The SSA considers them invalid, but someone may
want to have the included.

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
001,02
002,02
003,98
004,06
005,06
006,04
007,04
008,88
009,88
010,88
011,88
012,88
013,88
014,88
015,88
016,88
017,88
018,88
019,88
020,88
021,88
022,86
023,86
024,86
025,86
026,86
027,86
028,86
029,86
030,86
031,86
032,86
033,86
034,86
035,70
036,70
037,70
038,70
039,68
040,08
041,08
042,08
043,06
044,06
045,06
046,06
047,06
048,06
049,06
050,94
051,94
052,94
053,94
054,94
055,94
056,94
057,94
058,94
059,94
060,94
061,94
062,94
063,94
064,94
065,94
066,94
067,94
068,94
069,94
070,94
071,94
072,94
073,94
074,94
075,94
076,94
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
116,92
117,92
118,92
119,92
120,92
121,92
122,92
123,92
124,92
125,92
126,92
127,92
128,92
129,92
130,92
131,92
132,92
133,92
134,92
135,15
136,15
137,15
138,15
139,15
140,15
141,15
142,15
143,15
144,13
145,13
146,13
147,13
148,13
149,13
150,13
151,13
152,13
153,13
154,13
155,13
156,13
157,13
158,13
159,82
160,82
161,82
162,82
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
211,80
212,71
213,71
214,71
215,71
216,71
217,69
218,69
219,69
220,69
221,02
222,98
223,99
224,99
225,99
226,99
227,99
228,99
229,99
230,99
231,99
232,51
233,51
234,51
235,51
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
268,11
269,11
270,11
271,11
272,11
273,11
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
285,08
286,08
287,08
288,08
289,08
290,08
291,08
292,08
293,08
294,08
295,08
296,08
297,08
298,08
299,08
300,08
301,08
302,08
303,29
304,29
305,29
306,29
307,27
308,27
309,27
310,27
311,27
312,27
313,27
314,27
315,27
316,27
317,27
318,04
319,04
320,04
321,04
322,04
323,04
324,04
325,04
326,04
327,04
328,04
329,04
330,04
331,04
332,04
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
345,02
346,02
347,02
348,02
349,02
350,02
351,02
352,02
353,02
354,02
355,02
356,02
357,02
358,02
359,02
360,02
361,02
362,31
363,31
364,31
365,31
366,31
367,31
368,31
369,31
370,31
371,31
372,31
373,31
374,29
375,29
376,29
377,29
378,29
379,29
380,29
381,29
382,29
383,29
384,29
385,29
386,29
387,25
388,25
389,25
390,25
391,25
392,25
393,25
394,25
395,25
396,25
397,23
398,23
399,23
400,63
401,63
402,63
403,63
404,63
405,61
406,61
407,61
408,99
409,99
410,99
411,97
412,97
413,97
414,97
415,97
416,57
417,57
418,57
419,57
420,57
421,57
422,57
423,57
424,57
425,97
426,95
427,95
428,95
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
441,19
442,19
443,19
444,19
445,19
446,19
447,19
448,19
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
468,45
469,45
470,45
471,45
472,45
473,45
474,45
475,45
476,43
477,43
478,35
479,35
480,35
481,33
482,33
483,33
484,33
485,33
486,23
487,21
488,21
489,21
490,21
491,21
492,21
493,21
494,21
495,21
496,21
497,21
498,21
499,21
500,21
501,31
502,29
503,37
504,35
505,49
506,47
507,47
508,47
509,25
510,23
511,23
512,23
513,23
514,23
515,23
516,41
517,39
518,71
519,69
520,49
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
531,55
532,55
533,55
534,55
535,55
536,55
537,55
538,53
539,53
540,67
541,67
542,67
543,67
544,67
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
574,41
575,99
576,99
577,39
578,37
579,37
580,35
581,99
582,99
583,99
584,99
585,99
586,55
587,95
589,99
590,99
591,99
592,99
593,99
594,99
595,99
596,78
597,76
598,76
599,76
600,99
601,99
602,49
603,49
604,49
605,49
606,49
607,49
608,49
609,47
610,47
611,47
612,47
613,47
614,47
615,47
616,47
617,47
618,47
619,47
620,47
621,47
622,47
623,47
624,47
625,47
626,47
627,94
628,94
629,94
630,94
631,94
632,94
633,94
634,94
635,94
636,94
637,94
638,94
639,92
640,92
641,92
642,92
643,92
644,92
645,92
646,80
647,78
648,36
649,34
650,34
651,34
652,32
653,32
654,20
655,18
656,18
657,18
658,18
659,10
660,10
661,10
662,09
663,09
664,09
665,09
667,24
668,24
669,24
670,24
671,24
672,24
673,24
674,22
675,22
676,09
677,09
678,07
679,07
680,62
681,07
682,05
683,05
684,05
685,05
686,05
687,05
688,05
689,05
690,05
691,01
692,01
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
729,03
730,03
731,03
732,03
733,03
750,01
751,01
764,48
765,48
766,36
767,36
768,34
769,34
770,34
771,34
772,34
900,70-80 ## Individual Taxpayer Identification Number
900,93-93 ## Adoption Taxpayer Identification Number
