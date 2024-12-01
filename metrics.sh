#!/bin/bash
# Usage: ./metrics.sh <resultsfile> <recreate?>
# This is usually run using the batch.sh script to generate multiple iterations of perf eval results.

declare -a methods=(
    [0]=PC2P
    [1]=CUBCO+
    [2]=ClusterOne
    [3]=MCL
)

declare -a gldstds=(
    [0]=CYC
    [1]=SGD
)

declare -a ppins=(
    [0]=Collins
    [1]=Gavin
    [2]=KroganCore
    [3]=KroganExt
    [4]=BIM
)

# Results File (file containing the computed metrics)
resultsfile=$1
recreate=$2     # true or false (recreate the results file or not, can be handled by batch.sh)

if [ "$recreate" = true ]
then
    echo "Method,GldStd,PPIN,Predicts,Refs,Precision,Recall,F0.5-score,F1-score,F2-score,AUC-PR,MMR,Sensitivity,PPP,Accuracy,F-Match,Separation" > $resultsfile
fi

p=
r=
o="data/Results/Dummy"

for gldstd in "${gldstds[@]}"; do
    case "$gldstd" in
        "CYC") r=eval/CYC2008.txt
        ;;
        "SGD") r=eval/SGD.txt
        ;;
    esac
    for ppin in "${ppins[@]}"; do
        case "$ppin" in
            "Collins") p=eval/Collins.txt
            ;;
            "Gavin") p=eval/Gavin.txt
            ;;
            "KroganCore") p=eval/KroganCore.txt
            ;;
            "KroganExt") p=eval/KroganExt.txt
            ;;
            "BIM") p=eval/BIM.txt
            ;;
        esac
        # P5COMP
        ./pipeline1.sh -p $p -r $r -o $o \
            -n eval/Negatome.txt -f perpair -a "P5COMP-${gldstd}-${ppin}" -R $resultsfile
        # PC2P, CUBCO+, and ClusterOne
        for method in "${methods[@]}"; do
            ./pipeline2.sh -p $p -r $r -o $o -f perpair -a "${method}-${gldstd}-${ppin}" -R $resultsfile
        done
    done
done