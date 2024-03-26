import os
from collections import namedtuple, OrderedDict

Group = namedtuple("Group", ["edge_count", "length_filename", "perid_filename"])

class CacheManager():
    def __init__(self, cache_dir, max_filehandles=20, filehandle_dump_size=10):
        self.cache_dir = cache_dir
        self.filehandles = OrderedDict()
        self.edge_counts = {}
        self.max_filehandles = max_filehandles
        self._fh_dump_size = filehandle_dump_size

        self.LENGTH = "length"
        self.PERID = "perid"

        assert max_filehandles > filehandle_dump_size

    def __enter__(self):
        os.mkdir(self.cache_dir)
        return self

    def __exit__(self, exc_type, exc_value, traceback):
        for fh in self.filehandles.values():
            fh.close()

    def format_key(self, dataset, key):
        return f"{dataset}{key}"

    def append(self, alignment_score, alignment_length, percent_identical):
        self._append(self.LENGTH, alignment_score, alignment_length)
        self._append(self.PERID, alignment_score, percent_identical)
        self.edge_counts[alignment_score] = self.edge_counts.get(alignment_score, 0) + 1 

    def get_cache_filename(self, fkey):
        return os.path.join(self.cache_dir, fkey)

    def _append(self, dataset, key, value):
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
        
    def _compute_cumulative_sum(self):
        cumsum = 0
        summed_edge_counts = {}
        for k in reversed(sorted(self.edge_counts.keys())):
            cumsum += self.edge_counts[k]
            summed_edge_counts[k] = (self.edge_counts[k], cumsum)
        return summed_edge_counts

    def save_edge_counts(self, filename):
        summed_edge_counts = self._compute_cumulative_sum()
        with open(filename, "w+") as f:
            for k, t in sorted(summed_edge_counts.items()):
                f.write(f"{k}\t{t[0]}\t{t[1]}\n")

    def get_edge_counts_and_filenames(self):
        metadata = {}
        for k in self.edge_counts.keys():
            g = Group(edge_count=self.edge_counts[k],
                      length_filename=self.get_cache_filename(self.format_key(self.LENGTH, k)),
                      perid_filename=self.get_cache_filename(self.format_key(self.PERID, k))
                      )
            metadata[k] = g 
        return metadata
