$:.unshift(File.expand_path(File.join(File.dirname(__FILE__), "..", "lib")))

require "minitest/autorun"
require "tmpdir"
require "matching_translator"

# Return the path to a named fixture file.
def fixture_file(name)
  File.expand_path(File.join(File.dirname(__FILE__), "fixtures", name))
end

# Return a normalized version of a graph file, suitable for test comparison.
def normalize_results(contents)
  contents.lines.map {|l| l.chomp.gsub(/\s+/, ' ') }.sort.join("\n")
end

describe "Un-augmenting a DIMACS-format matching solution file" do
  before do
    @basedir = Dir.mktmpdir
    @outfile = File.join(@basedir, "output.txt")
  end

  it "fails if the specified file cannot be read" do
    assert_raises(Errno::ENOENT) do
      process = MatchingTranslator.process 1, 2, "/non/existent/file", @outfile, silent = true
    end
  end

  it "generates the correct file" do
    # enumerate test cases; numbers are number of source nodes and total nodes in graph
    test_cases = {
      "3-node-graph"      => [2,  3],
      "5-node-fan-graph"  => [1,  5],
      "10-node-graph"     => [5, 10]
    }

    test_cases.keys.each do |which|
      input_file    = fixture_file("#{which}-augmented-match.txt")
      expected_file = fixture_file("#{which}-match.txt")
      sources, nodes = test_cases[which]
      process = MatchingTranslator.process sources, nodes, input_file, @outfile, silent = true
      expected = normalize_results(File.read(expected_file))
      actual   = normalize_results(File.read(@outfile))
      assert_equal expected, actual,
        "Result path did not match. Input file [#{input_file}], " +
        "expected file [#{expected_file}], output file [#{@outfile}]\n" +
        "\n\noutput:\n\n#{File.read(@outfile)}"
    end
  end
end
