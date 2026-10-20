# regex-redux with Crystal's Regex (PCRE2). Counting with String#scan walks byte offsets; 1.cr calls
# match(pattern, pos) with character positions, which rescans the 25 MB string on every match.
file_name = ARGV.size > 0 ? ARGV[0] : "25000_in"
content = File.read(file_name)
ilen = content.bytesize
content = content.gsub(/>.*\n|\n/, "")
clen = content.bytesize

[/agggtaaa|tttaccct/,
 /[cgt]gggtaaa|tttaccc[acg]/,
 /a[act]ggtaaa|tttacc[agt]t/,
 /ag[act]gtaaa|tttac[agt]ct/,
 /agg[act]taaa|ttta[agt]cct/,
 /aggg[acg]aaa|ttt[cgt]ccct/,
 /agggt[cgt]aa|tt[acg]accct/,
 /agggta[cgt]a|t[acg]taccct/,
 /agggtaa[cgt]|[acg]ttaccct/].each do |pattern|
  count = 0
  content.scan(pattern) { count += 1 }
  puts "#{pattern.source} #{count}"
end

{
  /tHa[Nt]/            => "<4>",
  /aND|caN|Ha[DS]|WaS/ => "<3>",
  /a[NSt]|BY/          => "<2>",
  /<[^>]*>/            => "|",
  /\|[^|][^|]*\|/      => "-",
}.each { |pattern, replacement| content = content.gsub(pattern, replacement) }

puts "\n#{ilen}\n#{clen}\n#{content.bytesize}"
