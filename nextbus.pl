    use strict;
    use warnings;
    use LWP::Simple;
    use LWP::UserAgent;
    use HTML::TreeBuilder::XPath;
    use Gtk2 '-init';
    use constant false => 0;
    use constant true  => 1;
    use Text::CSV;
    use Time::localtime;
    use JSON;
    use DateTime;
    use Data::Dumper;
    use DateTime::Format::RFC3339;
    use HTML::Entities;
    my @msgline;


    my @time_array;
    my @timeline;
    my $clockline;
    my $meteopng;
    my $meteotemp;
    my %colors = ( "258", "red", "157", "purple", "259", "blue" );

    my $count = 0;
    my $font_size  = "17000" . '" font_family = "dejavu';
    my $font_name  = "dejavu";
    my $stopname;
    my $api = "https://prim.iledefrance-mobilites.fr/marketplace/stop-monitoring?MonitoringRef=STIF:StopPoint:Q:";
    my $dateparser = DateTime::Format::RFC3339->new();

    sub fill_array() {
        my $line    = shift;
        my $url     = shift;
        my $sens    = shift;
        my $tree;
        my @monitoringDelivery;
        my @schedule;

        print "Update ligne $line / $sens : $url $ENV{'STIF_TOKEN'}\n";
        my $ua = LWP::UserAgent->new;
        my $res = $ua->get($url,
            'Accept' => 'application/json',
            'apikey' => $ENV{'STIF_TOKEN'});

        if ($res->is_success) {
            print "Line update Success\n";
            $tree = eval { return decode_json($res->decoded_content); };
            @monitoringDelivery = @{ $tree->{Siri}{ServiceDelivery}{StopMonitoringDelivery} };
            @schedule = @{ $monitoringDelivery[0]->{MonitoredStopVisit} };
            $tree = eval { return decode_json($res->decoded_content); };
        }

        my $rec1;
        my $rec2;

        my $time;
        my $ntime;
        my $dest;
        my $i = 2;

        my $drift = 0;

        if(not $tree){
            print "Ooops\n";
            return 1;
        }

        $time = $schedule[1]->{message};
        $dest = $schedule[0]->{MonitoredVehicleJourney}{MonitoredCall}{DestinationDisplay}[0]{value};

        $dest =~ s/.+>.//g;
        $dest =~ s/Zone/Z./;

        my $reftime = $dateparser->parse_datetime($monitoringDelivery[0]->{ResponseTimestamp});
        foreach my $montime (@schedule)
        {
            next if ($montime->{MonitoredVehicleJourney}{OperatorRef}{value} !~ /\.${line}/);
            my $record;
            $record->{'line'} = $line;
            $record->{'dest'} = encode_entities("[${sens}] " . $montime->{MonitoredVehicleJourney}{MonitoredCall}{DestinationDisplay}[0]{value});
            my $stoptime = $dateparser->parse_datetime($montime->{MonitoredVehicleJourney}{MonitoredCall}{ExpectedDepartureTime});
            my $delta = $reftime->delta_ms($stoptime);
            $record->{'delay'} = $delta->minutes;
            print "RECEIVED: " . $record->{'line'} . " " .$record->{'dest'} . " " . $delta->minutes . ":" . $delta->seconds."\n";
            push @time_array, $record;
        }
    1;
    }



    sub updatetime() {
        my $dt = DateTime->now();

        my $local = $dt->clone;
        $local->set_time_zone('Europe/Paris');

        $clockline->set_markup( ' <span font_size="'
            . $font_size
            . '" color="black" bgcolor="white">'
            . $local->strftime('%H:%M')
            . '</span>');

        1;
}

sub updatedisplay() {
    print "Update datas\n";
    my $label = "black";

    @time_array = ();
    $stopname="28785";
    &fill_array( "258", "${api}${stopname}:", "RER A");

    $stopname="27239";
    &fill_array( "259", "${api}${stopname}:", "RER A/TER L");

    $stopname="26140";
    &fill_array( "157", "${api}${stopname}:", "RER A");


    my @slist = sort {
         ( $a->{'delay'} <=> $b->{'delay'} )
    } @time_array;

    my $i = 0;
    foreach my $line (@slist)
    {
        $msgline[$i]->{"BUS"}->set_markup(' <span font_size="'
              . $font_size
              . '" color="white" bgcolor="'
              . $colors{ $slist[$i]->{'line'} } . '">'
              . $slist[$i]->{'line'}
              . '</span>');
        $msgline[$i]->{"DEST"}->set_markup('<span font_size="'
              . $font_size
              . '" color="'
              . $label
              . '" bgcolor="white">'
              . $slist[$i]->{'dest'}
              . '</span>');
        $msgline[$i]->{"TIME"}->set_markup('<span font_size="'
              . $font_size
              . '" color="'
              . $label
              . '" bgcolor="white">'
              . $slist[$i]->{'delay'}
              . "</span>" );
        $i++;
        last if ($i >= scalar(@msgline));
    }

    print "End Update datas\n";
    1;
}

sub updatemeteo() {
    my $description = "";
    my $icon;
    my $temp;
    my @weather;
    my $url= 'https://api.openweathermap.org/data/2.5/weather?id=2990970&appid=' . $ENV{'OPENWEATHER_TOKEN'} . '&units=metric&lang=fr';
    print "UPDATE METEO IN====>\n";
    my $content = get($url);
    print $content;
    my $tree = eval { return decode_json($content); };

    print $url . "\n";

    if(not $tree){
        print "METEO Ooops\n";
        return 1;
    }

    @weather = @{ $tree->{'weather'} };
    print  Dumper($tree);

    $icon = $weather[0]->{'icon'};
    $description = $weather[0]->{'description'};
    $temp = $tree->{'main'}{'feels_like'};

    $meteopng->set_from_file($icon .'@2x.png');
    print "ICON========> $icon" .'@2x.png\n';

    $meteotemp->set_markup( ' <span font_size="'
        . $font_size
        . '" color="black" bgcolor="white">'
        . "$temp C / $description"
        . '</span>');
    print ' <span font_size="'
        . $font_size
        . '" color="black" bgcolor="white">'
        . "$temp C / $description"
        . '</span>';
    print "UPDATE METEO OUT <====\n";

}

my $white = Gtk2::Gdk::Color->new( 0xFFFF, 0xFFFF, 0xFFFF );

my $fenetre = Gtk2::Window->new('toplevel');
my $table   = Gtk2::Table->new(8, 8, false);
my $screen  = $fenetre->get_screen;
$meteopng = Gtk2::Image->new_from_file('01d@2x.png');
$meteotemp = new Gtk2::Label("");
$meteotemp->set_markup( ' <span font_size="'
    . $font_size
    . '" color="black" bgcolor="white">'
    . "10.00 C / ciel degage"
    . '</span>');

$fenetre->modify_bg( 'normal', $white );

$clockline = new Gtk2::Label(" 00:00:00 ");


foreach my $i (0..5) {
    push(@msgline, { "BUS" => new Gtk2::Label("<<<<<BUS".$i)
                    ,"DEST" => new Gtk2::Label(">>>>>DEST".$i)
                    ,"TIME" => new Gtk2::Label("====TIME".$i)});
}


$table->attach_defaults( $clockline, 0, 2, 0, 1 );
$table->attach_defaults( $meteotemp, 2, 6, 0, 1 );
$table->attach_defaults( $meteopng,  6, 8, 0, 1 );


foreach my $i (0..5) {
    $table->attach_defaults( $msgline[$i]->{"BUS"},  0, 1, $i+1, $i+2 );
    $table->attach_defaults( $msgline[$i]->{"TIME"}, 6, 8, $i+1, $i+2 );
    $table->attach_defaults( $msgline[$i]->{"DEST"}, 1, 6, $i+1, $i+2 );
    $msgline[$i]->{"DEST"}->set_line_wrap(true);
}

$fenetre->add($table);
$fenetre->show_all;
$fenetre->resize( $screen->get_width, $screen->get_height );
#$fenetre->fullscreen();


updatemeteo();
updatedisplay();
updatetime();

Glib::Timeout->add( 60000, \&updatemeteo );
Glib::Timeout->add( 30000, \&updatedisplay );
Glib::Timeout->add( 100, \&updatetime);

Gtk2->main;
