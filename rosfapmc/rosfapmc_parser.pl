#! /usr/bin/perl
use strict;
use warnings;
use utf8;

use Encode;
use Text::CSV_XS;
use LWP::UserAgent;
use HTTP::Request::Common;
use File::Temp qw/tempfile/;
use File::Spec;

grep { -x File::Spec->join($_, 'catdoc') } File::Spec->path
    or die "`catdoc' executable not found in $ENV{PATH}, try installing `catdoc' package\n";

my %sources = (
    'Перечень получателей господдержки в сфере периодической печати, осуществляющих реализацию социально значимых проектов в 2009 году'
        => 'http://www.fapmc.ru/files/download/719_file.doc',
    'Получатели государственной поддержки в сфере электронных СМИ Роспечати в 2009 году'
        => 'http://www.fapmc.ru/files/download/713_file.doc',
    'Перечень получателей господдержки в сфере периодической печати, осуществляющих реализацию социально значимых проектов в 2008 году'
        => 'http://www.fapmc.ru/files/download/556_file.doc',
    'Перечень получателей господдержки в сфере электронных СМИ, осуществляющих реализацию социально значимых проектов в 2008 году'
        => 'http://www.fapmc.ru/files/download/551_file.doc',
    'Перечень получателей господдержки в сфере электронных СМИ, осуществляющих реализацию социально значимых проектов в 2007 году'
        => 'http://www.fapmc.ru/files/download/411_file.doc',
    'Перечень получателей господдержки в сфере электронных СМИ, осуществляющих реализацию социально значимых проектов в 2006г.'
        => 'http://www.fapmc.ru/files/download/85_file.doc',
);

sub get_page {
    my $req = shift;
    my $delay = 1;
    our $ua;
    unless (defined $ua) {
        $ua = LWP::UserAgent->new();
    }

    my $resp;
    until (($resp = $ua->request($req))->is_success) {
        warn "error fetching [@{[$req->uri]}], delaying for $delay\n";
        sleep($delay *= 2);
    }

    return $resp->content;
}

my $csv = Text::CSV_XS->new({ binary => 1 });

for my $doc (keys %sources) {
    my ($doc_fh, $doc_filename) = tempfile();
    print $doc_fh get_page(GET $sources{$doc});
    close $doc_fh;

    my ($year) = $doc =~ /(\d{4})/ or warn "No year in [$doc], skipping\n", next;
    open my $csv_fh, '>:utf8', $year . ($doc =~ /периодич/ ? '_periodic' : '_electronic') . '.csv';

    my @rows = split /\\\\/, decode('utf-8', `catdoc -dutf8 -t $doc_filename`);
    shift @rows;    # skip headers and blabla

    for my $row (@rows) {
        next if $row =~ /PAGE\s+\d+/ && $row !~ /[а-я]/i;  # ending lines

        my @cols = map { s/\s+/ /sg; s/HYPERLINK "[^"]+"//g; $_ eq ' ' ? () : ($_) } split /&/, $row;
        next if @cols < 2;

        $csv->print($csv_fh, \@cols);
        print $csv_fh "\n";
    }
    close $csv_fh;
}
