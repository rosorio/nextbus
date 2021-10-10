    use strict;
    use warnings;
    use LWP::Simple;
    use HTML::TreeBuilder::XPath;
    use Gtk2 '-init';
    use constant false => 0;
    use constant true  => 1;
    use Text::CSV;
    use Time::localtime;
    use JSON;
    use DateTime;
    use Data::Dumper;


    my @time_array;
    my @timeline;
    my $clockline;
    my $meteopng;
    my $meteotemp;
    my %colors = ( "258", "red", "157", "purple", "259", "blue" );

    my $count = 0;
    my $font_size  = "22000" . '" font_family = "dejavu';
    my $font_name  = "dejavu";
    my $stopname="lenine";
    #my $stopname="musee+de+l+air+et+de+l+espace";
    #my $stopname="juste+heras";
    my $api = "https://api-ratp.pierre-grimaud.fr/v4/schedules/buses";

    sub fill_array() {
        my $line    = shift;
        my $url     = shift;
        my $tree;

        my $content = get($url) or print 'Unable to get page';
        $tree = eval { return decode_json($content); };
        my $rec1;
        my $rec2;

        my $time;
        my $ntime;
        my $dest;
        my $i = 2;

        my $drift = 0;

        if(not $tree){
            print "Ooops\n";
            return 0;
        }


        my @schedule = @{ $tree->{result}{schedules} };
        $time = $schedule[0]->{message};
        $dest = $schedule[0]->{destination};
        print $tree->{_metadata}{date} . "\n";
        print "$time $dest\n";

        $dest =~ s/.+>.//g;
        $dest =~ s/Zone/Z./;

        ($ntime) = $time =~ /(\d+)/;

        $rec1->{'line'}  = $line;
        $rec1->{'ptime'} = $rec1->{'ctime'};
        $rec1->{'ctime'} = $ntime;
        $rec1->{'time'}  = $time;
        $time =~ s/[^\d]//g;
        $rec1->{'tval'}  = $time;
        $rec1->{'dest'}  = $dest;
        $rec1->{'drift'} = $drift;
        push @time_array, $rec1;

        $time = $schedule[1]->{message};
        $dest = $schedule[1]->{destination};
        print "$time $dest\n";
        ($ntime) = $time =~ /(\d+)/;
        $dest =~ s/Zone/Z./;
        $dest =~ s/.+>.//g;
        $rec2->{'line'}  = $line;
        $rec2->{'ptime'} = $rec2->{'ctime'};
        $rec2->{'ctime'} = $ntime;
        $rec2->{'drift'} = $drift;
        $rec2->{'time'}  = $time;
        $time =~ s/[^\d]//g;
        $rec2->{'tval'} = $time;
        $rec2->{'dest'} = $dest;
        push @time_array, $rec2;
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

    @time_array = ();
$stopname="Clemenceau+Sadi+Carnot";
    &fill_array( "258", "${api}/258/${stopname}/R"
    );
$stopname="carriers";
    &fill_array( "259", "${api}/259/${stopname}/R"
    );
    $stopname="Clemenceau+Sadi+Carnot";
    &fill_array( "157", "${api}/157/${stopname}/A"
    );


    my @slist = sort {
        ( $a->{'tval'} + $a->{'drift'} ) <=> ( $b->{'tval'} + $b->{'drift'} )
    } @time_array;

    my $i    = 0;
    my $honk = 0;
    for my $dline (@timeline) {
        my $label = "black";
        my $realtime = "";
        if ( $slist[$i]->{'drift'} > 4 ) {
            $label = "red";
        }

        if ( $slist[$i]->{'ctime'} =~ m/^\d/ ) {
            $realtime =
              ( $slist[$i]->{'ctime'} + $slist[$i]->{'drift'} ) . " mn";
        }
        else {
            $realtime = $slist[$i]->{'time'};
        }

        my $destination = substr("$slist[$i]->{'dest'}",0, 20);
        $destination .= ".." . " " x(24 - length($destination));
        $dline->set_markup( ' <span font_size="'
              . $font_size
              . '" color="white" bgcolor="'
              . $colors{ $slist[$i]->{line} } . '">'
              . $slist[$i]->{line}
              . '</span>('
              . $slist[$i]->{'drift'}
              . ')<span font_size="'
              . $font_size
              . '" color="'
              . $label
              . '" bgcolor="white">'
              . " $destination"
              . $realtime
              . "</span>" );

        $i++;
    }
    system('/usr/local/bin/mplayer /usr/home/rodrigo/cars-passing.mp3 &')
      if ( $honk == 1 );
    print "End Update datas\n";
    1;
}

sub updatemeteo() {
    my $description = "";
    my $icon;
    my $temp;
    my @weather;
    my $content = get('https://api.openweathermap.org/data/2.5/weather?id=XXXXXXXXXXXXXXXXX&units=metric&lang=fr') or print 'Unable to get page';
    my $tree = eval { return decode_json($content); };

    if(not $tree){
        print "Ooops\n";
        return 0;
    }

    @weather = @{ $tree->{'weather'} };
    #print  Dumper($tree);

    $icon = $weather[0]->{'icon'};
    $description = $weather[0]->{'description'};
    $temp = $tree->{main}{feels_like};

    $meteopng->set_from_file($icon .'@2x.png');

    $meteotemp->set_markup( ' <span font_size="'
        . $font_size
        . '" color="black" bgcolor="white">'
        . "$temp C / $description"
        . '</span>');

}

my $white = Gtk2::Gdk::Color->new( 0xFFFF, 0xFFFF, 0xFFFF );

my $fenetre = Gtk2::Window->new('toplevel');
my $screen  = $fenetre->get_screen;
my $table   = Gtk2::Table->new( 7, 6, true );
$meteopng = Gtk2::Image->new_from_file('01d@2x.png');
$meteotemp = new Gtk2::Label("");
$meteotemp->set_markup( ' <span font_size="'
    . $font_size
    . '" color="black" bgcolor="white">'
    . "10.00 C / ciel degage"
    . '</span>');

$fenetre->modify_bg( 'normal', $white );

$clockline = new Gtk2::Label(" 00:00:00 ");

$timeline[0] = new Gtk2::Label("");
$timeline[1] = new Gtk2::Label("");
$timeline[2] = new Gtk2::Label("");
$timeline[3] = new Gtk2::Label("");


$table->attach_defaults( $clockline, 0, 1, 0, 1 );
$table->attach_defaults( $meteotemp, 1, 3, 0, 1 );
$table->attach_defaults( $meteopng,  3, 5, 0, 1 );

#$table->attach_defaults( $clockline[1], 0, 6, 1, 2 );
#$table->attach_defaults( $clockline[2], 0, 6, 2, 3 );

$table->attach_defaults( $timeline[0], 0, 5, 1, 2 );
$table->attach_defaults( $timeline[1], 0, 5, 2, 3 );
$table->attach_defaults( $timeline[2], 0, 5, 3, 4 );
$table->attach_defaults( $timeline[3], 0, 5, 4, 5 );
for my $dline (@timeline) {
    $dline->set_alignment( 0, 0.5 );
}

$fenetre->resize( $screen->get_width, $screen->get_height );
$fenetre->add($table);
$fenetre->show_all;

updatemeteo();
updatedisplay();
updatetime();

Glib::Timeout->add( 60000, \&updatemeteo );
Glib::Timeout->add( 30000, \&updatedisplay );
Glib::Timeout->add( 100, \&updatetime);

Gtk2->main;
