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
    my @msgline;


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
    for my $dline (@msgline) {
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
        $dline->{"BUS"}->set_markup(' <span font_size="'
              . $font_size
              . '" color="white" bgcolor="'
              . $colors{ $slist[$i]->{line} } . '">'
              . $slist[$i]->{line}
              . '</span>');
        $dline->{"DEST"}->set_markup('<span font_size="'
              . $font_size
              . '" color="'
              . $label
              . '" bgcolor="white">'
              .'<span font_size="'
              . "$destination");

        $dline->{"TIME"}->set_markup('<span font_size="'
              . $font_size
              . '" color="'
              . $label
              . '" bgcolor="white">'
              .'<span font_size="'
              . " $destination");
        $dline->{"DEST"}->set_markup('<span font_size="'
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
    my $content = get('https://api.openweathermap.org/data/2.5/weather?id=' . $ENV{'OPENWEATHER_TOKEN'} . 'units=metric&lang=fr') or print 'Unable to get page';
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


$table->attach_defaults( $clockline, 0, 1, 0, 1 );
$table->attach_defaults( $meteotemp, 1, 4, 0, 1 );
$table->attach_defaults( $meteopng,  4, 6, 0, 1 );


foreach my $i (0..5) {
    $table->attach_defaults( $msgline[$i]->{"BUS"},  0, 1, $i+1, $i+2 );
    $table->attach_defaults( $msgline[$i]->{"TIME"}, 6, 8, $i+1, $i+2 );
    $table->attach_defaults( $msgline[$i]->{"DEST"}, 1, 6, $i+1, $i+2 );
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
