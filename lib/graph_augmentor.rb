class GraphAugmentor
  attr_reader :silent, :file, :output_dir, :current_line, :line_count
  attr_reader :problem_source_count, :problem_node_count, :problem_arc_count
  attr_reader :final_node_count, :final_arc_count
  attr_reader :seen_nodes, :seen_arcs
  attr_reader :results_path

  # Process a GraphAugmentor file and generate an augmented graph file.
  def self.process(graph_file, output_dir, silent = false)
    processor = self.new(silent)
    processor.process graph_file, output_dir
    processor
  end

  # Create an instance of the Dimacs Graph processor class; no arguments necessary.
  def initialize(silent = false)
    @silent = silent
  end

  # Process the graph data located in the `graph_file` file, using `output_dir`
  # as a workspace, and for storage of the final augmented graph file.
  #
  # Returns the path to the augmented graph file.
  def process(graph_file, output_dir)
    raise ArgumentError, "process expects a graph file and an output path" unless graph_file && output_dir
    raise ArgumentError, "cannot find output directory [#{output_dir}]" unless File.directory?(output_dir)
    @file, @output_dir = graph_file, output_dir

    @problem_source_count = extract_problem_source_count

    File.open(file) do |f|
      f.each_line do |line|
        track_line line

        case line
        when /^a\s+/i
          process_arc_line line
        when /^n\s+/i
          process_node_line line
        when /^c\s+/i
          process_comment_line line
        when /^p\s+/i
          process_problem_line line
        else
          line_error "Unrecognized line"
        end
      end
    end

    validate_processed_file # can throw exceptions
    merge_output_files
  end

  def extract_problem_source_count
    node_line_seen      = false
    highest_node_number = 0

    File.open(file) do |f|
      f.each_line do |line|
        if node_line_seen
          return highest_node_number unless line =~ /^n\s+(\d+)/i
          candidate = $1.to_i
          highest_node_number = candidate if candidate > highest_node_number
        else
          if line =~ /^n\s+(\d+)/i
            node_line_seen = true
            highest_node_number = $1.to_i
          end
        end
      end
    end

    raise "No node lines in file [#{file}]" unless node_line_seen
    highest_node_number
  end

  # Raise an error message, including the current line and line offset on the
  # input graph file.
  def line_error(message)
    raise "#{message} at [#{file}:#{line_count}]: [#{current_line}]"
  end

  def message(message)
    puts message unless silent
  end

  # Keep track of the current line in the graph input file (for error message generation).
  def track_line(line)
    @current_line = line
    @line_count ||= 0
    @line_count += 1
  end

  # Handle a "problem line" from the input graph file.
  def process_problem_line(line)
    line_error "Multiple problem lines seen" if seen_problem_line?
    line_error "Invalid problem line" unless line =~ /^p\s+asn\s+(\d+)\s+(\d+)\s*$/i

    @problem_node_count, @problem_arc_count = $1.to_i, $2.to_i
    @seen_problem_line = true

    output_problem
  end

  # Output a "problem line" to the problem output working file.
  def output_problem
    @final_node_count = 2 * problem_node_count
    @final_arc_count  = 2 * problem_arc_count + problem_node_count
    problem_output_file.puts "p asn #{final_node_count} #{final_arc_count}"
  end

  # Return the file handle for the problem output working file.
  def problem_output_file
    @problem_output_file ||= File.open(problem_output_path, 'w')
  end

  # Return the location of the problem output working file (accumulates problem line + comment lines).
  def problem_output_path
    File.join(output_dir, "problem_output.txt")
  end

  # Have we already seen a problem line in this input file?
  def seen_problem_line?
    !!@seen_problem_line
  end

  # Handle a "comment line" from the input graph file.
  def process_comment_line(line)
    problem_output_file.puts line
  end

  # Handle a "node line" from the input graph file.
  def process_node_line(line)
    line_error "Invalid node line" unless line =~ /^n\s+(\d+)\s*$/i
    node_id = $1.to_i
    line_error "Node line seen before problem line" unless problem_node_count
    line_error "Node id exceeds node count (#{problem_node_count})" unless node_id <= problem_node_count
    output_node node_id
  end

  # Output a "node line" to the node output working file.
  def output_node(node_id)
    register_seen_node node_id
    node_output_file.puts "n #{node_id}"
  end

  # Return the file handle for the node output working file.
  def node_output_file
    @node_output_file ||= File.open(node_output_path, 'w')
  end

  # Return the location of the node output working file (accumulates node lines).
  def node_output_path
    File.join(output_dir, "node_output.txt")
  end

  # Register that we have seen a new node.
  #
  # (Currently only tracks node counts, but could track individual nodes.)
  def register_seen_node(node_id)
    @seen_nodes ||= 0
    @seen_nodes += 1
  end

  # Handle an "arc line" from the input graph file.
  def process_arc_line(line)
    line_error "Invalid arc line" unless match = %r{^a\s+(\d+)\s+(\d+)\s+([0-9.]+)\s*$}.match(line)
    source, dest, weight = match[1].to_i, match[2].to_i, match[3]
    line_error "Arc line seen before problem line" unless problem_node_count
    line_error "Source node is outside max node range (#{problem_node_count})" if source > problem_node_count
    line_error "Destination node is outside max node range (#{problem_node_count})" if dest > problem_node_count

    # add original arc line to output arc list (s -> d), with original weight w
    output_arc adjusted_source(source), adjusted_destination(dest), weight

    # Add source as a known augmented node. Do not add augmented source node
    # to the output node source list (because it is only a destination).
    augmented_node(source_as_augmented_node(source)) do
      # add a high-cost arc from source to augmented source: source -> source + n
      output_arc adjusted_source(source), source_as_augmented_node(source), unmatchable_cost
    end

    # If dest has not been mirrored as an augmented node yet, create a mirror-
    # image node for it.
    augmented_node(dest_as_augmented_node(dest)) do
      # add (dest) to the output source list
      output_node dest_as_augmented_node(dest)

      # add a high-cost arc from augmented node (dest) to original dest node (d + n)
      output_arc dest_as_augmented_node(dest), adjusted_destination(dest), unmatchable_cost
    end

    # add an arc from augmented source (dest+n) to augmented dest (source+n)
    output_arc dest_as_augmented_node(dest), source_as_augmented_node(source), weight
  end

  # Compute a node id for the "mirror image" node for an arc source in the
  # augmented graph.
  #
  # The computation is basically that this mirror image will be past all
  # sources, past all the mirror image nodes for original destinations, and past
  # all the original destination nodes. So, "node_id + problem_source_count +
  # 2 * destination count", but destination count is simply, "problem_node_count -
  # problem_source_count", and we simplify terms.
  def source_as_augmented_node(node_id)
    node_id + 2 * problem_node_count - problem_source_count
  end

  # Compute a node id for the "mirror image" node for an arc destination in the
  # augmented graph.
  #
  # The computation here is a no-op, since the offset of original destination nodes
  # from source nodes is exactly the offset of augmented destination nodes in
  # the augmented graph: because we are forced to list all sources contiguously.
  def dest_as_augmented_node(node_id)
    node_id
  end

  # Compute a new node id for a source node. Since our original source nodes
  # appear in the same order in the augmented graph, this is a no-op, and is
  # included here to improve readability of the calling code.
  def adjusted_source(node_id)
    node_id
  end

  # Compute a new node id for a destination node. This just offsets the original
  # destination node's node id by sufficient amount to account for keeping all
  # source nodes (original and augmented) contiguous in the output file.
  #
  # The computation is basically "how far into the original list of destination
  # nodes where you? (node_id - problem_source_count) offset by the size of the
  # augmented source list (which is has size: problem_source_count +
  # problem_destination count == problem_node_count)
  def adjusted_destination(node_id)
    node_id - problem_source_count + problem_node_count
  end

  # What do we output for a high cost node?
  #
  # TODO: this should be configurable by the caller
  def unmatchable_cost
    -1000000000
  end

  # Allow registering new "augmented nodes".
  #
  # If the provided `node_id` has already been seen as an augmented node, then do nothing;
  # otherwise, track that this is an augmented node, and also run the provided block.
  def augmented_node(node_id, &block)
    return if is_known_augmented_node? node_id
    register_seen_node node_id
    register_augmented_node node_id
    yield if block_given?
  end

  # Has this `node_id` been seen before, as an augmented node?
  def is_known_augmented_node?(node_id)
    known_augmented_nodes.has_key?(node_id)
  end

  # Mark that this `node_id` has been seen before as an augmented node.
  def register_augmented_node(node_id)
    known_augmented_nodes[node_id] = true
  end

  # Return the `Hash` of known augmented nodes.
  def known_augmented_nodes
    @known_augmented_nodes ||= {}
  end

  # Output an "arc line" to the arc output working file.
  def output_arc(source, dest, weight)
    register_seen_arc source, dest, weight
    arc_output_file.puts "a #{source} #{dest} #{weight}"
  end

  # Mark that we have seen a new arc.
  #
  # (Currently only tracks arc counts, but could track individual arcs.)
  def register_seen_arc(source, dest, weight)
    @seen_arcs ||= 0
    @seen_arcs += 1
  end

  # Return the file handle for the arc output working file.
  def arc_output_file
    @arc_output_file ||= File.open(arc_output_path, 'w')
  end

  # Return the location of the arc output working file (accumulated arc lines).
  def arc_output_path
    File.join(output_dir, "arc_output.txt")
  end

  # Verify that the fully processed graph input file is well-formed.
  #
  # Raises RuntimeError when graph file is found to be invalid.
  def validate_processed_file
    raise "No problem line found" unless seen_problem_line?
    raise "Seen node count [#{seen_nodes}] does not match computed [#{final_node_count}]" unless seen_nodes == final_node_count
    raise "Seen arc count [#{seen_arcs}] does not match computed [#{final_arc_count}]" unless seen_arcs == final_arc_count
  end

  # Close all open output files.
  def close_output_files
    problem_output_file.close
    node_output_file.close
    arc_output_file.close
  end

  # Merge working files into final augmented graph file.
  def merge_output_files
    @results_path = File.join(output_dir, "augmented_graph.txt")
    close_output_files
    system "cat #{problem_output_path} #{node_output_path} #{arc_output_path} > #{results_path}" # NOTE: not particularly portable
    message "Wrote augmented graph file: #{results_path}"
    results_path
  end
end
