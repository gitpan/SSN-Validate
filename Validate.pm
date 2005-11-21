package SSN::Validate;

use 5.006;
use strict;
use warnings;

our $VERSION = '0.13';

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
002,02
003,02
004,06
005,06
006,06
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
032,86
033,86
034,86
035,72
036,70
037,70
038,70
039,70
040,08
041,08
042,08
043,08
044,08
045,08
046,08
047,08
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
144,15
145,15
146,15
147,15
148,15
149,15
150,15
151,15
152,15
153,15
154,15
155,15
156,15
157,15
158,15
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
212,73
213,73
214,73
215,73
216,73
217,73
218,73
219,71
220,71
221,02
222,02
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
233,51
234,51
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
268,11
269,11
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
307,29
308,29
309,29
310,29
311,29
312,29
313,29
314,29
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
374,31
375,31
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
391,25
392,25
393,25
394,25
395,25
396,25
397,25
398,25
399,25
400,65
401,65
402,63
403,63
404,63
405,63
406,63
407,63
408,99
409,99
410,99
411,99
412,99
413,99
414,99
415,99
416,59
417,59
418,59
419,59
420,59
421,57
422,57
423,57
424,57
425,97
426,97
427,97
428,97
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
440,21
441,21
442,21
443,21
444,21
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
468,47
469,47
470,47
471,47
472,47
473,47
474,45
475,45
476,45
477,45
478,35
479,35
480,35
481,35
482,35
483,35
484,35
485,33
486,23
487,23
488,23
489,23
490,23
491,23
492,23
493,23
494,21
495,21
496,21
497,21
498,21
499,21
500,21
501,31
502,31
503,37
504,37
505,49
506,49
507,49
508,47
509,25
510,25
511,25
512,25
513,25
514,23
515,23
516,41
517,41
518,73
519,71
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
531,57
532,57
533,57
534,57
535,57
536,57
537,57
538,55
539,55
540,69
541,69
542,69
543,69
544,69
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
574,45
575,99
576,99
577,41
578,39
579,39
580,37
581,99
582,99
583,99
584,99
585,99
586,57
587,97
589,99
590,99
591,99
592,99
593,99
594,99
595,99
596,80
597,78
598,78
599,78
600,99
601,99
602,53
603,53
604,53
605,53
606,53
607,53
608,53
609,53
610,53
611,53
612,53
613,53
614,53
615,53
616,53
617,53
618,53
619,53
620,53
621,53
622,51
623,51
624,51
625,51
626,51
627,98
628,98
629,98
630,98
631,98
632,98
633,98
634,98
635,98
636,98
637,98
638,98
639,98
640,96
641,96
642,96
643,96
644,96
645,96
646,84
647,84
648,38
649,38
650,38
651,36
652,36
653,36
654,22
655,20
656,20
657,20
658,20
659,12
660,10
661,10
662,10
663,10
664,10
665,10
667,28
668,28
669,28
670,26
671,26
672,26
673,26
674,26
675,26
676,10
677,09
678,09
679,09
680,70
681,09
682,09
683,09
684,09
685,07
686,07
687,07
688,07
689,07
690,07
691,03
692,03
693,03
694,01
695,01
696,01
697,01
698,01
699,01
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
729,05
730,05
731,05
732,05
733,05
750,03
751,03
756,01
757,01
758,01
764,58
765,56
766,44
767,44
768,44
769,42
770,42
771,42
772,42
900,70-80 ## Individual Taxpayer Identification Number
900,93-93 ## Adoption Taxpayer Identification Number
