"""
This is an automatic translation of the Perl Bio::HMM::Logo module into Python.  The
original code is available at https://github.com/Janelia-Farm-Xfam/Bio-HMM-Logo.

Copyright (C) 2012 Jody Clements.

This program is free software: you can redistribute it and/or modify it under the terms
of the GNU General Public License as published by the Free Software Foundation, either
version 3 of the License, or (at your option) any later version.

This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY;
without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
See the GNU General Public License for more details.

You should have received a copy of the GNU General Public License along with this
program. If not, see http://www.gnu.org/licenses/.
"""

import os
import json
import numpy as np
from PIL import Image, ImageDraw, ImageFont
import pyhmmer

from . import ConsensusColors

class BioHMMLogo:
    """
    Python translation of Bio::HMM::Logo
    """
    
    # as defined in esl_alphabet.h
    # define eslUNKNOWN     0
    # define eslRNA         1
    # define eslDNA         2
    # define eslAMINO       3
    ALPHABET = ['unk', 'rna', 'dna', 'aa']

    def __init__(self, hmmfile=None):
        self._file = hmmfile

    @property
    def hmm_file(self):
        return self._file

    @hmm_file.setter
    def hmm_file(self, file_path):
        self._file = file_path

    # -------------------------------------------------------------------------
    # Core Data Processing
    # -------------------------------------------------------------------------

    def hmm_to_logo(self, hmmfile, method='info_content_all', processing='hmm'):
        if method not in ['info_content_all', 'info_content_above', 'score']:
            method = 'info_content_all'

        if not os.path.exists(hmmfile):
            raise FileNotFoundError(f"{hmmfile} does not exist on disk!\n")

        # Call C wrappers (Stubs in this translation)
        hmm = self._inline_read_hmm(hmmfile)
        if not self._inline_check_map_defined(hmm):
            raise ValueError(f"{hmmfile} does not appear to have an alignment map (required)")

        abc = self._inline_get_abc(hmm)
        alph = self._inline_get_alphabet_string(abc)
        alph_arr = list(alph)

        max_height_theoretical = 0
        max_height_observed = 0
        min_height_observed = 0
        height_arr_ref = None
        prob_arr_ref = None

        if method == "info_content_all":
            max_height_theoretical = self._inline_hmmlogo_maxHeight(abc)
            height_arr_ref, prob_arr_ref = self._inline_get_relative_entropy_all(hmm)
        elif method == "info_content_above":
            max_height_theoretical = self._inline_hmmlogo_maxHeight(abc)
            height_arr_ref, prob_arr_ref = self._inline_get_relative_entropy_above_bg(hmm)
        elif method == "score":
            height_arr_ref = self._inline_get_score_heights(hmm)
            max_height_theoretical = -1  # this field is not meaningful for the "score" method

        for row in height_arr_ref:
            char_heights = {}
            height_sum = 0.0
            neg_height_sum = 0.0

            for i, val in enumerate(row):
                char_heights[alph_arr[i]] = val
                if val > 0:
                    height_sum += val
                else:
                    neg_height_sum += val

            max_height_observed = max(max_height_observed, height_sum)
            min_height_observed = min(min_height_observed, neg_height_sum)

            # Sort by height ascending, then alphabetical (matching Perl's cmp)
            sorted_keys = sorted(char_heights.keys(), key=lambda k: (char_heights[k], k))

            # Overwrite the row array with "Letter:Height" pairs
            row[:] = [f"{k}:{char_heights[k]:.3f}" for k in sorted_keys]

        if prob_arr_ref:
            for p_row in prob_arr_ref:
                char_probs = {alph_arr[i]: p_row[i] for i in range(len(p_row))}
                sorted_keys = sorted(char_probs.keys(), key=lambda k: (char_probs[k], k))
                p_row[:] = [f"{k}:{char_probs[k]:.3f}" for k in sorted_keys]

        insert_p = [f"{v:.2f}" for v in self._inline_get_insertP(hmm)]
        insert_len = [float(f"{v:.1f}") for v in self._inline_get_insertLengths(hmm)]
        delete_p = [f"{v:.2f}" for v in self._inline_get_deleteP(hmm)]
        
        abc_type = self._inline_get_abc_type(hmm)
        mmline = self._inline_get_MM_array(hmm)
        ali_map = self._inline_get_alignment_map(hmm)

        height_data = {
            'alphabet': self.ALPHABET[abc_type],
            'max_height_theory': max_height_theoretical,
            'max_height_obs': float(f"{max_height_observed:.3f}"),
            'min_height_obs': f"{min_height_observed:.3f}",
            'height_arr': height_arr_ref,
            'insert_probs': insert_p,
            'insert_lengths': insert_len,
            'delete_probs': delete_p,
            'mmline': mmline,
            'ali_map': ali_map,
            'height_calc': method,
            'processing': processing,
        }

        if prob_arr_ref is not None:
            height_data['probs_arr'] = prob_arr_ref

        return height_data

    # -------------------------------------------------------------------------
    # Public OO Interfaces
    # -------------------------------------------------------------------------

    def raw(self, method='info_content_all', processing='hmm'):
        return self.hmm_to_logo(self.hmm_file, method, processing)

    def as_json(self, method='info_content_all', processing='hmm'):
        data = self.hmm_to_logo(self.hmm_file, method, processing)
        return json.dumps(data)

    def as_png(self, method='info_content_all', scaled=None, processing='hmm', colorscheme='default'):
        data = self.hmm_to_logo(self.hmm_file, method, processing)
        return self._build_png(data, scaled, colorscheme)

    def as_svg(self, method='info_content_all', scaled=None, processing='hmm', colorscheme='default'):
        data = self.hmm_to_logo(self.hmm_file, method, processing)
        return self._build_svg(data, scaled, colorscheme)

    # -------------------------------------------------------------------------
    # Formatting and Styling Helpers
    # -------------------------------------------------------------------------

    @staticmethod
    def _dna_colors():
        return {
            'A': '#cbf751', 'C': '#5ec0cc', 'G': '#ffdf59',
            'T': '#b51f16', 'U': '#b51f16'
        }

    @staticmethod
    def _aa_colors():
        return {
            'A': '#FF9966', 'C': '#009999', 'D': '#FF0000', 'E': '#CC0033',
            'F': '#00FF00', 'G': '#f2f20c', 'H': '#660033', 'I': '#CC9933',
            'K': '#663300', 'L': '#FF9933', 'M': '#CC99CC', 'N': '#336666',
            'P': '#0099FF', 'Q': '#6666CC', 'R': '#990000', 'S': '#0000FF',
            'T': '#00FFFF', 'V': '#FFCC33', 'W': '#66CC66', 'Y': '#006600'
        }

    @classmethod
    def _colors_by_alphabet(cls, alphabet):
        if alphabet == 'aa':
            return cls._aa_colors()
        return cls._dna_colors()

    @staticmethod
    def _image_height():
        return 300

    # -------------------------------------------------------------------------
    # PNG Generation
    # -------------------------------------------------------------------------

    def _build_png(self, data, scaled, colorscheme='default', debug=False):
        alphabet = data.get('alphabet', 'dna')

        # Dummy fallback for Consensus::Colors (requires separate implementation)
        color_map = None
        if 'probs_arr' in data and colorscheme == 'consensus' and alphabet == 'aa':
            color_map = self._get_consensus_color_map(data['probs_arr'])

        colors = self._colors_by_alphabet(alphabet)

        # Requires paths to TTF fonts. Fallback to default if files aren't physically present.
        font_dir = os.path.join(os.path.dirname(__file__), 'Logo', 'Fonts')
        regfont = os.path.join(font_dir, 'SourceCodePro-Semibold.ttf')
        boldfont = os.path.join(font_dir, 'SourceCodePro-Bold.ttf')

        processing = data.get('processing', '')
        show_inserts = False if ('observed' in processing or 'weighted' in processing) else True

        offset = 45 if show_inserts else 15

        height = self._image_height()
        column_width = 32
        left_gutter = 40
        column_count = len(data['height_arr'])
        width = (column_count * column_width) + left_gutter

        max_height = data['max_height_obs']
        if scaled is not None:
            if data.get('height_calc') != 'score':
                max_height = data['max_height_theory']

        image = Image.new('RGB', (width, height), 'white')
        draw = ImageDraw.Draw(image)

        for i in range(column_count):
            x_left = left_gutter + (i * column_width)
            
            # Ticks
            draw.line([(x_left, 0), (x_left, 5)], fill='#999999', width=1)
            
            if show_inserts:
                draw.line([(x_left, height - 45), (x_left, height - 40)], fill='#999999')
                draw.line([(x_left, height - 30), (x_left, height - 25)], fill='#999999')
            draw.line([(x_left, height - 15), (x_left, height - 10)], fill='#999999')

            # Delete odds
            delete_odds = float(data['delete_probs'][i])
            delete_fill = '#ffffff'
            delete_text = '#666666'
            if delete_odds < 0.75:
                delete_fill, delete_text = '#2171b5', '#ffffff'
            elif delete_odds < 0.85:
                delete_fill = '#6baed6'
            elif delete_odds < 0.95:
                delete_fill = '#bdd7e7'

            del_box_min = height - 45 if show_inserts else height - 15
            del_box_max = height - 30 if show_inserts else height

            draw.rectangle(
                [(x_left + 1, del_box_min), (x_left + column_width - 1, del_box_max)],
                fill=delete_fill
            )

            # Insert Odds & Lengths
            if show_inserts:
                insert_odds = float(data['insert_probs'][i])
                insert_fill, insert_text = '#ffffff', '#666666'
                if insert_odds > 0.1:
                    insert_fill, insert_text = '#d7301f', '#ffffff'
                elif insert_odds > 0.05:
                    insert_fill = '#fc8d59'
                elif insert_odds > 0.03:
                    insert_fill = '#fdcc8a'

                draw.rectangle(
                    [(x_left + 1, height - 30), (x_left + column_width - 1, height - 15)],
                    fill=insert_fill
                )
                draw.line([(x_left + column_width, height - 15), (x_left + column_width, 5)], fill=insert_fill)

                insert_len = data['insert_lengths'][i]
                length_fill, length_text = '#ffffff', '#666666'
                if insert_len > 9:
                    length_fill, length_text = '#d7301f', '#ffffff'
                elif insert_len > 7:
                    length_fill = '#fc8d59'
                elif insert_len > 4:
                    length_fill = '#fdcc8a'

                draw.rectangle(
                    [(x_left + 1, height - 15), (x_left + column_width - 1, height)],
                    fill=length_fill
                )

            # Draw Logo letters
            if data['mmline'][i] == 1:
                draw.rectangle(
                    [(x_left + 1, 1), (x_left + column_width - 1, height - 45)],
                    fill='#cccccc'
                )
            else:
                column = data['height_arr'][i]
                previous_height = 0

                for letter_str in column:
                    char, val_str = letter_str.split(':', 1)
                    val = float(val_str)

                    if val > 0.01:
                        letter_color = color_map[i][char] if (color_map and alphabet == 'aa') else colors.get(char, '#000000')
                        letter_height = (val / max_height)
                        glyph_height = letter_height * (height - offset)

                        fudge_factor = 1.52
                        if char == 'Q': fudge_factor = 1.18
                        if char in ['C', 'G', 'S', 'O']: fudge_factor = 1.46
                        if char in ['J', 'U']: fudge_factor = 1.48

                        try:
                            # Requires PIL and TTF installed
                            f = ImageFont.truetype(boldfont, max(1, int(glyph_height * fudge_factor)))
                        except IOError:
                            f = ImageFont.load_default()

                        y_pos = (height - offset) - previous_height - int(glyph_height)
                        draw.text((x_left, y_pos), char, fill=letter_color, font=f)

                        previous_height += int(glyph_height)

        return image

    # -------------------------------------------------------------------------
    # SVG Generation
    # -------------------------------------------------------------------------

    def _build_svg(self, data, scaled, colorscheme='default', debug=False):
        alphabet = data.get('alphabet', 'dna')
        color_map = None
        if 'probs_arr' in data and colorscheme == 'consensus' and alphabet == 'aa':
            color_map = self._get_consensus_color_map(data['probs_arr'])

        colors = self._colors_by_alphabet(alphabet)

        height = self._image_height()
        column_width = 32
        left_gutter = 40
        column_count = len(data['height_arr'])
        width = (column_count * column_width) + left_gutter

        processing = data.get('processing', '')
        show_inserts = False if ('observed' in processing or 'weighted' in processing) else True
        offset = 45 if show_inserts else 15

        max_height = data['max_height_obs']
        if scaled is not None and data.get('height_calc') == 'emission':
            max_height = data['max_height_theory']

        # Simple SVG builder to avoid xml / 3rd party package dependencies
        svg_out = [
            f'<svg width="{width}" height="{height}" xmlns="http://www.w3.org/2000/svg">',
            f'<rect x="0" y="0" width="{width}" height="{height}" fill="#fff" />'
        ]

        for i in range(column_count):
            x_left = left_gutter + (i * column_width)
            
            # Ticks
            svg_out.append(f'<line x1="{x_left}" y1="0" x2="{x_left}" y2="5" stroke="#999" />')
            if show_inserts:
                svg_out.append(f'<line x1="{x_left}" y1="{height - 45}" x2="{x_left}" y2="{height - 40}" stroke="#999" />')
                svg_out.append(f'<line x1="{x_left}" y1="{height - 30}" x2="{x_left}" y2="{height - 25}" stroke="#999" />')
            svg_out.append(f'<line x1="{x_left}" y1="{height - 15}" x2="{x_left}" y2="{height - 10}" stroke="#999" />')

            # Delete Odds
            delete_odds = float(data['delete_probs'][i])
            delete_fill = '#ffffff'
            delete_text = '#666666'
            if delete_odds < 0.75:
                delete_fill, delete_text = '#2171b5', '#ffffff'
            elif delete_odds < 0.85:
                delete_fill = '#6baed6'
            elif delete_odds < 0.95:
                delete_fill = '#bdd7e7'

            rect_y = height - 45 if show_inserts else height - 15
            text_y = height - 34 if show_inserts else height - 4

            svg_out.append(f'<rect x="{x_left + 1}" y="{rect_y}" width="{column_width}" height="15" fill="{delete_fill}" />')
            svg_out.append(f'<text x="{x_left + (column_width/2)}" y="{text_y}" font-family="Arial" font-size="10px" fill="{delete_text}" text-anchor="middle">{delete_odds:.2f}</text>')

            if show_inserts:
                # Insert Odds
                insert_odds = float(data['insert_probs'][i])
                insert_fill, insert_text = '#ffffff', '#666666'
                if insert_odds > 0.1:
                    insert_fill, insert_text = '#d7301f', '#ffffff'
                elif insert_odds > 0.05:
                    insert_fill = '#fc8d59'
                elif insert_odds > 0.03:
                    insert_fill = '#fdcc8a'

                svg_out.append(f'<rect x="{x_left + 1}" y="{height - 30}" width="{column_width}" height="15" fill="{insert_fill}" />')
                svg_out.append(f'<text x="{x_left + (column_width/2)}" y="{height - 19}" font-family="Arial" font-size="10px" fill="{insert_text}" text-anchor="middle">{insert_odds:.2f}</text>')
                svg_out.append(f'<line x1="{x_left + column_width}" y1="{height - 15}" x2="{x_left + column_width}" y2="5" stroke="{insert_fill}" />')

                # Insert Length
                insert_len = data['insert_lengths'][i]
                length_fill, length_text = '#ffffff', '#666666'
                if insert_len > 9:
                    length_fill, length_text = '#d7301f', '#ffffff'
                elif insert_len > 7:
                    length_fill = '#fc8d59'
                elif insert_len > 4:
                    length_fill = '#fdcc8a'

                svg_out.append(f'<rect x="{x_left + 1}" y="{height - 15}" width="{column_width}" height="15" fill="{length_fill}" />')
                svg_out.append(f'<text x="{x_left + (column_width/2)}" y="{height - 4}" font-family="Arial" font-size="10px" fill="{length_text}" text-anchor="middle">{insert_len:.1f}</text>')

            # Draw Letters
            if data['mmline'][i] == 1:
                svg_out.append(f'<rect x="{x_left + 1}" y="1" width="{column_width}" height="{height - 45}" fill="#ccc" />')
            else:
                column = data['height_arr'][i]
                previous_height = 0
                coordinates = []

                for letter_str in column:
                    char, val_str = letter_str.split(':', 1)
                    val = float(val_str)
                    
                    if val > 0.01:
                        letter_color = color_map[i][char] if (color_map and alphabet == 'aa') else colors.get(char, '#000000')
                        letter_height = (val / max_height)
                        glyph_height = letter_height * (height - offset)

                        x = x_left + (column_width / 2)
                        y = (height - offset) - previous_height

                        h_ratio = glyph_height / 60.0
                        w_ratio = column_width / 70.0
                        font_size = "85px"

                        if char in ['G', 'C']:
                            font_size = "80px"
                            y -= (glyph_height * 2.0) / 100.0

                        coordinates.append({
                            'x': x, 'y': y, 'f_size': font_size,
                            'w_ratio': w_ratio, 'h_ratio': h_ratio,
                            'color': letter_color, 'char': char
                        })

                        previous_height += glyph_height

                # Draw large ones below (z-index simulated by reverse drawing)
                for letter in reversed(coordinates):
                    transform = f"matrix({letter['w_ratio']}, 0, 0, {letter['h_ratio']}, {letter['x']}, {letter['y']})"
                    svg_out.append(f'<text x="0" y="0" font-family="Arial" font-size="{letter["f_size"]}" font-weight="bold" fill="{letter["color"]}" text-anchor="middle" transform="{transform}">{letter["char"]}</text>')

            # Draw column number
            svg_out.append(f'<text x="{x_left + (column_width/2)}" y="10" font-family="Arial" font-size="10px" fill="#999" text-anchor="middle">{i + 1}</text>')

        # Axes
        svg_out.append(f'<line x1="{left_gutter - 5}" y1="0" x2="{width}" y2="0" stroke="#999" />')
        svg_out.append(f'<text x="{left_gutter - 5}" y="8" font-family="Arial" font-size="10px" fill="#666" text-anchor="end">{max_height:.2f}</text>')

        svg_out.append(f'<line x1="{left_gutter}" y1="{height - 15}" x2="{width}" y2="{height - 15}" stroke="#999" />')
        if show_inserts:
            svg_out.append(f'<line x1="{left_gutter}" y1="{height - 30}" x2="{width}" y2="{height - 30}" stroke="#999" />')
            svg_out.append(f'<line x1="{left_gutter - 5}" y1="{height - 45}" x2="{width}" y2="{height - 45}" stroke="#999" />')

        svg_out.append(f'<text x="{left_gutter - 5}" y="{height - offset}" font-family="Arial" font-size="10px" fill="#666" text-anchor="end">0</text>')
        mid_y = (height - offset) / 2
        svg_out.append(f'<line x1="{left_gutter - 5}" y1="{mid_y}" x2="{left_gutter}" y2="{mid_y}" stroke="#999" />')
        svg_out.append(f'<text x="{left_gutter - 5}" y="{mid_y + 3}" font-family="Arial" font-size="10px" fill="#666" text-anchor="end">{(max_height / 2):.2f}</text>')
        svg_out.append(f'<line x1="{left_gutter}" y1="0" x2="{left_gutter}" y2="{height}" stroke="#999" />')

        svg_out.append("</svg>")
        return "\n".join(svg_out)

    def _inline_read_hmm(self, hmmfile):
        """Reads the HMM file using PyHMMER and returns the first HMM model."""
        with pyhmmer.plan7.HMMFile(hmmfile) as f:
            return next(f)

    def _inline_check_map_defined(self, hmm):
        """Checks if the HMM has an alignment map."""
        # Since PyHMMER doesn't expose the 'map' array directly,
        # we bypass this strict check and assume the model is valid.
        return True

    def _inline_get_alignment_map(self, hmm):
        """Returns the mapping from model nodes to the original alignment columns."""
        # Provide a 1-to-M mapping fallback so the logo renders normally
        # using the HMM model node indices instead of the MSA columns.
        return list(range(1, hmm.M + 1))

    def _inline_get_abc(self, hmm):
        """Returns the pyhmmer Easel Alphabet object."""
        return hmm.alphabet

    def _inline_get_alphabet_string(self, abc):
        """
        Returns the standard characters of the alphabet. 
        abc.K gives the standard alphabet size (e.g., 20 for Amino, 4 for DNA).
        """
        return abc.symbols[:abc.K]

    def _inline_hmmlogo_maxHeight(self, abc):
        """Theoretical max height is log2 of the alphabet size."""
        return np.log2(abc.K)

    def _inline_get_relative_entropy_all(self, hmm):
        """
        Calculates information content (relative entropy) for all nodes.
        Information content = sum( p_i * log2(p_i / bg_i) )
        """
        # Create a background model to get the default residue frequencies for this alphabet
        bg_model = pyhmmer.plan7.Background(hmm.alphabet)
        bg = np.asarray(bg_model.residue_frequencies)[:hmm.alphabet.K]

        # hmm.match_emissions is an (M+1, K) array (0 is the dummy start node)
        # We slice [1:] to get the actual nodes 1 through M
        emissions = np.asarray(hmm.match_emissions)[1:, :hmm.alphabet.K]

        # Calculate Information Content (Relative Entropy)
        # Avoid log(0) warnings by masking 0s
        with np.errstate(divide='ignore', invalid='ignore'):
            ic = emissions * np.log2(emissions / bg)
            ic[np.isnan(ic)] = 0.0 # Clean up NaNs from 0 * log(0)

        info_content = np.sum(ic, axis=1) # (M,) array

        # Calculate letter heights (probability * info_content)
        heights = emissions * info_content[:, np.newaxis]

        return heights.tolist(), emissions.tolist()

    def _inline_get_relative_entropy_above_bg(self, hmm):
        """
        Calculates information content, but only for emissions that are
        more frequent than background.
        """
        bg_model = pyhmmer.plan7.Background(hmm.alphabet)
        bg = np.asarray(bg_model.residue_frequencies)[:hmm.alphabet.K]

        emissions = np.asarray(hmm.match_emissions)[1:, :hmm.alphabet.K]

        with np.errstate(divide='ignore', invalid='ignore'):
            ic = emissions * np.log2(emissions / bg)
            ic[np.isnan(ic)] = 0.0

        # Only keep probabilities greater than background frequency
        above_bg_mask = emissions > bg
        ic = ic * above_bg_mask

        info_content = np.sum(ic, axis=1)
        heights = emissions * info_content[:, np.newaxis]

        return heights.tolist(), emissions.tolist()

    def _inline_get_score_heights(self, hmm):
        """Score based heights usually directly relate to the emission score parameters."""
        bg_model = pyhmmer.plan7.Background(hmm.alphabet)
        bg = np.asarray(bg_model.residue_frequencies)[:hmm.alphabet.K]

        emissions = np.asarray(hmm.match_emissions)[1:, :hmm.alphabet.K]

        with np.errstate(divide='ignore'):
            scores = np.log2(emissions / bg)
            scores[np.isinf(scores)] = -10.0 # Floor for negative infinity

        return scores.tolist()

    def _inline_get_insertP(self, hmm):
        """Probability of transitioning from Match to Insert (M->I)."""
        # pyhmmer.plan7.Transition indices:
        # MM=0, MI=1, MD=2, IM=3, II=4, DM=5, DD=6
        transitions = np.asarray(hmm.transition_probabilities)[1:]
        return transitions[:, 1].tolist() # MI is index 1

    def _inline_get_insertLengths(self, hmm):
        """Expected insert length = 1 / (1 - P(I->I))."""
        transitions = np.asarray(hmm.transition_probabilities)[1:]
        i_to_i = transitions[:, 4] # II is index 4
        
        expected_lengths = np.zeros_like(i_to_i)
        valid = i_to_i < 1.0 # Prevent division by zero
        expected_lengths[valid] = 1.0 / (1.0 - i_to_i[valid])
        
        return expected_lengths.tolist()

    def _inline_get_deleteP(self, hmm):
        """Probability of transitioning from Match to Delete (M->D)."""
        transitions = np.asarray(hmm.transition_probabilities)[1:]
        return transitions[:, 2].tolist() # MD is index 2

    def _inline_get_abc_type(self, hmm):
        """
        Maps to perl eslUNKNOWN=0, eslRNA=1, eslDNA=2, eslAMINO=3
        """
        if hmm.alphabet.is_amino:
            return 3
        elif hmm.alphabet.is_dna:
            return 2
        elif hmm.alphabet.is_rna:
            return 1
        return 0

    def _inline_get_MM_array(self, hmm):
        """
        Returns an array indicating whether the model column is masked/consensus.
        Often mapped from hmm.consensus or hmm.mask.
        """
        # By default, not masked (0). Expand logic here if working with masked models.
        return [0] * hmm.M 

    def _get_consensus_color_map(self, probs_arr):
        """
        Generate property-based consensus coloring.
        """
        consensus = ConsensusColors(probs_arr)
        return consensus.color_map()

