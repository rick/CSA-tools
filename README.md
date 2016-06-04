## CSA tools

This is a set of supplementary tools for use with [Andrew Goldberg's CSA](https://github.com/rick/CSA) weighted bipartite matching solver.

Included here are the following:

 - [generate_matching](https://github.com/rick/CSA-tools/blob/master/bin/generate_matching) - The main driver script. Take a [DIMACS-format](https://github.com/rick/CSA-tools/blob/master/docs/dimacs_file_format.pdf) graph file containing a weighted bipartite graph, augment the graph, run the CSA solver, and deaugment the resulting matching. I.e., solve a matching, doing whatever you have to do behind the scenes.

 - [generate_augmented_graph](https://github.com/rick/CSA-tools/blob/master/bin/generate_augmented_graph) - command-line tooling to take a weighted bipartite graph, contained in a Dimacs-format graph file, and produce an augmented graph in another Dimacs-formatted graph file. The augmented graph is guaranteed to have a perfect matching.

 - [deaugment_matching](https://github.com/rick/CSA-tools/blob/master/bin/convert_matching_to_original_graph) - command-line tooling to take a CSA matching on an augmented graph and convert that matching to the analogous matching on the original (unaugmented) graph.

### Perfect Matchings

CSA presumes that the graph provided as input contains a perfect matching. If no such matching exists the solver will either not terminate, or can produce a non-optimal matching. (There are notes in the code to the effect that it would be possible to modify the solver to deal with this case, but that work was apparently never undertaken)

In conversations with Andrew V. Golberg, he provided an algorithm for converting a bipartite graph which might not have a perfect matching into a graph which will have a perfect matching, and from which a solution to the perfect assignment problem on the augmented graph can be transformed into a maximum cardinality minimum cost matching on the original graph.

The algorithm is as follows.

Given a weighted bipartite graph `G`, with `n` vertices and `m` weighted edges, construct an augmented graph `G'` with `2n` vertices and `2m+n` edges:

 - Take the vertices and edges of the original graph `G`, and add a flipped copy of `G`: vertices on the left side copied to the right side, and vice versa. Copy the edges with weights.
 - Add high-cost edges between each original node and its flipped copy.

An illustration may help:

![](docs/images/augmented-matching.png?raw=true)

From the matching on the augmented graph, we can take those original nodes from `G` which matched with other original nodes from `G` as the desired matching. Note that nodes from `G` which matched via high-cost edges (necessarily with their complement nodes in the flipped graph) are unmatched nodes in the solution.
