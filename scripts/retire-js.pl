#!/usr/bin/perl -w

use strict;
use FindBin;
use lib $FindBin::Bin;
use Parser;
use JSON;
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


sub ParseFile
{
    my ($parser, $jsonFn) = @_;

    my $data = Util::ReadFile($jsonFn);
    my $json = JSON->new->utf8->decode($data);

    my $num = -1;
    foreach my $group (@$json)  {
	++$num;
	my $file;
	$file = $group->{file} if exists $group->{file};
	if (exists $group->{results})  {
	    my $resultNum = -1;
	    foreach my $r (@{$group->{results}})  {
		++$resultNum;
		my $resultJsonPath = "\$[$num].results[$resultNum]";
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
			my $bugGroup = 'Known-Vuln';
			my ($bugCode, $summary, $idText) = GetIdData($component, $v);
			my $msg = "Known vulnerabilities in component $component version $version";
			$msg .= "\n(detected by $detection)" if defined $detection;
			$msg .= ":";
			$msg .= "\n\n$summary" if defined $summary;
			$msg .= "\n\nIdentifiers:\n\n$idText" if $idText;
			$msg .= "\n\nDependencies:\n\n$dependencyText" if $dependencyText;
			if (exists $v->{info} && @{$v->{info}})  {
			    $msg .= "\n\nMore Inforation:\n\n";
			    $msg .= join "\n", map {" - $_"} @{$v->{info}};
			}

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
	    die "Error: no results in $jsonFn \$[$num]"
	}
    }
}


my $parser = Parser->new(ParseFileProc => \&ParseFile);
