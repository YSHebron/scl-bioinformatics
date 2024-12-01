param(
    [string]$ppinfile,
    [string]$reffile,
    [string]$outputdir,
    [string]$negfile,
    [string]$filtering,
    [string]$attribs
)

function Help {
@"
usage: .\pipeline2.ps1 [-p [ppinfile]] [-r [reffile]] [-o [outputdir]] [-n [negfile]] [-f [filter]] [-a [attribs]] [-h]

Runs P5COMP on the given PPIN file (ppinfile) and evaluates against the given gold standard (reffile).
Final predicted clusters will be written in outputdir.
Important: Protein names (PID) should be in gene name (ordered locus) or KEGG format (ex. YLR075W) to match gold standards.
UPDATE (11/22/2024): Finally added P5COMP capability.

options:
    -p [ppinfile]       path to PPIN file (.txt) where each row is (u v w) (required)
    -r [reffile]        path to gold standard or reference complexes file (.txt) (required)
    -o [outputdir]      path to output directory (required)
    -n [negfile]        path to negatome (.txt) where each row is (u v) (optional)
    -f [filter]         filtering type (perpair or perprotein)
    -a [attribs]        attributes for evaluation file name of format 'algo-goldstd-ppin', ex: P5COMP-CYC-Collins
    -h                  show this help information
"@
}

function Validate-File {
    param(
        [string]$file
    )
    if (-not (Test-Path $file -PathType Leaf)) {
        Write-Error "$file is not a valid file."
        exit 1
    }
}

function Validate-Directory {
    param(
        [string]$dir
    )
    if (-not (Test-Path $dir -PathType Container)) {
        Write-Error "$dir is not a valid directory."
        exit 1
    }
}

if ($help) {
    Help
    exit 0
}

# if ($args.Count -eq 0) {
#     Write-Error "Error: No options supplied. See help below."
#     Help
#     exit 1
# }

if (-not $ppinfile -or -not $reffile -or -not $outputdir) {
    Write-Error "Error: Missing -p, -r, and/or -o arguments. See help (-h)."
    Help
    exit 1
}

# Create output directory if it doesn't exist
New-Item -ItemType Directory -Force -Path $outputdir | Out-Null

# Clean output files from previous run and retain parent folder
Get-ChildItem $outputdir | Remove-Item -recurse -Force
write-host "Contents of $outputdir deleted..." -ForegroundColor Green

# Validate input files and directories
Validate-File $ppinfile
Validate-File $reffile
Validate-Directory $outputdir

$method = $attribs.Split('-')[0]
switch ($method) {
    "PC2P" {
        Write-Output "RUNNING INDEPENDENT CLUSTERING ALGO:"
        Write-Output "IND 1: Running PC2P..."
        $predictsfile = Join-Path $outputdir "PC2P_predicted.txt"
        $postprocessed = Join-Path $outputdir "PC2P_postprocessed.txt"
        python code/PC2P/PC2P.py $filteredfile $predictsfile -p mp
        python code/PC2P/PC2P_scoring.py $filteredfile $predictsfile $postprocessed
        python code/eval2.py $postprocessed $reffile results.csv auc_pts.csv --attribs $attribs
    }
    "CUBCO+" {
        Write-Output "RUNNING INDEPENDENT CLUSTERING ALGO:"
        Write-Output "IND 2: Running CUBCO+..."
        $predictsfile = Join-Path $outputdir "CUBCO+_predicted.txt"
        $postprocessed = Join-Path $outputdir "CUBCO+_postprocessed.txt"
        python code/CUBCO+/CUBCO.py $filteredfile $outputdir $predictsfile
        python code/CUBCO+/cubco_scoring.py $filteredfile $predictsfile $postprocessed
        python code/eval2.py $postprocessed $reffile results.csv auc_pts.csv --attribs $attribs
    }
    "ClusterOne" {
        Write-Output "RUNNING INDEPENDENT CLUSTERING ALGO:"
        Write-Output "IND 3: Running ClusterOne..."
        $predictsfile = Join-Path $outputdir "ClusterOne_predicted.txt"
        $postprocessed = Join-Path $outputdir "ClusterOne_postprocessed.txt"
        $jarPath = "code/ClusterOne/cluster_one-1.0.jar"
        java -jar $jarPath $filteredfile > $predictsfile

        ## Score ClusterOne clusters
        python code/ClusterOne/cluster_one_scoring.py $ppinfile $predictsfile $postprocessed
        python code/eval2.py $postprocessed $reffile results.csv auc_pts.csv --attribs $attribs
    }
    "P5COMP" {
        write-host "Now running P5COMP..." -ForegroundColor Green

        Write-Output "PPIN: $(Resolve-Path $ppinfile)"
        Write-Output "Ref: $(Resolve-Path $reffile)"
        Write-Output "Output: $(Resolve-Path $outputdir)"

        # Developer parameters
        $filteredfile = "data/Interm/filtered_ppin.txt"
        $decompfile = "data/Interm/decomp_ppin.txt"
        $hubfile = "data/Interm/hub_proteins.txt"
        $iAdjustCD_outfile = "data/Interm/ppin_adjusted.txt"
        
        # Denoising -> data/Interm/filtered_ppin.txt
        ## Filtering: Negatome and either PerProteinPair / PerProtein filtering.
        ## Note: This pipeline is packaged with Negatome 2.0 datasets.
        write-host "PART 1. DENOISING" -ForegroundColor Green
        python code/filtering.py $ppinfile $reffile $filteredfile --negfile $negfile --filtering $filtering

        ### DECOMP 1: Hub Removal
        ### -> data/Interm/ppin_adjusted.txt
        ### -> data/Interm/decomp_ppin.txt, data/Interm/hub_proteins.txt 
        write-host "PART 2. HUB REMOVAL" -ForegroundColor Green
        python code/iAdjustCD.py $filteredfile $iAdjustCD_outfile
        python code/hub_remove.py $filteredfile $hubfile $decompfile
        # At this point, hubfile contains the hub proteins while decompfile contains the decomposed PPIN.
        # The iAdjustCD_outfile contains the rescored PPIN, for use in hub_return.

        write-host "PART 3. COMPONENT CLUSTERING" -ForegroundColor Green

        # Parallel Clustering (Ensemble Clustering)
        ## 1. PC2P with hub return -> data/Results/Dummy/PC2P_predicted.txt, data/Results/Dummy/PC2P_postprocessed.txt
        Write-Output "Running PC2P..."
        $predictsfile_PC2P = Join-Path $outputdir "PC2P_predicted.txt"
        $postprocessed_PC2P = Join-Path $outputdir "PC2P_postprocessed.txt"
        python code/PC2P/PC2P.py $decompfile $predictsfile_PC2P -p mp
        python code/hub_return.py $predictsfile_PC2P $iAdjustCD_outfile $hubfile $filteredfile $postprocessed_PC2P

        ## 2. CUBCO+ with hub return -> data/Results/Dummy/CUBCO+_predicted.txt, data/Results/Dummy/CUBCO+_postprocessed.txt
        ## Note: omit '+' character from varnames
        Write-Output "Running CUBCO+..."
        $predictsfile_CUBCO = Join-Path $outputdir "CUBCO+_predicted.txt"
        $postprocessed_CUBCO = Join-Path $outputdir "CUBCO+_postprocessed.txt"
        python code/CUBCO+/CUBCO.py $decompfile $outputdir $predictsfile_CUBCO
        python code/hub_return.py $predictsfile_CUBCO $iAdjustCD_outfile $hubfile $filteredfile $postprocessed_CUBCO

        ## 3. ClusterOne with hub return -> data/Results/Dummy/ClusterOne_predicted.txt, data/Results/Dummy/ClusterOne_postprocessed.txt
        Write-Output "Running ClusterOne..."
        $predictsfile_ClusterOne = Join-Path $outputdir "ClusterOne_predicted.txt"
        $postprocessed_ClusterOne = Join-Path $outputdir "ClusterOne_postprocessed.txt"
        $jarPath = "code/ClusterOne/cluster_one-1.0.jar"
        java -jar $jarPath $filteredfile > $predictsfile_ClusterOne

        ## Score clusters
        python code/ClusterOne/cluster_one_scoring.py $ppinfile $predictsfile_ClusterOne $postprocessed_ClusterOne

        # Ensemble Clustering
        write-host "PART 4 (FINALE). ENSEMBLE CLUSTERING" -ForegroundColor Green
        $final_clusters = Join-Path $outputdir "${attribs}_clusters.txt"
        python code/ensemble.py $postprocessed_ClusterOne $postprocessed_CUBCO $postprocessed_PC2P $final_clusters

        # Evaluation (currently assumes running from root)
        python code/eval2.py $final_clusters $reffile results.csv auc_pts.csv --attribs $attribs
    }
    default {
        Write-Error "Unknown method: $method"
        exit 1
    }
}
