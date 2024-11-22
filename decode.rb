require "zlib"

VERBOSE = false

def main
  ARGV.each do |filename|
    puts "Decoding #{filename}."
    File.open(filename, "rb") do |file|
      decode(Zlib::GzipReader.new(file), verbose: VERBOSE)
    end
  end
end

SQUAWK_MARKER = (1 << 30)
LL_SCALE = 1E6.to_f

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
def decode(gz, verbose:)
  # Read all of these bad boys:
  # struct heatEntry {
  #    int32_t hex;
  #    int32_t lat;
  #    int32_t lon;
  #    int16_t alt;
  #    int16_t gs;
  #} __attribute__ ((__packed__));
  entries = 0
  in_index = true
  i = 0
  while buf = gz.read((32*3+16*2)/8)
    hex = buf.unpack("L<").first
    in_index = false if in_index && hex == 0xe7f7c9d
    case
    when in_index
      s = verbose ? "index: #{hex}" : nil
    when hex == 0xe7f7c9d
      ss_high, ss_low, heatmap_interval = buf.unpack("xxxxL<L<s<")
      slice_stamp = (ss_high << 32) | ss_low
      start = slice_stamp - (i * heatmap_interval)
      start = Time.at(start / 1000)
      slice_stamp = Time.at(slice_stamp / 1000)
      s = slice_stamp.to_s
      i += 1
    else
      lat, lon, alt, gs = buf.unpack("xxxxl<l<s<s<")
      if lat & SQUAWK_MARKER == SQUAWK_MARKER
        addr = hex
        squawk = lat & ~SQUAWK_MARKER
        callsign = [lon, alt, gs].pack("l<s<s<")
        s = "addr: #{addr}, squawk: #{squawk}, callsign: #{callsign.inspect}"
      else
        addrtype_5bits = (hex >> 27) & 0b11111
        addr = hex & 0x07ffffff
        lat = lat / LL_SCALE
        lon = lon / LL_SCALE
        s = {addr_type: addrtype_5bits, addr: addr, lat: lat, lon: lon, alt: alt, gs: gs}.inspect
      end
    end
    printf "[%10d] %s\n", entries, s if s
    entries += 1
  end
end

main
