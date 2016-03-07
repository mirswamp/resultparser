#!/usr/bin/perl
package util;

# NormalizePath - take a path and remove empty and '.' directory components
#                 empty directories become '.'
#
sub NormalizePath {
	my $p = shift;

	$p =~ s/\/\/+/\//g;        # collapse consecutive /'s to one /
	$p =~ s/\/(\.\/)+/\//g;    # change /./'s to one /
	$p =~ s/^\.\///;           # remove initial ./
	$p = '.' if $p eq '';      # change empty dirs to .
	$p =~ s/\/\.$/\//;                 # remove trailing . directory names
	$p =~ s/\/$// unless $p eq '/';    # remove trailing /

	return $p;
}

# AdjustPath - take a path that is relative to curDir and make it relative
#              to baseDir.  If the path is not in baseDir, do not modify.
#
#       baseDir    - the directory to make paths relative to
#       curDir     - the directory paths are currently relative to
#       path       - the path to change
#
sub AdjustPath {
	my ( $baseDir, $curDir, $path ) = @_;

	$baseDir = NormalizePath($baseDir);
	$curDir  = NormalizePath($curDir);
	$path    = NormalizePath($path);
    
	# if path is relative, prefix with current dir
	if ( $path eq '.' ) {
		$path = $curDir;
	}
	elsif ( $curDir ne '.' && $path !~ /^\// ) {
		$path = "$curDir/$path";
	}

	# remove initial baseDir from path if baseDir is not empty
	$path =~ s/^\Q$baseDir\E\///;

	return $path;
}


sub SplitString {
    my ($str) = @_;
    $str =~ s/::+/~#~/g;
        $str  =~ /(‘[^:]+:+[^:]+’)/;
        my $temp = $1;
        $str =~ s/‘[^:]+:+[^:]+’/~~&&~~/;
        if (defined ($temp))
        {
            $temp =~ s/:/~%%~/;
        }
        $str =~ s/~~&&~~/$temp/;
    my @tokens = split(':',$str);
    my @ret;
    foreach $a (@tokens)
    {
       $a =~ s/~#~/::/g;
           $a =~ s/~%%~/:/g;
       push(@ret,$a);
    }
    return(@ret);
}


sub trim
{
        my ($string) = @_;
        $string =~ s/^ *//;
        $string =~ s/ *$//;
        return "$string";
}

1;
