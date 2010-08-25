#! /usr/bin/perl
use uni::perl;

use URI;
use Encode;
use Web::Scraper;
use Data::Dump;
use Text::CSV_XS;
use LWP::UserAgent;
use HTTP::Request::Common;
use HTML::Form;
use Encode;
use autodie;
use signatures;

my $DEBUG = 0;

sub get_page($req) {
    my $delay = 1;
    state $ua;
    unless (defined $ua) {
        $ua = LWP::UserAgent->new();
        $ua->show_progress(1) if $DEBUG;
    }

    my ($resp, $data);
    until (($resp = $ua->request($req))->is_success
        && ($data = decode('cp1251', $resp->content)) !~ /возникли технические неполадки/) {

        warn "error fetching [@{[$req->uri]}], delaying for $delay\n";
        sleep($delay *= 2);
    }

    return $data;
}

my $url = 'http://rnp.fas.gov.ru/';

my $unfair_list_scraper = scraper {
    # <thead> is skipped via XPath children axis magic
    process '//table[@class="data"]/tr[position() < last()]/td[1]/input[1]', 'ids[]' => sub { $_[0]->attr('onclick') =~ /id=([^"]+)"/ ? $1 : undef },
};

my $unfair_scraper = scraper {
    process '//table[@class="form"]/tr/td[2]', 'values[]' => 'TEXT',
};

my @ids = ();
my $page = get_page(GET $url);
my ($total) = ($page =~ m{<span id="ctl00_phWorkZone_rnpList_datapgr_lblRecNumAll">(\d+)</span>});
my $from = 0;
my $form = HTML::Form->parse($page, $url);

$|++;
while ($total - $from > 500) {
    @ids and $form->param('ctl00$phWorkZone$rnpList$datapgr$tbRecNumFrom', $from = scalar @ids + 1);
    $form->param('ctl00$phWorkZone$rnpList$datapgr$ddlVolume', 500);

    $page = get_page($form->click);
    push @ids, @{$unfair_list_scraper->scrape($page)->{ids}};

    $form = HTML::Form->parse($page, $url);
}

say "we have " . scalar @ids . " entries";

my $csv = Text::CSV_XS->new({ binary => 1 });
open my $file, '>:utf8', 'output.csv';

for my $id (@ids) {
    my @fields = @{$unfair_scraper->scrape(get_page(GET "${url}RNPCard.aspx?id=$id"))->{values}};
    $csv->print($file, \@fields);
    print $file "\n";
    print ".";
}
say;

close $file;

__END__
todo:
2. no headers
