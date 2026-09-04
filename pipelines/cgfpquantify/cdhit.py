
class CdHitParser:
    """
    Utility class for parsing CD-HIT files and returning a mapping of cluster ID
    to IDs in the cluster.
    """

    def __init__(self, cdhit_cluster_file):
        """
        Create an object

        Parameters
        ----------
            cdhit_cluster_file
                path to a file containing CD-HIT cluster results (e.g. .clstr)
        """
        # Get CD-HIT cluster data
        self.cdhit_clusters = self.parse_file(cdhit_cluster_file)

    def parse_file(self, cdhit_file: str) -> dict:
        """
        Parses a CD-HIT file and returns a dictionary of CD-HIT clusters.
        
        An example of a CD-HIT file:
    
            >Cluster 268
            0       146aa, >A0A6M4JL07... *
            1       146aa, >A0A8E0SEA1... at 100.00%
            2       146aa, >A0AAE2VGX6... at 100.00%
            3       146aa, >A0AAP5KZA6... at 100.00%
            4       146aa, >P45945... at 100.00%
            >Cluster 270
            0       146aa, >A0A9Q4HJ08... *
            1       146aa, >A0AAP3CN64... at 100.00%
    
        This will result in the following entry in the output dictionary:
    
            {'Cluster 268': ['A0A6M4JL07', 'A0A8E0SEA1', 'A0AAE2VGX6', 'A0AAP5KZA6', 'P45945'],
             'Cluster 270': ['A0A9Q4HJ08', 'A0AAP3CN64']}
    
        Parameters
        ----------
            cdhit_file
                path to a CD-HIT .clstr file
    
        Returns
        -------
            dict mapping CD-HIT clusters to members of the cluster
        """
    
        # Read CD-HIT clusters from file
        clusters = {}
        cluster_id = ""
        with open(cdhit_file, 'r') as f:
            for line in f:
                line = line.strip()
                if line.startswith('>'):
                    # Extract cluster ID
                    cluster_id = line[1:]
                    clusters[cluster_id] = []
                else:
                    m = re.search(r'^.+>(.+)\.\.\.$', line)
                    if m:
                        sequence_id = m.group(1)
                        #pct = m.group(2)
                        #md = re.search(r'at ([\d\.]+)\%', pct)
                        #if md:
                        #    pct = md.group(1)
                        #else:
                        #    pct = ""
                        clusters[cluster_id].append(sequence_id)
    
        return clusters

    def get_first_members(self) -> list:
        """
        Return the first member of every cluster in the CD-HIT results.   It can
        be used to get the list of unique sequences in a FASTA file that was
        analyzed by CD-HIT.  For the example given in
        :func:`~cdhit.CdHitParser.parse_file`, this function returns:

            ['A0A6M4JL07', 'A0A9Q4HJ08']

        Returns
        -------
            list of sequence identifiers
        """
        ids = {members[0] for cluster_id, members in self.cdhit_clusters.items()}
        return ids

    def get_cluster_ids(self) -> list:
        """
        Return the CD-HIT cluster IDs (e.g. the ID values in the lines that
        start with '>'.  For the example given in
        :func:`~cdhit.CdHitParser.parse_file`, this function returns:

            ['Cluster 268', 'Cluster 270']

        Returns
        -------
            list of cluster IDs
        """
        ids = {cluster_id for cluster_id, members in self.cdhit_clusters.items()}
        return ids

