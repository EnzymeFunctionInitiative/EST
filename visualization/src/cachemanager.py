import os
from collections import namedtuple, OrderedDict
from typing import Any

Group = namedtuple("Group", ["edge_count", "cumulative_edge_count", "length_filename", "pident_filename"])

class CacheManager():
    """
    An on-disk append-only dictionary

    CacheManager uses the filesystem to store lists of values associated with a
    key. Every key added to the cache gets its own file. A limited number of file
    handles are maintained on a least-recently-used basis.
    """
    def __init__(self, cache_dir: str, max_filehandles=20, filehandle_dump_size=10):
        """
        An on-disk append-only dictionary

        Parameters:
        ---
            cache_dir (str) - directory in which cache files will be stored
            
            max_filehandles (int) - max number of filehandles to keep open at one time, 
                                    they will be reopened as needed
            
            filehandle_dump_size (int) - when too many filehandles are open, close this many
                                         before opening a new one. Must be less than 
                                         max_filehandles and should be higher for less randomized
                                         workloads
        """
        self.cache_dir = cache_dir
        self.filehandles = OrderedDict()
        self.edge_counts = {}
        self.max_filehandles = max_filehandles
        self._fh_dump_size = filehandle_dump_size

        self.LENGTH = "length"
        self.PERID = "pident"

        assert max_filehandles > filehandle_dump_size

    def __enter__(self):
        os.mkdir(self.cache_dir)
        return self

    def __exit__(self, exc_type, exc_value, traceback):
        for fh in self.filehandles.values():
            fh.close()

    def format_key(self, dataset: str, key: str) -> str:
        """
        provides consistent formatting for key values

        Parameters:
        ---
            dataset (str) - one of self.LENGTH or self.PERID
            
            key (int) - the integer alignment score used to group by

        Returns:
        ---
            A string key value to be used in self.filehandles
        """
        return f"{dataset}{key}"

    def append(self, alignment_score: int, alignment_length: int, percent_identical: float) -> None:
        """
        Append an alignment length and percent identical value to the cache at a particular alignment score

        Parameters:
        ----
            alignment_score (int) - the number that represents the group. Will be used as a key
            
            alignment_length (int) - a value that gets cached
            
            percent_identical (float) - a value that gets cached
        """
        self._append(self.LENGTH, alignment_score, alignment_length)
        self._append(self.PERID, alignment_score, percent_identical)
        self.edge_counts[alignment_score] = self.edge_counts.get(alignment_score, 0) + 1 

    def get_cache_filename(self, fkey: str) -> str:
        """
        Provides a consistent way to name cache files

        Parameters:
        ---
            fkey (str) - formatted key (from self.format_key)
        
        Returns:
        ---
            str path name for cache file
        """
        return os.path.join(self.cache_dir, fkey)

    def _append(self, dataset: str, key: int, value: Any) -> None:
        """
        Helper function for appending to cache

        Opens new files as needed, closes files when too many handles are open,
        writes data to files in a consistent format

        Parameters:
        ---
            dataset (str) - either self.LENGTH or self.PERID
            
            key (int) - alignment score used to group by
            
            value (any) - the alignment length or percent identical value
        """
        fkey = self.format_key(dataset, key)
        if fkey not in self.filehandles:
            if len(self.filehandles) + 1 >= self.max_filehandles:
                for _ in range(max(len(self.filehandles.keys()), self._fh_dump_size)):
                    _, fh = self.filehandles.popitem(last=False)
                    fh.close()

            fh = open(self.get_cache_filename(fkey), "a")
            self.filehandles[fkey] = fh
        
        fh = self.filehandles[fkey]
        fh.write(f"{value}\n")
        
    def _compute_cumulative_sum(self) -> dict[int, tuple[int, int]]:
        """
        Helper function that computes a cumulative summation of edge counts 
        
        Sums in reverse sorted order of keys, used to generate the evalue.tab output 
        file of (alignment score, edge count, cumlative, edge count sum). Lowest
        alignment_score will have highest cumulative sum.

        Returns:
        ---
            A dictionary of {alignment_score: (edge count, cumulative_edge_sum)}
        """
        cumsum = 0
        summed_edge_counts = {}
        for k in reversed(sorted(self.edge_counts.keys())):
            cumsum += self.edge_counts[k]
            summed_edge_counts[k] = cumsum
        return summed_edge_counts

    def get_edge_counts_and_filenames(self) -> dict[int, Group]:
        """
        Get dictionary of alignment scores and group-info, represents
        all of the data managed by the object

        Returns:
        ---
            A dict of {alignment_score: Group("edge_count", "cumulative_edge_count", "length_filename", "pident_filename")}
        """
        metadata = {}
        summed_edge_counts = self._compute_cumulative_sum()
        for k in self.edge_counts.keys():
            g = Group(edge_count=self.edge_counts[k],
                      cumulative_edge_count=summed_edge_counts[k],
                      length_filename=self.get_cache_filename(self.format_key(self.LENGTH, k)),
                      pident_filename=self.get_cache_filename(self.format_key(self.PERID, k))
                      )
            metadata[k] = g 
        return metadata
