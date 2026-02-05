
import pandas as pd


def count_lengths(count_file: str, frac: float) -> pd.DataFrame:
    """
    Load and trim length histogram data

    This function can also trim ends of the data. The method to do this
    is borrowed from the original Perl code and it seems to include a
    certain percentage of the total count.

    Parameters
    ----------
        count_file
            path to a 2 column tsv (length and count)
        frac
            percentage of counts to include

    Returns
    -------
        A pandas DataFrame object with "count" and "length" columns
    """
    df = pd.read_csv(count_file, sep='\s+')
    df["sequence_sum"] = df["count"].cumsum()
    # trim values using --frac value
    end_trim = int(df["count"].sum() * (1.0 - frac) / 2.0)
    df = df[(df["sequence_sum"] >= end_trim) & (df["sequence_sum"] - df["count"] <= df["count"].sum() - end_trim)]
    df = df.drop(["sequence_sum"], axis=1)

    return df


def compute_outlying_groups(group_edge_counts: pd.DataFrame, min_num_edges: int, min_num_groups: int) -> set[int]:
    """
    Determine groups to exclude from plots

    Considers groups in sorted order and locates the first and last group which has less than
    ``min_num_edges``. Cuts groups that are less than the first or greater than the last group. Some
    groups between these endpoints may still have less than `min_num_edges`. If the the number of
    groups present after removing the outliers is less than `min_group_size`, the upper cutoff
    index is incremented until the group size meets the minimum or no more groups are left to
    include.

    Parameters
    ----------
        group_metadata
            cache metadata from `group_output_data`

        min_num_edges
            minimum number of edges needed to retain a group

        min_num_groups
            keep at least this many groups (may override min_num_edges)

    Returns
    -------
        A set of group numbers to exclude
    """
    sizes = sorted(group_edge_counts.itertuples(index=False))

    lower_bound_idx = 0
    upper_bound_idx = 0
    # find first group with at least min_num_edges edges
    for i, t in enumerate(sizes):
        if t.edge_count >= min_num_edges:
            lower_bound_idx = i
            break

    # find last group with at least min_num_edges edges
    for i, t in enumerate(reversed(sizes)):
        if t.edge_count >= min_num_edges:
            upper_bound_idx = i
            break

    # ensure we have at least min_num_groups, walk upper index forward if not
    while upper_bound_idx < len(sizes) and upper_bound_idx - lower_bound_idx + 1 < min_num_groups:
        upper_bound_idx += 1
    # extract `alignment_score`s from sizes array, put in Set of O(1) lookups in subsequent filter
    if upper_bound_idx - lower_bound_idx + 1 < min_num_groups:
        return set()
    else:
        groups_to_keep = set(k.alignment_score for k in sizes[lower_bound_idx:-upper_bound_idx])
        return set([k.alignment_score for k in sizes]) - groups_to_keep


def delete_outlying_groups(stats: pd.DataFrame, groups_to_delete: set) -> pd.DataFrame:
    """
    Removes outlying groups from metadata

    Parameters
    ----------
        stats
            dataframe of boxplot stats

        groups_to_delete
            set of alignment scores to exclude from the returned dataframe

    Returns
    -------
        Metadata dict with groups removed
    """
    return stats[~stats["alignment_score"].isin(groups_to_delete)]

