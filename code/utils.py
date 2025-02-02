import networkx as nx
import pandas as pd
from pathlib import Path
from termcolor import colored

def read_ppin_to_graph(ppinfile: Path) -> nx.Graph:
    """
    Reads an input PPIN and converts it to a NetworkX Graph.
    Recommended: .txt without header where each row is (u v w).
    Allowed: .csv/.tsv with header (u, v, w) where each row is (u, v, w).

    Args:
        ppinfile (Path): path to PPIN
    """
    
    if ppinfile.suffix != ".txt":
        df = pd.read_csv(ppinfile)
        return nx.from_pandas_edgelist(df, source = "u", target = "v", create_using = nx.Graph, edge_attr = "w")
    else:
        return nx.read_weighted_edgelist(ppinfile, create_using = nx.Graph, nodetype = str)

    
def read_ppin_to_dict(ppinfile: Path, weighted=False) -> dict:
    ppin = {}
    with open(ppinfile) as f:
        if weighted:
            for line in f:
                u, v, w = line.split()
                key = (u, v) if u < v else (v, u) # lexical ordering
                ppin[key] = float(w)
        else:
            for line in f:
                u, v = line.split()[:2] # exclude score
                key = (u, v) if u < v else (v, u) # lexical ordering
                ppin[key] = None
            
    return ppin


def write_ppin_dict_to_txt(ppin: dict, outfile: Path, weighted=False):
    outfile.parent.mkdir(exist_ok=True, parents=True)
    # PPIN will be written in decreasing order of reliability
    ppin = dict(sorted(ppin.items(), key=lambda ppi: ppi[1], reverse=True))
    with open(outfile, 'w') as f:
        if weighted:
            for ppi in ppin:
                u, v = ppi
                w = ppin[ppi]
                f.write(f"{u} {v} {w}\n")
        else:
            for ppi in ppin:
                u, v = ppi
                f.write(f"{u} {v}\n")


def printc(str, color="cyan", *args, **kwargs):
    "`print` wrapper that adds color to the console output."
    print(colored(str, color), end=kwargs.get("end", None))