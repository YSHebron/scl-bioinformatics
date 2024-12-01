#!/bin/bash
# Usage: ./batch.sh
echo "Method,GldStd,PPIN,Predicts,Refs,Precision,Recall,F0.5-score,F1-score,F2-score,AUC-PR,MMR,Sensitivity,PPP,Accuracy,F-Match,Separation" > results.csv

for i in {1..3}
do
    # Usage of metrics.sh: ./metrics.sh <resultsfile> <recreate?>
    # Currently: results3.csv contains the most updated results (for cleanup)
    ./metrics.sh results3.csv false
done