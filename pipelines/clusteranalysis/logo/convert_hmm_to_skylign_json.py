
import argparse
import json
import math
import numpy as np
import pyhmmer

def convert_hmm_to_skylign_json(hmm_path, output_json_path):
    """
    Parses an HMM, calculates Information Content (Skylign style),
    and saves the letter heights to a JSON file.
    """
    
    # 1. Load the HMM
    try:
        with pyhmmer.plan7.HMMFile(hmm_path) as hmm_file:
            hmm = next(hmm_file) # Get the first HMM in the file
    except Exception as e:
        print(f"Error loading HMM: {e}")
        return

    # 2. Identify Alphabet and Constants
    # HMMER determines alphabet automatically (Amino, DNA, RNA)
    if hmm.alphabet.is_amino:
        alphabet = "ACDEFGHIKLMNPQRSTVWY" # Standard 20 AA
        bg_prob = 1 / 20.0
        max_entropy = math.log2(20)
    elif hmm.alphabet.is_dna:
        alphabet = "ACGT"
        bg_prob = 1 / 4.0
        max_entropy = math.log2(4)
    elif hmm.alphabet.is_rna:
        alphabet = "ACGU"
        bg_prob = 1 / 4.0
        max_entropy = math.log2(4)
    else:
        print("Unknown alphabet type.")
        return

    # Map the HMM symbol list to indices for easy lookup
    # hmm.alphabet.symbols gives us the order stored in the HMM object
    hmm_symbols = hmm.alphabet.symbols
    
    # 3. Extract Probabilities
    # hmm.match_emission is a matrix of negative natural log probabilities (scores)
    # Shape: (Length + 1, Alphabet_Size)
    # We convert them back to probabilities: p = exp(-score)
    mat_emissions = np.asarray(hmm.match_emissions)
    probs_matrix = np.exp(-mat_emissions)

    # FIX 2: Check if name is bytes before decoding (Newer pyhmmer returns str)
    hmm_name = hmm.name
    if isinstance(hmm_name, bytes):
        hmm_name = hmm_name.decode('utf-8')
    elif hmm_name is None:
        hmm_name = "Unknown"

    # 4. Build the JSON Structure
    # Structure: A list of dictionaries. Each dict is one position (column).
    # Keys are amino acids, values are the height in bits.
    skylign_data = {
        "name": hmm_name,
        "alphabet": alphabet,
        "heights": []
    }

    # Iterate through positions (1 to M). 
    # Skip index 0 (Node 0 is usually the start/dummy node in HMMER internal rep)
    rows, cols = probs_matrix.shape
    
    for i in range(1, rows):
        row_probs = probs_matrix[i]
        
        # --- The Math (Skylign Logic) ---
        
        # A. Calculate Entropy at this position: H = -sum(p * log2(p))
        # We use a small epsilon (1e-10) to avoid log(0) errors
        current_entropy = -np.sum(row_probs * np.log2(row_probs + 1e-10))
        
        # B. Calculate Information Content (R): R = Max_Entropy - Obs_Entropy
        # (This determines the total height of the stack)
        info_content = max_entropy - current_entropy
        
        # Clamp negative info content to 0 (can happen due to small gap corrections in some models)
        if info_content < 0:
            info_content = 0

        # C. Calculate Height of each letter: Height = Prob * Info_Content
        pos_data = {}
        for idx, symbol in enumerate(hmm_symbols):
            # Only include symbols that are in our standard alphabet
            if symbol in alphabet:
                prob = row_probs[idx]
                letter_height = prob * info_content
                pos_data[symbol] = round(letter_height, 5) # Round for cleaner JSON

        skylign_data["heights"].append(pos_data)

    # 5. Write to File
    with open(output_json_path, 'w') as f:
        json.dump(skylign_data, f, indent=2)

    print(f"Successfully converted {hmm_path} to {output_json_path}")


# --- Usage Example ---
if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Convert HMM output from HMMER into a JSON structure that can be used by Skylign for visualization")
    parser.add_argument("--hmm", required=True, type=str, help="Path to the input HMM file")
    parser.add_argument("--json", required=True, type=str, help="Path to the output JSON file")
    args = parser.parse_args()
    convert_hmm_to_skylign_json(args.hmm, args.json)
