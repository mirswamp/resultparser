#!/usr/bin/perl -w

package BugInstance;
use strict;
use Data::Dumper;

sub new {
    my ($class) = @_;

    my $self = {};
    
    bless $self, $class;
    return $self;
}


sub setBugMessage {
    my ($self, $bugMessage) = @_;
    $self->{BugMessage} = $bugMessage if defined $bugMessage;
}

sub AppendBugFlowToBugMsg
{
    my ($self) = @_;

    my $m = '';
    my $locCount = 0;
    my $firstLoc;

    foreach my $loc (@{$self->{BugLocations}})  {
	next unless defined $loc;

	++$locCount;
	$firstLoc = $loc if $locCount == 1;

	my ($file, $line, $column, $msg, $primary)
		= @$loc{qw/SourceFile StartLine StartColumn Explanation primary/};

	if (defined $file)  {
	    $m .= "*** $file";
	    $m .= ":$line" if defined $line;
	    $m .= ":$column" if defined $column;
	    $m .= " ***";
	}  else  {
	    $m .= "*** <no-file-information> ***";
	}
	$m .= "*** Primary Bug Location" if $primary eq 'true';
	if (defined $msg)  {
	    $msg =~ s/^/  /mg;
	    $m .= "\n$msg";
	}
        $m .= "\n";
    }

    return if $locCount == 0;
    my $firstLocMsg = $firstLoc->{Explanation};
    $firstLocMsg = '' unless defined $firstLocMsg;
    $self->{BugMessage} = '' unless defined $self->{BugMessage};
    return if $locCount == 1
	    && ($firstLocMsg eq $self->{BugMessage} || $firstLocMsg eq '');

    $self->{BugMessage} .= "\n\n" if $self->{BugMessage} ne '';
    $self->{BugMessage} .= "Bug Path:\n\n$m";
    $self->{BugMessage} .= "\n" unless $m =~ /\n$/;
}


sub setBugLocation
{
    my ($self, $bugLocationId, $bugClassname, $sourceFile, $startLine,
	    $endLine, $startColumn, $endColumn, $bugMessage, $primary,
	    $resolvedFlag, $noAdjustPath) = @_;

    my %bugLocation;

    $bugLocation{LocationId} = $bugLocationId if defined $bugLocationId;
    $bugLocation{SourceFile} = $sourceFile if defined $sourceFile;
    $bugLocation{primary} = $primary if defined $primary;

    if (defined $startLine && $startLine != 0) {
        $bugLocation{StartLine} = $startLine;
    }
    if (defined $endLine && $endLine != 0) {
        $bugLocation{EndLine} = $endLine;
    }
    if (defined $startColumn && $startColumn != 0) {
        $bugLocation{StartColumn} = $startColumn;
    }
    if (defined $endColumn && $endColumn != 0) {
        $bugLocation{EndColumn} = $endColumn;
    }
    if (defined $bugMessage && $bugMessage ne "") {
        $bugLocation{Explanation} = $bugMessage;
    }
    $bugLocation{noAdjustPath} = 1 if $noAdjustPath;

    push @{$self->{BugLocations}}, \%bugLocation;
}

# This function is only used by error-prone.
# The parser should be updated to use setBugLocation() instead
# and this function should be retired.
sub setBugColumn
{
    my ($self, $start_column, $end_column, $bugLocationId) = @_;

    #FIXME: why $locationObject
    #my $locationObject = $self->{_bugLocations}[$bugLocationId]->setBugColumn($start_column, $end_column);
}


sub setBugMethod
{
    my ($self, $methodId, $className, $methodName, $primary) = @_;

    my %method = (
        MethodId => $methodId,
        name => $methodName,
        primary => $primary,
    );

    push @{$self->{Methods}}, \%method;
}

sub setClassName
{
    my ($self, $className) = @_;
    $self->{ClassName} = $className if defined $className;
}

# This function is only used by findbugs and pmd
# The parsers should be updated and this function should be retired.
# ClassStartLine and ClassEndLine are used when a location does not have a StartLine and EndLine
# ClassName is set just like the setClassName function
sub setClassAttribs
{
    my ($self, $classname, $sourcefile, $start, $end, $classMessage) = @_;
    $self->{_classSourceFile} = $sourcefile if defined $sourcefile;
    $self->{ClassName} = $classname if defined $classname;
    $self->{ClassStartLine} = $start if defined $start;
    $self->{ClassEndLine} = $end if defined $end;
    $self->{_classMessage} = $classMessage if defined $classMessage;
}

sub setBugSeverity
{
    my ($self, $bugSeverity) = @_;
    $self->{BugSeverity} = $bugSeverity if defined $bugSeverity;
}

sub setBugRank
{
    my ($self, $bugRank) = @_;
    $self->{BugRank} = $bugRank if defined $bugRank;
}


sub setCweId
{
    my ($self, $cweId) = @_;
    push(@{$self->{CweIds}}, $cweId) if defined $cweId;
}


sub setBugGroup {
   my ($self, $group) = @_;
   $self->{BugGroup} = $group if defined $group;
}

sub setBugCode {
    my ($self, $code) = @_;
    $self->{BugCode} = $code if defined $code;
}

sub setBugSuggestion
{
    my ($self, $suggestion) = @_;
    $self->{ResolutionSuggestion} = $suggestion if defined $suggestion;
}


sub setBugPath {
    my ($self, $bugPath) = @_;
    $self->{InstanceLocation}{Xpath} = $bugPath if defined $bugPath;
}


sub setBugLine
{
    my ($self, $bugLineStart, $bugLineEnd) = @_;
    $self->{InstanceLocation}{LineNum}{Start} = $bugLineStart if defined $bugLineStart;
    $self->{InstanceLocation}{LineNum}{End} = $bugLineEnd if defined $bugLineEnd;
}


sub setBugReportPath
{
    my ($self, $reportPath) = @_;
    $self->{AssessmentReportFile} = $reportPath if defined $reportPath;
}


sub getBugReportPath
{
    my ($self) = @_;
    return $self->{AssessmentReportFile} if exists $self->{AssessmentReportFile};
    return;
}


sub setBugBuildId
{
    my ($self, $buildId) = @_;
    $self->{BuildId} = $buildId if defined $buildId;
}

# This method is called by
# android-lint, dawnscanner, error-prone, phpmd & pmd.
# The parsers should be updated and this method should be retired.
sub setURLText
{
    my ($self, $url_txt) = @_;
    $self->{_url} = $url_txt if defined $url_txt;
}

# This method is called by pmd.
# The parser should be updated and this method should be retired.
sub setBugPackage
{
    my ($self, $bugPackage) = @_;
    $self->{_package} = $bugPackage if defined $bugPackage;
    return $self->{_package};
}

# This method is called by clang-sa
# The parser should be updated and this method should be retired.
sub setBugPathLength
{
    my ($self, $bugPathLength) = @_;
    $self->{_bugPathLength} = $bugPathLength if defined $bugPathLength;
    return $self->{_bugPathLength};
}

# This method is called by dawnscanner
# The parser should be updated to use setCweId() instead
# and this method should be retired.
sub setCWEInfo
{
    my ($self, $info) = @_;
    $self->{_cwe} = $info if defined $info;
    return $self->{_cwe};
}

# This method is called by gt-csonar
# The parser should be updated to use setCweId() instead
# and this method should be retired.
sub setCWEArray
{
    my $self = shift;
    if (@_ != 0)  {
        #$self->{_cwe_array} = [];
        #@{$self->{_cwe_array}} = @_;
        foreach my $cwe (@_) {
            setCweId($self, $cwe);
        }
    }
    #return @{$self->{_cwe_array}};
}

# This method is called by android-lint
# The parser should be updated and this method should be retired.
sub setBugPosition
{
    my ($self, $info) = @_;
    $self->{_position} = $info if defined $info;
    return $self->{_position};
}

# This method is called by brakeman
# The parser should be updated and this method should be retired.
sub setBugWarningCode
{
    my ($self, $info) = @_;
    $self->{_warningCode} = $info if defined $info;
    return $self->{_warningCode};
}

# This method is called by brakeman
# The parser should be updated and this method should be retired.
sub setBugToolSpecificCode
{
    my ($self, $info) = @_;
    $self->{_toolSpecificCode} = $info if defined $info;
    return $self->{_toolSpecificCode};
}

# This method is called by cppcheck
# The parser should be updated and this method should be retired.
sub setBugInconclusive
{
    my ($self, $info) = @_;
    $self->{_inconclusive} = $info if defined $info;
    return $self->{_inconclusive};
}

1;
