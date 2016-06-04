class MatchingTranslator
  attr_reader :source_nodes, :total_nodes, :input_file, :output_file, :silent

  def initialize(source_nodes, total_nodes, input_file, output_file, silent = false)
    @source_nodes = source_nodes
    @total_nodes  = total_nodes
    @input_file   = input_file
    @output_file  = output_file
    @silent       = silent
  end

  def self.process(source_nodes, total_nodes, input_file, output_file, silent = false)
    new(source_nodes, total_nodes, input_file, output_file, silent).process
  end

  def process
    message "Processing matching file [#{input_file}]. Original problem had #{source_nodes} source nodes and #{total_nodes} total nodes..."
    File.open(input_file) do |infile|
      infile.each_line do |line|
        if line =~ /^f\s+(\d+)\s+(\d+)\s+(-?\d+)/
          source, destination, weight = $1.to_i, $2.to_i, $3.to_i

          if is_valid_match?(source, destination, weight)
            output_flow_arc(source, destination, weight)
          else
            message "Discarding match [#{source}, #{destination}, #{weight}]"
          end
        else
          message "Skipping line: [#{line.chomp}]"
        end
      end
    end
    close_output_files
  end

  def message(message)
    puts message unless silent
  end

  def output_flow_arc(source, destination, weight)
    new_source, new_destination, new_weight = translate_flow_arc(source, destination, weight)
    message "Keeping match [#{source}, #{destination}, #{weight}] -> [#{new_source}, #{new_destination}, #{new_weight}]"
    output_handle.puts "f #{source} #{destination} #{weight}"
  end

  # Return the file handle for the problem output working file.
  def output_handle
    @output_handle ||= File.open(output_file, 'w')
  end

  def is_valid_match?(source, destination, weight)
    source >= first_augmented_source_node &&
      source <= last_augmented_source_node &&
      destination >= first_augmented_destination_node &&
      destination <= last_augmented_destination_node
  end

  def translate_flow_arc(source, destination, weight)
    [ source, destination - total_nodes + source_nodes, weight]
  end

  def first_augmented_source_node
    1
  end

  def last_augmented_source_node
    source_nodes
  end

  def first_augmented_destination_node
    total_nodes + 1
  end

  def last_augmented_destination_node
    total_nodes + destination_nodes
  end

  def destination_nodes
    total_nodes - source_nodes
  end

  def close_output_files
    output_handle.close
  end
end
