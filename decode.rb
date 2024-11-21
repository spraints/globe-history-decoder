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
  r, w = IO.pipe
  spawn "xxd", in: r
  r.close
  w.write gz.read(32)
  w.close
  Process.wait
end

main
