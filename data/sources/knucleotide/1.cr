# k-nucleotide: counts every k-mer of the THREE sequence in a Hash keyed by 2-bit packed codes.
def code_of(c : UInt8) : UInt64
  case c.unsafe_chr
  when 'A' then 0_u64
  when 'C' then 1_u64
  when 'G' then 2_u64
  else          3_u64
  end
end

def count_kmers(seq : Bytes, k : Int32) : Hash(UInt64, Int32)
  counts = Hash(UInt64, Int32).new(0)
  mask = (1_u64 << (2 * k)) &- 1
  key = 0_u64
  seq.each_with_index do |c, i|
    key = ((key << 2) | code_of(c)) & mask
    counts[key] += 1 if i + 1 >= k
  end
  counts
end

def unpack(key : UInt64, k : Int32) : String
  String.build do |s|
    (k - 1).downto(0) { |i| s << "ACGT"[(key >> (2 * i)) & 3] }
  end
end

def print_frequencies(seq : Bytes, k : Int32)
  total = (seq.size - k + 1).to_f
  sorted = count_kmers(seq, k).map { |key, count| {unpack(key, k), count} }
  sorted.sort! { |a, b| a[1] != b[1] ? b[1] <=> a[1] : a[0] <=> b[0] }
  sorted.each { |kmer, count| printf("%s %.3f\n", kmer, count * 100.0 / total) }
  puts
end

file_name = ARGV.size > 0 ? ARGV[0] : "25000_in"
io = IO::Memory.new
File.open(file_name) do |file|
  file.each_line { |line| break if line.starts_with?(">THREE") }
  file.each_line do |line|
    break if line.starts_with?('>')
    io << line.strip.upcase
  end
end
seq = io.to_slice

print_frequencies(seq, 1)
print_frequencies(seq, 2)
["GGT", "GGTA", "GGTATT", "GGTATTTTAATT", "GGTATTTTAATTTATAGT"].each do |kmer|
  key = kmer.each_byte.reduce(0_u64) { |acc, c| (acc << 2) | code_of(c) }
  puts "#{count_kmers(seq, kmer.size)[key]}\t#{kmer}"
end
