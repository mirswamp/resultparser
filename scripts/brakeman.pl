#!/usr/bin/perl -w

use strict;
use FindBin;
use lib $FindBin::Bin;
use Parser;
use bugInstance;
use Util;
use JSON;


sub ParseFile
{
    my ($parser, $fn) = @_;

    my $jsonData = Util::ReadFile($fn);

    my $jsonObject = JSON->new->utf8->decode($jsonData);
    my $appPath = $jsonObject->{scan_info}{app_path};

    foreach my $warning (@{$jsonObject->{warnings}})  {
	my $file = $appPath . "/" . $warning->{file};

	my $bug = $parser->NewBugInstance();

	if (defined $warning->{line})  {
	    my $line = $warning->{line};
	    $bug->setBugLocation(1, "", $file, $line, $line, 0, 0, "", "true", "true");
	} else {
	    $bug->setBugLocation(1, "", $file, 0, 0, 0, 0, "", "true", "true");
	}

	if (defined $warning->{location})  {
	    if ($warning->{location}{type} eq "method")  {
		my $class  = $warning->{location}{class};
		my $method = $warning->{location}{method};
		$method =~ s/\Q$class.\E//;
		$bug->setBugMethod(1, $class, $method, "true");
		$bug->setClassName($warning->{location}{class});
	    }
	}

	$bug->setBugMessage(sprintf("%s (%s)", $warning->{message}, $warning->{link}));
	$bug->setBugCode($warning->{warning_type});
	$bug->setBugSeverity($warning->{confidence});
	$bug->setBugWarningCode($warning->{warning_code});
	$bug->setBugToolSpecificCode($warning->{code});
	$parser->WriteBugObject($bug);
    }
}

my $parser = Parser->new(ParseFileProc => \&ParseFile);
