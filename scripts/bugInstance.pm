#!/usr/bin/perl -w
package bugInstance;

use strict;

use bugLocation;
use bugMethod;


sub new
{
    my $class = shift;
    my $self= {
	_bugId => shift
    };
    bless $self, $class;
    return $self;
}


sub setBugMessage
{
    my ($self, $bugMessage) = @_;
    $self->{_bugMessage} = $bugMessage if defined $bugMessage;
    return $self->{_bugMessage};
}


sub AppendBugFlowToBugMsg
{
    my ($self) = @_;

    my $m = '';
    my $locCount = 0;
    my $firstLoc;

    foreach my $loc (@{$self->{_bugLocations}})  {
	next unless defined $loc;

	++$locCount;
	$firstLoc = $loc if $locCount == 1;

	my ($file, $line, $msg, $primary)
		= @$loc{qw/_sourceFile _startLine _bugMessage _primary/};

	$m .= "*** $file";
	$m .= ":$line" if defined $line;
	$m .= " ***";
	$m .= "*** Primary Bug Location" if $primary eq 'true';
	if (defined $msg)  {
	    $msg =~ s/^/  /mg;
	    $m .= "\n$msg\n";
	}
    }

    return if $locCount == 0;
    my $firstLocMsg = $firstLoc->{_bugMessage};
    $firstLocMsg = '' unless defined $firstLocMsg;
    $self->{_bugMessage} = '' unless defined $self->{_bugMessage};
    return if $locCount == 1
	    && ($firstLocMsg eq $self->{_bugMessage} || $firstLocMsg eq '');

    $self->{_bugMessage} .= "\n\n" if $self->{_bugMessage} ne '';
    $self->{_bugMessage} .= "Bug Path:\n\n$m";
    $self->{_bugMessage} .= "\n" unless $m =~ /\n$/;
}


sub setBugLocation
{
    my ($self, $bugLocationId, $bugClassname, $SourceFile, $startLine,
	    $endLine, $beginColumn, $endColumn, $bugMessage, $primary, $resolvedFlag) = @_;
    my $locationObject;
    if ($resolvedFlag eq 'true' or (defined $startLine && $startLine ne ""))  {
	$locationObject = new bugLocation($bugLocationId, $bugClassname, $SourceFile, $startLine,
		$endLine, $beginColumn, $endColumn, $bugMessage, $primary);
    }  else  {
	$locationObject = new bugLocation($bugLocationId, $bugClassname, $self->{_classSourceFile},
		$self->{_classStartLine}, $self->{_classEndLine}, $beginColumn, $endColumn,
		$self->{_classMessage}, $primary);
    }	
    $self->{_bugLocations}[$bugLocationId] = $locationObject;
}


sub setBugColumn
{
    my ($self, $start_column, $end_column, $bugLocationId) = @_;
    #FIXME: why $locationObject
    my $locationObject = $self->{_bugLocations}[$bugLocationId]->setBugColumn($start_column, $end_column);
}


sub setBugMethod
{
    my ($self, $methodId, $className, $methodName, $primary) = @_;
    my $methodObject = new bugMethod($methodId, $methodName, $className, $primary);
    $self->{_bugMethodHash}{$methodId} = $methodObject;
    #print $self->{_bugMethodHash}{$methodId}, "\n";
}


sub setSourceFile
{
    my ($self, $sourceFile) = @_;
    $self->{_sourceFile} = $sourceFile if defined $sourceFile;
    return $self->{_sourceFile};
}


sub setClassName
{
    my ($self, $className) = @_;
    $self->{_className} = $className if defined $className;
    return $self->{_className};
}


sub setClassAttribs
{
    my ($self, $classname, $sourcefile, $start, $end, $classMessage) = @_;
    #print $sourcefile, "\n";
    $self->{_classSourceFile} = $sourcefile if defined $sourcefile;
    $self->{_className} = $classname if defined $classname;
    $self->{_classStartLine} = $start if defined $start;
    $self->{_classEndLine} = $end if defined $end;
    $self->{_classMessage} = $classMessage if defined $classMessage;
}


sub setBugSeverity
{
    my ($self, $bugSeverity) = @_;
    $self->{_bugSeverity} = $bugSeverity if defined $bugSeverity;
    return $self->{_bugSeverity};
}


sub setBugRank
{
    my ($self, $bugRank) = @_;
    $self->{_bugRank} = $bugRank if defined $bugRank;
    return $self->{_bugRank};
}


sub setCweId
{
    my ($self, $cweId) = @_;
    push(@{$self->{_cweId}}, $cweId) if defined $cweId;
    return $self->{_cweId};
}


sub setBugGroup
{
   my ($self, $group) = @_;
   $self->{_bugGroup} = $group if defined $group;
   return $self->{_bugGroup};
}


sub getBugGroup
{
    my ($self) = @_;
    return $self->{_bugGroup} if exists $self->{_bugGroup};
    return;
}


sub setBugCode
{
    my ($self, $code) = @_;
    $self->{_bugCode} = $code if defined $code;
    return $self->{_bugCode};
}


sub getBugCode
{
    my ($self) = @_;
    return $self->{_bugCode} if exists $self->{_bugCode};
    return;
}


sub setBugSuggestion
{
    my ($self, $suggestion) = @_;
    $self->{_bugSuggestion} = $suggestion if defined $suggestion;
    return $self->{_bugSuggestion};
}


sub setBugPath
{
    my ($self, $bugPath) = @_;
    $self->{_bugPath} = $bugPath if defined $bugPath;
    return $self->{_bugPath};
}


sub setBugLine
{
    my ($self, $bugLineStart, $bugLineEnd) = @_;
    $self->{_bugLineStart} = $bugLineStart if defined $bugLineStart;
    $self->{_bugLineEnd} = $bugLineEnd if defined $bugLineEnd;
}


sub setBugReportPath
{
    my ($self, $reportPath) = @_;
    $self->{_reportPath} = $reportPath if defined $reportPath;
    return $self->{_reportPath};
}


sub getBugReportPath
{
    my ($self) = @_;
    return $self->{_reportPath} if exists $self->{_reportPath};
    return;
}


sub setBugBuildId
{
    my ($self, $buildId) = @_;
    $self->{_buildId} = $buildId if defined $buildId;
    return $self->{_buildId};
}


sub getBugBuildId
{
    my ($self) = @_;
    return $self->{_buildId} if exists $self->{_buildId};
    return;
}


sub setURLText
{
    my ($self, $url_txt) = @_;
    $self->{_url} = $url_txt if defined $url_txt;
}


sub getURLText
{
    my ($self) = @_;
    return $self->{_url} if exists $self->{_url};
    return;
}


sub setBugPackage
{
    my ($self, $bugPackage) = @_;
    $self->{_package} = $bugPackage if defined $bugPackage;
    return $self->{_package};
}


sub getBugPackage
{
    my ($self) = @_;
    return $self->{_package} if exists $self->{_package};
    return;
}


sub setBugPathLength
{
    my ($self, $bugPathLength) = @_;
    $self->{_bugPathLength} = $bugPathLength if defined $bugPathLength;
    return $self->{_bugPathLength};
}


sub getBugPathLength
{
    my ($self) = @_;
    return $self->{_bugPathLength} if exists $self->{_bugPathLength};
    return;
}


sub setCWEInfo
{
    my ($self, $info) = @_;
    $self->{_cwe} = $info if defined $info;
    return $self->{_cwe};
}


sub getCWEInfo
{
    my ($self) = @_;
    return $self->{_cwe} if exists $self->{_cwe};
    return;
}


sub setCWEArray
{
    my $self = shift;
    if (@_ != 0)  {
	$self->{_cwe_array} = [];
	@{$self->{_cwe_array}} = @_;
    }
    return @{$self->{_cwe_array}};
}


sub getCWEArray
{
    my ($self) = @_;
    return @{$self->{_cwe_array}} if exists $self->{_cwe_array};
    return;
}


sub setBugPosition
{
    my ($self, $info) = @_;
    $self->{_position} = $info if defined $info;
    return $self->{_position};
}


sub getBugPosition
{
    my ($self) = @_;
    return $self->{_position} if exists $self->{_position};
    return;
}


sub setBugWarningCode
{
    my ($self, $info) = @_;
    $self->{_warningCode} = $info if defined $info;
    return $self->{_warningCode};
}


sub getBugWarningCode
{
    my ($self) = @_;
    return $self->{_warningCode} if exists $self->{_warningCode};
    return;
}


sub setBugToolSpecificCode
{
    my ($self, $info) = @_;
    $self->{_toolSpecificCode} = $info if defined $info;
    return $self->{_toolSpecificCode};
}


sub getBugToolSpecificCode
{
    my ($self) = @_;
    return $self->{_toolSpecificCode} if exists $self->{_toolSpecificCode};
    return;
}


sub setBugLongMessage
{
    my ($self, $info) = @_;
    $self->{_long_message} = $info if defined $info;
}


sub getBugLongMessage
{
    my ($self) = @_;
    return $self->{_long_message} if exists $self->{_long_message};
    return;
}


sub setBugShortMessage
{
    my ($self, $info) = @_;
    $self->{_short_message} = $info if defined $info;
}


sub getBugShortMessage
{
    my ($self) = @_;
    return $self->{_short_message} if exists $self->{_short_message};
    return;
}


sub setBugInconclusive
{
    my ($self, $info) = @_;
    $self->{_inconclusive} = $info if defined $info;
    return $self->{_inconclusive};
}


sub getBugInconclusive
{
    my ($self) = @_;
    return $self->{_inconclusive} if exists $self->{_inconclusive};
    return;
}


sub printXML
{
    my ($self, $writer) = @_;
    $writer->startTag('BugInstance', 'id' => $self->{_bugId});

    if (defined $self->{_className})
    {
	$writer->startTag('ClassName');
	$writer->characters($self->{_className});
	$writer->endTag();
    }

    $writer->startTag('Methods');
    my $method;
    foreach $method (sort{$a <=> $b} keys %{$self->{_bugMethodHash}})
    {
	$self->{_bugMethodHash}{$method}->printXML($writer);
    }
    $writer->endTag();

    $writer->startTag('BugLocations');
    my $foundPrimary = 0;
    my $elementsRemaining = @{$self->{_bugLocations}};
    foreach my $loc (@{$self->{_bugLocations}})
    {
	next unless defined $loc;
	$foundPrimary = 1 if $loc->{_primary} eq 'true';
	--$elementsRemaining;
	my $forcePrimary = !($elementsRemaining || $foundPrimary);
	$loc->printXML($writer, $self->{_classStartLine}, $self->{_classEndLine}, $forcePrimary);
    }
    $writer->endTag();
    if (defined $self->{_cweId})
    {
	foreach my $cwe (@{$self->{_cweId}})
	{
	    $writer->startTag('CweId');
	    $writer->characters($cwe);
	    $writer->endTag();
	}
    }

    if (defined $self->{_bugGroup})
    {
	$writer->startTag('BugGroup');
	$writer->characters($self->{_bugGroup});
	$writer->endTag();
    }

    if (defined $self->{_bugCode})
    {
	$writer->startTag('BugCode');
	$writer->characters($self->{_bugCode});
	$writer->endTag();
    }

    if (defined $self->{_bugRank})
    {
	$writer->startTag('BugRank');
	$writer->characters($self->{_bugRank});
	$writer->endTag();
    }

    if (defined $self->{_bugSeverity})
    {
	$writer->startTag('BugSeverity');
	$writer->characters($self->{_bugSeverity});
	$writer->endTag();
    }


    if (defined $self->{_bugMessage})
    {
	$writer->startTag('BugMessage');
	$writer->characters($self->{_bugMessage});
	$writer->endTag();
    }

    if (defined $self->{_bugSuggestion})
    {
	$writer->startTag('ResolutionSuggestion');
	$writer->characters($self->{_bugSuggestion});
	$writer->endTag();
    }

    $writer->startTag('BugTrace');
    if (defined $self->{_buildId})
    {
	$writer->startTag('BuildId');
	$writer->characters($self->{_buildId});
	$writer->endTag();
    }

    if (defined $self->{_reportPath})
    {
	$writer->startTag('AssessmentReportFile');
	$writer->characters($self->{_reportPath});
	$writer->endTag();
    }

    if (defined $self->{_bugPath})
    {
	$writer->startTag('InstanceLocation');
	$writer->startTag('Xpath');
	$writer->characters($self->{_bugPath});
	$writer->endTag();
	$writer->endTag();
    }
    if (defined $self->{_bugLineStart} and defined $self->{_bugLineEnd})
    {
	$writer->startTag('InstanceLocation');
	$writer->startTag('LineNum');
	$writer->startTag('Start');
	$writer->characters($self->{_bugLineStart});
	$writer->endTag();
	$writer->startTag('End');
	$writer->characters($self->{_bugLineEnd});
	$writer->endTag();
	$writer->endTag();
	$writer->endTag();
    }
    $writer->endTag();


    $writer->endTag();
}

1;
