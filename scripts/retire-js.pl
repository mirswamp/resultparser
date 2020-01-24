#!/usr/bin/perl -w

use strict;
use FindBin;
use lib $FindBin::Bin;
use Parser;
use Util;


sub GetOptionalElemText
{
    my ($elem, $child) = @_;

    my $c = $elem->first_child($child);

    if ($c)  {
	return $c->text();
    }  else  {
	return;
    }
}


sub GetValueIfExists
{
    my ($h, $k) = @_;

    return unless exists $h->{$k};

    return $h->{$k};
}


sub DisplayId
{
    my ($prefix, $id, $sep) = @_;

    if (ref $id eq '')  {
	return "$prefix$id";
    }  elsif (ref $id eq 'ARRAY')  {
	return join $sep, map {"$prefix$_"} @$id;
    }  else  {
	die "Bad identifier data, not ARRAY or SCALAR " . (ref $id);
    }
}


sub GetIdData
{
    my ($component, $v) = @_;

    my ($bugCode, $summary, $idText);

    if (exists $v->{identifiers})  {
	my $ids = $v->{identifiers};
	my @nonSummaryTypes = grep {!/summary/} sort keys %$ids;

	# find best matching identifier type for BugCode
	my @types = (qw/CVE issue bug advisory commit release/, @nonSummaryTypes);
	foreach my $type (@types)  {
	    if (exists $ids->{$type})  {
		my $id = $ids->{$type};
		my $prefix = '';
		$prefix = "$component-$type-" unless $type eq 'CVE';
		$bugCode = DisplayId($prefix, $id, ',');
		last;
	    }
	}
	$summary = $ids->{summary} if exists $ids->{summary};
	$idText = join "\n",
		    map {"  - $_:  " . DisplayId('', $ids->{$_}, ', ')}
			@nonSummaryTypes
			    if @nonSummaryTypes;
    }

    $bugCode = "$component-Unknown" unless defined $bugCode;

    return ($bugCode, $summary, $idText);
}


sub GetDependencyText
{
    my ($result) = @_;

    return unless $result->{parent};

    my $s = '';

    while (1)  {
	my $component = $result->{component};
	my $version = $result->{version};
	$s .= sprintf "  %-30s  version %-15s", $component, $version;
	$s .= " required by" if exists $result->{level};
	$s .= "\n";
	last unless exists $result->{parent};
	$result = $result->{parent};
    }

    return $s;
}


sub ProcessKnownWeaknesses
{
    my ($parser, $jsonObject, $jsonPathPrefix) = @_;

    my $num = -1;
    foreach my $group (@$jsonObject)  {
	++$num;
	my $file;
	$file = $group->{file} if exists $group->{file};
	my $groupJsonPath = "$jsonPathPrefix\[$num]";
	if (exists $group->{results})  {
	    my $resultNum = -1;
	    foreach my $r (@{$group->{results}})  {
		++$resultNum;
		my $resultJsonPath = "$groupJsonPath.results[$resultNum]";
		my $component = GetValueIfExists($r, 'component');
		my $version = GetValueIfExists($r, 'version');
		my $detection = GetValueIfExists($r, 'detection');
		my $dependencyText = GetDependencyText($r);
		if (exists $r->{vulnerabilities})  {
		    my $vulnNum = -1;
		    foreach my $v (@{$r->{vulnerabilities}})  {
			++$vulnNum;
			my $vulnJsonPath = "$resultJsonPath.vulnerabilities[$vulnNum]";
			my $severity = GetValueIfExists($v, 'severity');
			my $info = GetValueIfExists($v, 'info');
			$info = [] unless defined $info;
			my ($firstVulnVersion, $firstFixedVersion);
			$firstVulnVersion = $v->{atOrAbove} if exists $v->{atOrAbove};
			$firstFixedVersion = $v->{below} if exists $v->{below};
			my $bugGroup = 'Known-Vuln';
			my ($bugCode, $summary, $idText) = GetIdData($component, $v);

			my $msg = "Known vulnerabilities in component $component version $version:";
			$msg .= "\n\n$summary" if defined $summary;
			$msg .= "\n\nIdentifiers:\n\n$idText" if $idText;
			if (defined $firstVulnVersion || defined $firstFixedVersion)  {
			    $msg .= "\n\nVulnerable Versions:\n\n";
			    $msg .= " beginning with '$firstVulnVersion'" if defined $firstVulnVersion;
			    if (defined $firstFixedVersion)  {
				$msg .= " and" if defined $firstVulnVersion;
				$msg .= " prior to '$firstFixedVersion'";
			    }
			}
			$msg .= "\n\nDependencies:\n\n$dependencyText" if $dependencyText;
			if (exists $v->{info} && @{$v->{info}})  {
			    $msg .= "\n\nMore Information:\n\n";
			    $msg .= join "\n", map {" - $_"} @{$v->{info}};
			}

			$msg .= "\n\ndetected by $detection" if defined $detection;

			my $bug = $parser->NewBugInstance();
			$bug->setBugGroup($bugGroup);
			$bug->setBugCode($bugCode);
			$bug->setBugPath($vulnJsonPath);
			$bug->setBugSeverity($severity) if defined $severity;;
			$bug->setBugMessage($msg);
			$bug->setBugLocation(0, '', $file, undef, undef,
				'0', '0', '', 'true', 'true') if defined $file;
			$parser->WriteBugObject($bug);
			undef $bug;

		    }
		}
	    }
	}  else  {
	    die "Error: Required attribute does not exist at $groupJsonPath.results"
	}
    }
}


sub ParseFile
{
    my ($parser, $fn) = @_;

    my $jsonObject = Util::ReadJsonFile($fn);

    if (ref $jsonObject eq 'ARRAY')  {
	# version 1.x format
	ProcessKnownWeaknesses($parser, $jsonObject, '$');
    }  else  {
	# version 2.x format
	ProcessKnownWeaknesses($parser, $jsonObject->{data}, '$.data');

	my $errorNum = -1;
	if (exists $jsonObject->{errors})  {
	    for my $errMsg (@{$jsonObject->{errors}})  {
		++$errorNum;
		my $jsonPath = "\$.errors[$errorNum]";

		my ($file, $bugCode);
		if ($errMsg =~ /^Could not parse file:\s+(.*)$/)  {
		    $bugCode = 'parse error';
		    $file = $1;
		}  elsif ($errMsg =~ /^Missing version for /)  {
		    $bugCode = 'missing version';
		}  else  {
		    $bugCode = 'unknown';
		}

		my $bug = $parser->NewBugInstance();
		$bug->setBugGroup('error');
		$bug->setBugCode($bugCode);
		$bug->setBugPath($jsonPath);
		$bug->setBugMessage($errMsg);
		$bug->setBugLocation(0, '', $file, undef, undef,
			'0', '0', '', 'true', 'true') if defined $file;
		$parser->WriteBugObject($bug);
		undef $bug;
	    }
	}

	my $msgNum = -1;
	if (exists $jsonObject->{messages})  {
	    for my $msg (@{$jsonObject->{messages}})  {
		++$msgNum;
		my $jsonPath = "\$.messages[$msgNum]";

		my $msg;
		if (ref $msg eq '')  {
		    $msg = $msg;
		}  else  {
		    $msg = to_json($msg, {pretty => 1});
		    print STDERR "WARNING: Expected a string at $jsonPath, but found:\n$msg\n";
		}

		my $bug = $parser->NewBugInstance();
		$bug->setBugGroup('info');
		$bug->setBugCode('message');
		$bug->setBugPath($jsonPath);
		$bug->setBugMessage($msg);
		$parser->WriteBugObject($bug);
		undef $bug;
	    }
	}
    }
}


my $parser = Parser->new(ParseFileProc => \&ParseFile);
