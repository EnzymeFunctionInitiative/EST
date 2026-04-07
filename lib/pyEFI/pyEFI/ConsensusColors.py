
class ConsensusColors:
    """
    Python translation of Consensus::Colors.
    """
    def __init__(self, probs_arr, grey='#7a7a7a'):
        self.probs_arr = probs_arr
        self.grey = grey

    def color_map(self):
        thresholds = ['0.50', '0.60', '0.80', '0.85']

        # Amino acid groupings matching the Perl module
        hydro    = set('W L V I M A F C Y H P'.split()) # Hydrophobic
        polar    = set('Q N'.split())                   # Polar, non-alcohol
        positive = set('K R H'.split())                 # Basic
        alcohol  = set('S T'.split())                   # Polar, alcohol
        negative = set('E D'.split())                   # Acids

        cons = {t: [] for t in thresholds}

        for column in self.probs_arr:
            for t in thresholds:
                score = {}

                for aa_prob in column:
                    aa, prob_str = aa_prob.split(':', 1)
                    prob = float(prob_str)

                    score[aa] = score.get(aa, 0.0) + prob

                    # Following exact Perl flow-control (next/continue statements)
                    if aa in polar:
                        score['p'] = score.get('p', 0.0) + prob
                        continue

                    if aa in alcohol:
                        score['o'] = score.get('o', 0.0) + prob
                        continue

                    if aa in negative:
                        score['-'] = score.get('-', 0.0) + prob
                        continue

                    if aa in positive:
                        score['+'] = score.get('+', 0.0) + prob

                    if aa in hydro:
                        score['h'] = score.get('h', 0.0) + prob

                consensus_col = self._arbitrate(float(t), score)
                cons[t].append(consensus_col)

        colors = [{} for _ in range(len(self.probs_arr))]

        # Now based on the consensus assign a color per residue for that column
        for i in range(len(self.probs_arr)):
            self._D(i, cons, colors)
            self._R(i, cons, colors)
            self._Q(i, cons, colors)
            self._N(i, cons, colors)
            self._K(i, cons, colors)
            self._E(i, cons, colors)
            self._HY(i, cons, colors)
            self._ACFILMVW(i, cons, colors)
            self._ST(i, cons, colors)
            self._PG(i, cons, colors)

        return colors

    def _arbitrate(self, threshold, score_ref):
        bestclass = "."
        bestscore = 0.0

        class_size = {
            '.': 20,
            'h': 11,
            '+': 3,
            '-': 2,
            'o': 2,
            'p': 2
        }

        for cls, s in score_ref.items():
            if s >= threshold:
                a = class_size.get(cls, 1)
                b = class_size.get(bestclass, 1)

                # smaller set wins
                if a < b:
                    bestclass = cls
                    bestscore = s
                # sets are same size: look at score instead
                elif a == b:
                    if s > bestscore:
                        bestclass = cls
                        bestscore = s

        return bestclass

    # -------------------------------------------------------------------------------
    # Coloring Subroutines
    # -------------------------------------------------------------------------------
    def _HY(self, pos, consensuses, colors_ref):
        colors_ref[pos]['H'] = self.grey
        colors_ref[pos]['Y'] = self.grey

        cyan = '#99FFFF'
        if consensuses['0.60'][pos] == 'h':
            colors_ref[pos]['H'] = cyan
            colors_ref[pos]['Y'] = cyan
            return

        for aa in ['A', 'C', 'F', 'H', 'I', 'L', 'M', 'V', 'W', 'Y', 'P', 'Q', 'h']:
            if consensuses['0.85'][pos] == aa:
                colors_ref[pos]['H'] = cyan
                colors_ref[pos]['Y'] = cyan
                return

    def _ST(self, pos, consensuses, colors_ref):
        colors_ref[pos]['S'] = self.grey
        colors_ref[pos]['T'] = self.grey

        if consensuses['0.50'][pos] in ('a', 'S', 'T'):
            colors_ref[pos]['S'] = '#99FF99'
            colors_ref[pos]['T'] = '#99FF99'
            return

        for aa in ['A', 'C', 'F', 'H', 'I', 'L', 'M', 'V', 'W', 'Y', 'P', 'Q']:
            if consensuses['0.85'][pos] == aa:
                colors_ref[pos]['S'] = '#99FF99'
                colors_ref[pos]['T'] = '#99FF99'
                return

    def _ACFILMVW(self, pos, consensuses, colors_ref):
        aas = ['A', 'C', 'F', 'L', 'I', 'M', 'V', 'W']
        caas = ['A', 'C', 'F', 'H', 'I', 'L', 'M', 'V', 'W', 'Y', 'P', 'Q', 'h']

        for aa in aas:
            colors_ref[pos][aa] = self.grey
            if consensuses['0.60'][pos] in caas:
                colors_ref[pos][aa] = '#9999FF'

    def _D(self, pos, consensuses, colors_ref):
        colors_ref[pos]['D'] = self.grey
        red = '#FF9999'

        if consensuses['0.60'][pos] in ('+', 'R', 'K'):
            colors_ref[pos]['D'] = red
            return

        if consensuses['0.85'][pos] in ('D', 'E', 'N'):
            colors_ref[pos]['D'] = red
            return

        if consensuses['0.50'][pos] == '-' or consensuses['0.60'][pos] in ('E', 'D'):
            colors_ref[pos]['D'] = red
            return

    def _E(self, pos, consensuses, colors_ref):
        colors_ref[pos]['E'] = self.grey
        red = '#FF9999'

        if consensuses['0.60'][pos] in ('+', 'R', 'K'):
            colors_ref[pos]['E'] = red
            return

        if consensuses['0.85'][pos] in ('D', 'E'):
            colors_ref[pos]['E'] = red
            return

        if consensuses['0.50'][pos] in ('b', 'E', 'Q'):
            colors_ref[pos]['E'] = red
            return

    def _K(self, pos, consensuses, colors_ref):
        colors_ref[pos]['K'] = self.grey
        red = '#FF9999'

        if consensuses['0.60'][pos] in ('+', 'R', 'K'):
            colors_ref[pos]['K'] = red
            return

        if consensuses['0.85'][pos] in ('K', 'R', 'Q'):
            colors_ref[pos]['K'] = red
            return

    def _N(self, pos, consensuses, colors_ref):
        colors_ref[pos]['N'] = self.grey
        green = '#99FF99'

        if consensuses['0.50'][pos] == 'N':
            colors_ref[pos]['N'] = green
            return

        if consensuses['0.85'][pos] == 'D':
            colors_ref[pos]['N'] = green
            return

    def _Q(self, pos, consensuses, colors_ref):
        colors_ref[pos]['Q'] = self.grey
        green = '#99FF99'

        if consensuses['0.50'][pos] in ('b', 'E', 'Q'):
            colors_ref[pos]['Q'] = green
            return

        if consensuses['0.85'][pos] in ('Q', 'T', 'K', 'R'):
            colors_ref[pos]['Q'] = green
            return

        if consensuses['0.60'][pos] in ('+', 'K') or consensuses['0.50'][pos] == 'R':
            colors_ref[pos]['Q'] = green
            return

    def _R(self, pos, consensuses, colors_ref):
        colors_ref[pos]['R'] = self.grey
        red = '#FF9999'

        if consensuses['0.85'][pos] in ('Q', 'K', 'R'):
            colors_ref[pos]['R'] = red
            return

        if consensuses['0.60'][pos] in ('+', 'R', 'K'):
            colors_ref[pos]['R'] = red
            return

    def _PG(self, pos, consensuses, colors_ref):
        colors_ref[pos]['P'] = '#ffff11' # yellow
        colors_ref[pos]['G'] = '#ff7f11' # orange
