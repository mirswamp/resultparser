#!/usr/bin/perl -w

#  ConfUtils.pm   http://www.cs.wisc.edu/~kupsch
# 
#  Copyright 2013-2019 James A. Kupsch
# 
#  Licensed under the Apache License, Version 2.0 (the "License");
#  you may not use this file except in compliance with the License.
#  You may obtain a copy of the License at
# 
#      http://www.apache.org/licenses/LICENSE-2.0
# 
#  Unless required by applicable law or agreed to in writing, software
#  distributed under the License is distributed on an "AS IS" BASIS,
#  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
#  See the License for the specific language governing permissions and
#  limitations under the License.

package SwampUtils;

use strict;
use Getopt::Long;



# ProcessOptions - Process the options and handle help and version
#
# exits with 0 status if --help or --version is supplied
#       with 1 status if an invalid options is supplied
#
# returns a reference to a hash containing the option
#
sub ProcessOptions
{
    my %optionDefaults = (
		help		=> 0,
		version		=> 0,
		conf_file	=> 'sample1.conf',
		conf_file2	=> 'sample2.conf',
		);

    # for options that contain a '-', make the first value be the
    # same string with '-' changed to '_', so quoting is not required
    # to access the key in the hash $option{input_file} instead of
    # $option{'input-file'}
    my @options = (
		"help|h!",
		"version|v!",
		"conf_file|conf-file|c1|c=s",
		"conf_file2|conf-file2|c2=s",
		"num1|n1|n=s",
		"num2|n2|m=s",
		"op|o=s",
		);

    # Configure file options, will be read in this order
    my @confFileOptions = qw/ conf_file conf_file2 /;

    Getopt::Long::Configure(qw/require_order no_ignore_case no_auto_abbrev/);
    my %getoptOptions;
    my $ok = GetOptions(\%getoptOptions, @options);

    my %options = %optionDefaults;
    my %optSet;
    while (my ($k, $v) = each %getoptOptions)  {
	$options{$k} = $v;
	$optSet{$k} = 1;
    }

    my @errs;

    if ($ok)  {
	foreach my $opt (@confFileOptions)  {
	    if (exists $options{$opt})  {
		my $fn = $options{$opt};
		if ($optSet{$opt} || -e $fn)  {
		    if (-f $fn)  {
			my $h = ReadConfFile($fn, undef, \@options);

			while (my ($k, $v) = each %$h)  {
			    next if $k =~ /^#/;
			    $options{$k} = $v;
			    $optSet{$k} = 1;
			}
		    }  else  {
			push @errs, "option file '$fn' not found (specified by option '$opt')";
		    }
		}
	    }
	}
	while (my ($k, $v) = each %getoptOptions)  {
	    $options{$k} = $v;
	    $optSet{$k} = 1;
	}
    }

    if (!$ok || $options{help})  {
	PrintUsage(\%optionDefaults);
	exit !$ok;
    }

    if ($ok && $options{version})  {
	PrintVersion();
	exit 0;
    }

    # Error checking of options goes here
    push @errs, "num1 not set" unless exists $options{num1};
    push @errs, "num2 not set" unless exists $options{num2};
    if (exists $options{op})  {
	push @errs, "op '$options{op}' is invalid" unless $options{op} =~ /^[-+*\/]$/;
    }  else  {
	push @errs, "op not set";
    }
    if (@errs)  {
	print STDERR "$0: options Errors:\n    ", join ("\n    ", @errs), "\n";
	exit 1;
    }

    return \%options
}


#
#
# statusOutObj = ReadStatusOut(filename)
#
# ReadStatusOut returns a hash containing the parsed status.out file.
#
# A status.out file consists of task lines in the following format with the
# names of these elements labeled
#
#     PASS: the-task-name (the-short-message)           40.186911s
#
#     |     |              |                            |        |
#     |     task           shortMsg                     dur      |
#     status                                               durUnit
#
# Each task may also optional have a multi-line message (the msg element).
# The number of spaces before the divider are removed from each line and the
# line-feed is removed from the last line of the message
#
#     PASS: the-task-name (the-short-message)           40.186911s
#       ----------
#       line 1
#       line 2
#       ----------
#
# The returned hash contains a hash for each task.  The key is the name of the
# task.  If there are duplicate task names, duplicate keys are named using the
# scheme <task-name>#<unique-number>.
#
# The hash for each task contains the following keys
#
#   status    - one of PASS, FAIL, SKIP, or NOTE
#   task      - name of the task
#   shortMsg  - shortMsg or undef if not present
#   msg       - msg or undef if not present
#   dur       - duration is durUnits or undef if not present
#   durUnit   - durUnits: 's' is for seconds
#   linenum   - line number where task started in file
#   name      - key used in hash (usually the same as task)
#   text      - unparsed text
#
# Besided a hash for each task, the hash function returned from ReadStatusOut
# also contains the following additional hash elements:
#
#   #order     - reference to an array containing references to the task hashes
#                in the order they appeared in the status.out file
#   #errors    - reference to an array of errors in the status.out file
#   #warnings  - reference to an array of warnings in the status.out file
#   #filename  - filename read
#
# If there are no errors or warnings (the arrays are 0 length), then exists can
# be used to check for the existence of a task.  The following would correctly
# check if that run succeeded:
#
# my $s = ReadStatusOut($filename)
# if (!@{$s->{'#errors'}} && !@{$s->{'#warnings'}})  {
#     if (exists $s->{all} && $s->{all}{status} eq 'PASS')  {
#         print "success\n";
#     }  else  {
#         print "no success\n";
#     }
# }  else  {
#     print "bad status.out file\n";
# }
#
#


my $stdDivPrefix = ' ' x 2;
my $stdDivChars = '-' x 10;
my $stdDiv = "$stdDivPrefix$stdDivChars";

sub ReadStatusOut
{
    my ($statusFile) = @_;

    my %status = (
		    '#order'	=> [],
		    '#errors'	=> [],
		    '#warnings'	=> [],
		    '#filename'	=> $statusFile
		);

    my $lineNum = 0;
    if (!open STATUSFILE, "<", $statusFile)  {
	$status{'#fileopenerror'} = $!;
	push @{$status{'#errors'}}, "open $statusFile failed: $!";
	return \%status;
    }
    my ($lookingFor, $name, $prefix, $divider) = ('task', '');
    while (<STATUSFILE>)  {
	++$lineNum;
	my $line = $_;
	chomp;
	if ($lookingFor eq 'task')  {
	    if (/^( \s*)(-+)$/)  {
		($prefix, $divider) = ($1, $2);
		$lookingFor = 'endMsg';
		if ($name eq '')  {
		    push @{$status{'#errors'}}, "Message divider before any task at line $lineNum";
		    $status{$name}{linenum} = $lineNum;
		}
		if (defined($status{$name}{text}) && ($status{$name}{text} =~ tr/\n//) > 1)  {
		    push @{$status{'#errors'}}, "Message found after another message at line $lineNum";
		    $status{$name}{msg} .= "\n";
		}
		if ($_ ne $stdDiv)  {
		    push @{$status{'#errors'}}, "Non-standard message divider '$_' at line $lineNum";
		}
		$status{$name}{text} .= $line;
		$status{$name}{msg} .= '';
	    }  else  {
		s/\s*$//;
		if (/^\s*$/)  {
		    push @{$status{'#warnings'}}, "Blank line at line $lineNum";
		    next;
		}
		if (/^(\s*)([a-zA-Z0-9_.-]+):\s+([a-zA-Z0-9_.-]+)\s*(.*)$/)  {
		    my ($pre, $status, $task, $remain) = ($1, $2, $3, $4);
		    $name = $task;
		    if (exists $status{$name})  {
			push @{$status{"#warnings"}}, "Duplicate task name found at lines $status{$name}{linenum} and $lineNum";
			my $i = 0;
			do {
			    ++$i;
			    $name = "$task#$i";
			}  until (!exists $status{$name});
			
		    }
		    my ($shortMsg, $dur, $durUnit);

		    if ($remain =~ /^\((.*?)\)\s*(.*)/)  {
			($shortMsg, $remain) = ($1, $2);
		    }
		    if ($remain =~ /^([\d\.]+)([a-zA-Z]*)\s*(.*)$/)  {
			($dur, $durUnit, $remain) = ($1, $2, $3);
		    }

		    if ($pre ne '')  {
			push @{$status{'#warnings'}}, "White space before status at line $lineNum";
		    }
		    if ($remain ne '')  {
			push @{$status{'#errors'}}, "Extra data '$remain' after duration at line: $lineNum";
		    }
		    if (defined $dur)  {
			my ($wholeDur, $fracDur, $extra)
				= ($dur =~ /^(\d*)(?:\.(\d*)(.*))?$/);
			if ($wholeDur eq '')  {
			    push @{$status{'#warnings'}}, "Missing leading '0' in duration at line $lineNum";
			}
			if (length $fracDur != 6)  {
			    push @{$status{'#warnings'}}, "Fractional duration digits not 6 at line $lineNum";
			}
			if ($extra ne '')  {
			    push @{$status{'#errors'}}, "Two '.' characters in duration at line $lineNum";
			}
			if ($durUnit eq '')  {
			    push @{$status{'#errors'}}, "Missing duration unit at line $lineNum";
			}  elsif ($durUnit ne 's')  {
			    push @{$status{'#errors'}}, "Duration unit not 's' at line $lineNum";
			}
		    }
		    if (defined $shortMsg)  {
			if ($shortMsg =~ /\(/)  {
			    push @{$status{'#warnings'}}, "Short message contains '(' at line $lineNum";
			}
		    }

		    if ($status !~ /^(NOTE|SKIP|PASS|FAIL)$/i)  {
			push @{$status{'#errors'}}, "Unknown status '$status' at line $lineNum";
		    } elsif ($status !~ /^(NOTE|SKIP|PASS|FAIL)$/)  {
			push @{$status{'#warnings'}}, "Status '$status' should be uppercase at line $lineNum";
		    }

		    $status{$name} = {
					status	  => $status,
					task	  => $task,
					shortMsg  => $shortMsg,
					msg	  => undef,
					dur	  => $dur,
					durUnit	  => $durUnit,
					linenum	  => $lineNum,
					name	  => $name,
					text	  => $line
				    };
		    push @{$status{'#order'}}, $status{$name};
		}
	    }
	}  elsif ($lookingFor eq 'endMsg')  {
	    $status{$name}{text} .= $line;
	    if (/^$prefix$divider$/)  {
		$lookingFor = 'task';
		chomp $status{$name}{msg};
	    }  else  {
		$line =~ s/^$prefix//;
		$status{$name}{msg} .= $line;
	    }
	}  else  {
	    die "Unknown lookingFor value = $lookingFor";
	}
    }
    if (!close STATUSFILE)  {
	push @{$status{'#errors'}}, "close $statusFile failed: $!";
    }

    if ($lookingFor eq 'endMsg')  {
	my $ln = $status{$name}{linenum};
	push @{$status{'#errors'}}, "Message divider '$prefix$divider' not seen before end of file at line $ln";
	if (defined $status{$name}{msg})  {
	    chomp $status{$name}{msg};
	}
    }

    return \%status;
}


# HasValue - return true if string is defined and non-empty
#
sub HasValue
{
    my ($s) = @_;

    return defined $s && $s ne '';
}


# Read a configuration file containing keys and values, returning a reference to
# a hash containing the keys mapped to values.  The key and value are separated
# by the '=' and more generally ':<MODIFIER_CHARS>='.  The MODIFIER_CHARS allow
# the value to contain arbitrary whitespace and new-line characters.  The
# MODIFIER_CHARS are case insensitive.
#
# The key is the characters from the current place in the file to the first '='
# or last ':' before the first '='.  Leading and trailing whitespace surrounding
# the key are removed (all other characters are preserved).  Duplicate keys
# replace prior values.
#
# Configuration file lines are of the following form:
#
# - blank or all whitespace lines are skipped
# - comment lines (first non-whitespace is a '#') are skipped
# - k = v		adds k => v to hash, leading and trailing whitespace is
# 			removed
# - k :<COUNT>L=v	add k => VALUE to hash, where VALUE is the next <COUNT>
# 			lines with whitespace and new lines preserved, except
# 			the final new line.  If the file does not contain
# 			<COUNT> additional lines it is an error.
# - k :=v		same at 'k :1L=v'
# - k :<COUNT>C=v	add k => Value to hash, where VALUE is the next <COUNT>
# 			characters after the '=' with whitespace and new lines
# 			preserved,  If the file does not contain <COUNT>
# 			additonal characters it is an error.  Processing of the
# 			next key begins at the next character even if it is on
# 			the same line as part of the value.
# - other lines such as those lacking a '=', or an empty key after whitespace
#   removal are errors
#
# To aid human readability of configuration files, creators of configuration
# files are encouraged to use 'k = v' where the value does not contain a leading
# or trailing whitespace and there are no new line characters in v, 'k :=v'
# where v does not contain a new-line character, and one of the other forms only
# when v contains a new-line character.  Comments and blank lines can be used to
# increase readability.  If the 'k :<COUNT>C=v' form is used a new-line is
# encouraged after the value so each key starts on its own line.
#
#
sub ReadConfFile
{
    my ($filename, $required, $mapping) = @_;

    my $lineNum = 0;
    my $colNum = 0;
    my $linesToRead = 0;
    my $charsToRead = 0;
    my %h;
    $h{'#filenameofconffile'} = $filename;

    my %mapping;
    if (defined $mapping)  {
	if (ref($mapping) eq 'HASH')  {
	    %mapping = %$mapping;
	}  elsif (ref($mapping) eq 'ARRAY')  {
	    foreach my $a (@$mapping)  {
		$a =~ s/[:=!].*$//;
		my @names = split /\|/, $a;
		my $toName = shift @names;
		foreach my $name (@names)  {
		    $mapping{$name} = $toName;
		}
	    }
	}  else  {
	    die "ReadConfFile: ERROR mapping has unknown ref type: " . ref($mapping);
	}
    }

    open my $confFile, "<$filename" or die "Open configuration file '$filename' failed: $!";
    my ($line, $k, $origK, $kLine, $err);
    while (1)  {
	if (!defined $line)  {
	    $line = <$confFile>;
	    last unless defined $line;
	    ++$lineNum;
	    $colNum = 1;
	}

	if ($linesToRead > 0)  {
	    --$linesToRead;
	    chomp $line if $linesToRead == 0;
	    $h{$k} .= $line;
	}  elsif ($charsToRead > 0)  {
	    my $v = substr($line, 0, $charsToRead, '');
	    $colNum = length $v;
	    $charsToRead -= $colNum;
	    $h{$k} .= $v;
	    redo if length $line > 0;
	}  elsif ($line !~ /^\s*(#|$)/)  {
	    # line is not blank or a comment (first non-whitespace is a '#')
	    if ($line =~ /^\s*(.*?)\s*(?::([^:]*?))?=(\s*(.*?)\s*)$/)  {
		my ($u, $wholeV, $v) = ($2, $3, $4);
		$origK = $1;
		$k = (exists $mapping{$origK}) ? $mapping{$origK} : $origK;
		$kLine = $lineNum;
		if ($k eq '')  {
		    chomp $line;
		    $err = "missing key, line is '$line'";
		    last;
		}
		if (!defined $u)  {
		    # normal 'k = v' line
		    $h{$k} = $v;
		}  else  {
		    # 'k :<COUNT><UNIT>= v' line
		    $u = '1L' if $u eq '';
		    if ($u =~ /^(\d+)L$/i)  {
			$linesToRead = $1;
		    }  elsif ($u =~ /^(\d+)C$/i)  {
			$charsToRead = $1;
			$colNum = length($line) - length($wholeV);
		    }  else  {
			$err = "unknown units ':$u='";
			last;
		    }
		    $h{$k} = '';
		    $line = $wholeV;
		    redo;
		}
	    }  else  {
		chomp $line;
		$err = "bad line (no '='), line is '$line'";
		last;
	    }
	}
	undef $line;
    }
    close $confFile or defined $err or die "Close configuration file '$filename' failed: $!";

    if (defined $err)  {
	my $loc = "line $lineNum";
	$loc .= " column $colNum" unless $colNum == 1;
	die "Configuration file '$filename' $loc $err";
    }

    if ($linesToRead > 0)  {
	die "Configuration file '$filename' missing $linesToRead lines for key '$k' at line $kLine";
    }

    if ($charsToRead > 0)  {
	die "Configuration file '$filename' missing $charsToRead characters for key '$k' at line $kLine";
    }

    if (defined $required)  {
	my @missing = grep { !HasValue $h{$_}; } @$required;
	if (@missing)  {
	    die "Configuration file '$filename' missing required keys: " . join(", ", @missing);
	}
    }

    return \%h;
}


sub WriteConfFile
{
    my ($filename, $confKeys) = @_;

    open CONFFILE, ">", $filename or die "open > $filename: $!";
    foreach my $k (sort keys %$confKeys)  {
        my $v = $confKeys->{$k};
        die "leading whitespace in key: filename='$filename' k='$k' v='$v'" if $k =~ /^\s/;
        die "trailing whitespace in key: filename='$filename' k='$k' v='$v'" if $k =~ /\s$/;
        die "'=' in key: filename='$filename' k='$k' v='$v'" if $k =~ /=/;

        my $numLines = ($v =~ tr/\n//) + 1;
        my $sep;

        if ($numLines != 1)  {
            $sep = ":${numLines}L=";
        }  elsif ($v =~ /^\s+|\s+$/)  {
            $sep = ":=";
        }  else  {
            $sep = "= ";
        }

        print CONFFILE "$k $sep$v\n";
    }
    close CONFFILE or die "close $filename";
}


1;
