import pyhmmer
import logomaker
import pandas as pd
import numpy as np
import matplotlib.pyplot as plt

def plot_hmm_logo(hmm_path, output_file):
    # 1. Load the HMM using PyHMMER
    with pyhmmer.plan7.HMMFile(hmm_path) as hmm_file:
        hmm = next(hmm_file)
    
    # 2. Extract emission probabilities (converted from negative natural log)
    # HMMER stores scores as -ln(prob). We convert back to probabilities.
    # The first row (index 0) is usually the start node, so we skip if needed, 
    # but HMMER usually indexes 1..M. PyHMMER gives us the matrix directly.
    
    # Get the emission probabilities for the match states
    # mat_emissions is typically shape (M+1, K) where M is length, K is alphabet size
    emissions = np.asarray(hmm.mat_emission)
    
    # Convert from negative log space to probability space: p = exp(-score)
    probs = np.exp(-emissions)
    
    # Clean up: The 0th row in HMMER is often a dummy or begin state. 
    # Valid positions are usually 1 to M.
    probs = probs[1:] 

    # Create a DataFrame with correct column names (Amino Acids or DNA)
    alphabet = [sym for sym in hmm.alphabet.symbols]
    df_probs = pd.DataFrame(probs, columns=alphabet)

    # 3. Calculate Information Content (Height of the stack)
    # Formula: R_i = log2(20) - (Entropy_i + small_correction)
    # For simplicity here, we calculate standard Information Content:
    # Height = Total_Information - Entropy
    bg_prob = 1 / len(alphabet)
    max_entropy = np.log2(len(alphabet))
    
    # Entropy per position: -sum(p * log2(p))
    entropy = -np.sum(df_probs * np.log2(df_probs + 1e-10), axis=1)
    info_content = max_entropy - entropy
    
    # Scale the letter heights by the information content
    df_info = df_probs.multiply(info_content, axis=0)

    # 4. Generate Logo using Logomaker
    logo = logomaker.Logo(df_info,
                          shade_below=.5,
                          fade_below=.5,
                          font_name='Arial Rounded MT Bold')

    logo.style_spines(visible=False)
    logo.style_spines(spines=['left', 'bottom'], visible=True)
    logo.ax.set_ylabel('Information (bits)')
    logo.ax.set_xlabel('Position')
    
    # Save or show
    plt.savefig(output_file, dpi=300)
    print(f"Logo saved to {output_file}")

#if __name__ == "main":
# plot_hmm_logo("my_profile.hmm", "logo.png")
