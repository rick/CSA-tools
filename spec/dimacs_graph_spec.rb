$:.unshift(File.expand_path(File.join(File.dirname(__FILE__), "..", "lib")))

require "minitest/autorun"
require "tmpdir"
require "dimacs_graph"

# Return the path to a named fixture file.
def fixture_file(name)
  File.expand_path(File.join(File.dirname(__FILE__), "fixtures", name))
end

# Return a normalized version of a graph file, suitable for test comparison.
def normalize_graph_file(contents)
  contents.lines.map {|l| l.chomp.gsub(/\s+/, ' ') }.sort.join("\n")
end

describe "parsing a DIMACS assignment problem graph file" do
  before do
    @basedir = Dir.mktmpdir
  end

  it "fails if the specified file cannot be read" do
    assert_raises(Errno::ENOENT) do
      process = DimacsGraph.process "/non/existent/file", @basedir
    end
  end

  it "fails if the file does not have a problem line" do
    assert_raises RuntimeError do
      process = DimacsGraph.process fixture_file("no-problem-line.txt"), @basedir
    end
  end

  it "fails if the file does not have an assignment problem line" do
    assert_raises RuntimeError do
      process = DimacsGraph.process fixture_file("invalid-problem-line.txt"), @basedir
    end
  end

  it "fails if the file contains an unrecognizeable line" do
    assert_raises RuntimeError do
      process = DimacsGraph.process fixture_file("unrecognizeable-line.txt"), @basedir
    end
  end

  it "fails if the file does not have the number of arcs listed in the problem line" do
    assert_raises RuntimeError do
      process = DimacsGraph.process fixture_file("arc-count-too-low.txt"), @basedir
    end

    assert_raises RuntimeError do
      process = DimacsGraph.process fixture_file("arc-count-too-high.txt"), @basedir
    end
  end

  it "fails if the file does not mention all the nodes listed in the problem line" do
    assert_raises RuntimeError do
      process = DimacsGraph.process fixture_file("node-count-too-low.txt"), @basedir
    end

    assert_raises RuntimeError do
      process = DimacsGraph.process fixture_file("node-count-too-high.txt"), @basedir
    end
  end

  it "fails if the file mentions a node higher than the count in the problem line" do
    assert_raises RuntimeError do
      process = DimacsGraph.process fixture_file("node-with-index-too-high-on-node-list.txt"), @basedir
    end

    assert_raises RuntimeError do
      process = DimacsGraph.process fixture_file("node-with-index-too-high-on-arc-list.txt"), @basedir
    end
  end

  it "can return the correct number of nodes from the file's problem line" do
    process = DimacsGraph.process fixture_file("10-node-graph.txt"), @basedir
    assert_equal 10, process.problem_node_count
  end

  it "can return the correct number of arcs from the file's problem line" do
    process = DimacsGraph.process fixture_file("10-node-graph.txt"), @basedir
    assert_equal 20, process.problem_arc_count
  end

  it "generates the correct file" do
    [ "3-node-graph", "5-node-fan-graph", "10-node-graph" ].each do |path|
      input_file    = fixture_file("#{path}.txt")
      expected_file = fixture_file("#{path}-augmented.txt")

      process = DimacsGraph.process input_file, @basedir
      expected = normalize_graph_file(File.read(expected_file))
      actual   = normalize_graph_file(File.read(process.results_path))
      assert_equal expected, actual,
        "Result path did not match. Input file [#{input_file}], " +
        "expected file [#{expected_file}], output file [#{process.results_path}]\n" +
        "\n\noutput:\n\n#{File.read(process.results_path)}"
    end
  end
end
