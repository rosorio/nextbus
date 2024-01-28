require 'influxdb'

influxdb = InfluxDB::Client.new 'waterlevel', host: "central.home"

influxdb.query 'select last(*) from "Fineoffset-WH51" group by id' do |name, tags, points|
  realname=""
  case tags['id']
  when "0d484a"
    realname="monstera"
  when "0d4a5d"
    realname="jacintes"
  when "0d4a6b"
    realname="shiflora"
  when "0d4b6b"
    realname="pellaea"
  end
#  printf "%s [ %p ] %s\n", name, tags, realname
#  printf "%s (%s)", realname, tags['id']
  printf "%s ", realname
  points.each do |pt|
    #printf "  -> %p\n", pt
    printf "%s %%", pt['last_moisture']
  end
  printf "  // "
end



