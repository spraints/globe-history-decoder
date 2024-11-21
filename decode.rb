require "zlib"

def main
  ARGV.each do |filename|
    puts "Decoding #{filename}."
    File.open(filename, "rb") do |file|
      decode(Zlib::GzipReader.new(file))
    end
  end
end

# Inside the ttf file, there are two sections: the index and buffer2.
# https://github.com/wiedehopf/readsb/blob/c3214b36f7962793917e5830500bf611c1a04060/globe_index.c#L3318-L3321
# Both sections are arrays of 'struct heatEntry'.
# https://github.com/wiedehopf/readsb/blob/c3214b36f7962793917e5830500bf611c1a04060/globe_index.h#L81-L91
#
# The index portion has only the hex field set to the index in the complete
# array of a buffer2 group of entries.
#
# The buffer2 portion has one "special sauce" entry and N "buffer" entries.
#
# The special sauce entry has:
# - hex = 0xe7f7c9d
# - lat/lon = 64 bit slice_stamp (start + i * Modes.heatmap_interval), broken
#   out into these two 32 bit fields.
# - alt = Modes.heatmap_interval.
#
# https://github.com/wiedehopf/readsb/blob/c3214b36f7962793917e5830500bf611c1a04060/globe_index.c#L3270-L3285
#
# The N "buffer" entries can be formatted once of two ways:
# - https://github.com/wiedehopf/readsb/blob/c3214b36f7962793917e5830500bf611c1a04060/globe_index.c#L3196-L3199
# - https://github.com/wiedehopf/readsb/blob/c3214b36f7962793917e5830500bf611c1a04060/globe_index.c#L3223-L3240
def decode(gz)
  # Read all of these bad boys:
  # struct heatEntry {
  #    int32_t hex;
  #    int32_t lat;
  #    int32_t lon;
  #    int16_t alt;
  #    int16_t gs;
  #} __attribute__ ((__packed__));
  i = 0
  in_index = true
  while buf = gz.read((32*3+16*2)/8)
    hex, lat, lon, alt, gs = buf.unpack("l<l<l<s<s<")
    in_index = false if in_index && hex == 0xe7f7c9d
    case
    when in_index
      s = "index: #{hex}"
    when hex == 0xe7f7c9d
      if lat < 0 || lon < 0
        puts "WARNING: lat or lon is negative: #{lat}, #{lon}"
      end
      slice_stamp = (lat << 32) | lon
      s = "special sauce: 0x#{slice_stamp.to_s(16)}, #{alt}"
    else
      s = {hex: hex, lat: lat, lon: lon, alt: alt, gs: gs}.inspect
    end
    printf "[%10d] %s\n", i, s
    i += 1
  end
end

main
