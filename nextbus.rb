require "gtk3"
require "json"
require "net/http"
require "date"
require 'influxdb'

@builder
@config
@weathermap

def get_object(name)
    return @builder.get_object(name)
end

def update_bus_stops
end

def update_date_time
    jour = ["Dimanche", "Lundi", "Mardi", "Mercredi", "Jeudi", "Vendredi", "Samedi"]
    mois = ["Janvier", "Février", "Mars", "Avril", "Mai", "Juin", "Juillet",
            "Août", "Septembre", "Octobre", "Novembre", "Decembre"]

    date_obj = get_object("DATE")
    time_obj = get_object("TIME")

    now = Time.new
    date_obj.set_text("#{jour[now.wday]} %0d #{mois[now.month-1]} %d" %
                        [now.day, now.year])

    time_obj.set_text("%02d:%02d" % [now.hour, now.min])
end

def get_current_weather
    begin
        response = Net::HTTP.get_response(URI(@config["meteo"]["url"]))
        case response
        when Net::HTTPSuccess then
            return response.body
        else
            warn "fetching open meteo error: %d %s" % [response.code, response.message]
        end
    end
    return ""
end

def daynight(sunrise_d1,sunrise_d2,sunset_d1,sunset_d2, time)
    if (time > sunrise_d1 && time < sunset_d1) ||
       (time > sunrise_d2 && time < sunset_d2)
        return "day"
    end
    return "night"
end

def update_meteo
    now = DateTime.now

    begin
        wdata = JSON.parse(get_current_weather());
    rescue => e
        return
    end

    sunrise_d1 = DateTime.parse(wdata['daily']['sunrise'][0])
    sunrise_d2 = DateTime.parse(wdata['daily']['sunrise'][1])
    sunset_d1 = DateTime.parse(wdata['daily']['sunset'][0])
    sunset_d2 = DateTime.parse(wdata['daily']['sunset'][1])

    curweather = get_object("WEATHER")
    wcode = wdata['hourly']['weather_code'][now.hour]
    daynight = daynight(sunrise_d1,sunrise_d2,sunset_d1,sunset_d2, now)

    puts wcode.to_s
    puts daynight
    curweather.set_text("#{wdata['hourly']['temperature_2m'][now.hour]}°C  #{@weathermap[wcode.to_s][daynight]['description']}")

    i = 0
    while i < 14
        time_obj = get_object("METEO_TIME%d" % [i])
        time_obj.set_text("%dh" % ((now.hour + i) % 24) )

        ico_obj = get_object("METEO_IMAGE%d" % [i])
        wcode = wdata['hourly']['weather_code'][now.hour + i]
        daynight = daynight(sunrise_d1,sunrise_d2,sunset_d1,sunset_d2, now + i/24r)
    puts wcode.to_s
    puts daynight
        ico_obj.set_from_file(
        "#{File.expand_path(File.dirname(__FILE__))}/images/#{@weathermap[wcode.to_s][daynight]['image']}")

        temp_obj = get_object("METEO_TEMP%d" % [i])
        temp_obj.set_text("#{wdata['hourly']['temperature_2m'][now.hour + i]}°")

        i = i + 1
    end
end

def get_schedule(line_id)
    begin
        uri = URI("#{@config['stop']['url']}%s:" % line_id )
        req = Net::HTTP::Get.new(uri)
        req['Accept'] = 'application/json'
        req['apikey'] = @config["stop"]["token"]

        response = Net::HTTP.start(uri.hostname, uri.port, use_ssl: uri.scheme == 'https') { |http|
            http.request(req)
        }

        case response
        when Net::HTTPSuccess then
            return response.body
        else
            warn "fetching stop id %d time: %d %s" % [line_id, response.code, response.message]
        end
    end
    return ""
end

def parse_color(hex_color)
  color = Gdk::RGBA.new
  color.parse(hex_color)
  color
end

def update_bus_stops_time
    timearray = Array.new
    @config['stop']['stops'].each {|line|
        begin
            response = JSON.parse(get_schedule(line['id']))
            schedule = response['Siri']['ServiceDelivery']['StopMonitoringDelivery'][0]['MonitoredStopVisit']
        rescue
            next
        end
        now = DateTime.now

        stop_time = Array.new
        schedule.each {|schedule|
            if schedule['MonitoredVehicleJourney']['OperatorRef']['value'].match("\\.%s:$" %line ['bus_number'])
                delay = DateTime.parse(schedule['MonitoredVehicleJourney']['MonitoredCall']['ExpectedDepartureTime']) - now
                delay_mn = (delay * 24 * 60).to_i
                stop_time.push( [ delay_mn, schedule['MonitoredVehicleJourney']['MonitoredCall']['DestinationDisplay'][0]['value']])
            end
        }
        if stop_time.length() > 0
            stop_time = stop_time.sort_by { |s| s[0].to_i }
            timearray.push([ line, stop_time])
        end

    }
    timearray = timearray.sort_by { |s|
        s[1][0][0].to_i
    }
    lineno = 0
    timearray.each { |x|
        num_object = get_object("BUS_LIGNE_%d" % lineno)
        dest_object = get_object("BUS_DESTINATION_%d" % lineno)
        first_stop_obj = get_object("BUS_PASSAGE0_%d" % lineno)
        second_stop_obj = get_object("BUS_PASSAGE1_%d" % lineno)
        bgcolor = parse_color(x[0]['bus_color']);
        attr = Pango::AttrList.new
        attr.insert(Pango::AttrForeground.new(65535 ,65535 ,65535))
        attr.insert(Pango::AttrBackground.new(65535 * bgcolor.red, 65535 * bgcolor.green, 65535 *bgcolor.blue))
        attr.insert(Pango::AttrFontDesc.new("Sans Bold 14"))

        num_object.set_attributes(attr)
        num_object.set_text("  %d  " % x[0]['bus_number'])
        dest_object.set_text(" #{x[0]['extra']} #{x[1][0][1]}")
        if x[1][0][0].to_i > 1
            first_stop_obj.set_text("#{x[1][0][0]} mn")
        else
            #first_stop_obj.set_text("🚏🚌")
            first_stop_obj.set_text("0 mn")
        end

        if x[1].length() > 1
            second_stop_obj.set_text("#{x[1][1][0]} mn")
        else
            second_stop_obj.set_text("")
        end
        lineno = lineno + 1
    }

    attr = Pango::AttrList.new
    attr.insert(Pango::AttrForeground.new(65535 ,65535 ,65535))
    attr.insert(Pango::AttrBackground.new(65535 ,65535 ,65535))
    attr.insert(Pango::AttrFontDesc.new("Sans Bold 14"))

    while lineno <= 3
        num_object = get_object("BUS_LIGNE_%d" % lineno)
        dest_object = get_object("BUS_DESTINATION_%d" % lineno)
        first_stop_obj = get_object("BUS_PASSAGE0_%d" % lineno)
        second_stop_obj = get_object("BUS_PASSAGE1_%d" % lineno)

        num_object.set_attributes(attr)
        num_object.set_text("")
        dest_object.set_text("")
        first_stop_obj.set_text("")
        second_stop_obj.set_text("")
        lineno = lineno + 1
    end

end

def update_waterlevel
    i = 0
    one_hours_ago = Time.now - (1000)

    influxdb = InfluxDB::Client.new 'waterlevel', host: "central.home"
    @config['waterlevel'].each { |wl|
        mlabel_object = get_object("MLABEL%d" % i)
        moist_object = get_object("MOIST%d" % i)

        mlabel_object.set_text(wl['label'])
        puts "query #{wl['label']} ---- "

        points = influxdb.query "SELECT * FROM \"Fineoffset-WH51\" where id = '#{wl['id']}' ORDER BY time DESC LIMIT 1;"
        if points.count > 0
            point = points[0]['values'][0];
            puts "#{Time.parse(point['time'].to_s)} #{one_hours_ago.utc}"
            if Time.parse(point['time'].to_s) > one_hours_ago
                moist_object.set_text("#{point['moisture'].to_s}")
            else
                moist_object.set_text("DOWN")
            end
        else
            moist_object.set_text("OFF")
        end
        i = i + 1
    }
end

def load_ui

    wfile = File.read("#{File.expand_path(File.dirname(__FILE__))}/weather.json")
    @weathermap = JSON.parse(wfile)

    cfg = File.read("#{File.expand_path(File.dirname(__FILE__))}/nextbus.json")
    @config = JSON.parse(cfg)

    builder_file = "#{File.expand_path(File.dirname(__FILE__))}/nextbus.ui"

    # Construct a Gtk::Builder instance and load our UI description
    @builder = Gtk::Builder.new(:file => builder_file)

    # Connect signal handlers to the constructed widgets
    window = get_object("window")

    screen = Gdk::Screen.default

    window.set_default_size(1024, 600)
    window.resizable = false
end

def led_light()
    led = get_object("LedLight")
    #led.set_markup("<span background=\"#f6f6f5f5f4f4\" foreground=\"green\">↺</span>")
    led.set_markup("<span background=\"#f6f6f5f5f4f4\" foreground=\"green\">@</span>")
    GLib::Timeout.add(3000) do
       led = get_object("LedLight")
       #led.set_markup("<span background=\"#f6f6f5f5f4f4\" foreground=\"#f6f6f5f5f4f4\">↺</span>")
       led.set_markup("<span background=\"#f6f6f5f5f4f4\" foreground=\"#f6f6f5f5f4f4\">@</span>")
       false
    end
end

load_ui()
update_date_time()
update_meteo()
update_bus_stops_time()
#update_waterlevel()
led_light()

GLib::Timeout.add(100) do
    update_date_time
    true
end

GLib::Timeout.add(60000) do
    puts "Start Meteo update"
    update_meteo()
    puts "End Meteo update"
    true
end

GLib::Timeout.add(30000) do
    puts "Start Bus update"
    led_light()
    update_bus_stops_time()
    puts "End Bus update"
    true
end

GLib::Timeout.add(60000) do
    puts "Start Waterlevel update"
    #update_waterlevel()
    puts "End Waterlevel update"
    true
end

Gtk.main


