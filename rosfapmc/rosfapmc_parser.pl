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
use XML::LibXML;

grep { -x File::Spec->join($_, 'antiword') } File::Spec->path
    or die "`antiword' executable not found in $ENV{PATH}, try installing `antiword' package\n";

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

    my @rows = XML::LibXML->load_xml(string => decode('utf-8', `antiword -x db $doc_filename`))->findnodes('//tbody/row');
    shift @rows;    # skip headers

    for my $row (@rows) {
        my @cols = map {
            s/[ \t]+/ /g;
            s/[ \t]*\n+[ \t]*/\n/g;
            s/^\n//; s/\n\z//g;

            $_ eq ' ' ? () : ($_)
        } map { $_->textContent() } $row->nonBlankChildNodes();
        next if @cols < 2;

        $csv->print($csv_fh, \@cols);
        print $csv_fh "\n";
    }
    close $csv_fh;
}
