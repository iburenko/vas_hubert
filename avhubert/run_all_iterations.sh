#!/bin/bash -l

function iteration_step() {
    echo "start iteration for "$CLUSTER_ITER
    cd clustering
    echo "submitting clustering"
    if (( $CLUSTER_ITER==1 )); then
        ckpt_path="None"
    else
        ckpt_path="/home/atuin/b105dc/data/work/iburenko/av_hubert/results/$output_dir_suffix/checkpoints/checkpoint_best.pt"
    fi
    if (( $CLUSTER_ITER > 2 )); then
        python submit_cluster.py \
                --tsv /home/atuin/b105dc/data/datasets/ellen_show_datasets/av_hubert_clusters/300_frames/data \
                --output /home/atuin/b105dc/data/datasets/ellen_show_datasets/av_hubert_clusters/300_frames/$output_dir_suffix/clusters_iter$CLUSTER_ITER \
                --ckpt $ckpt_path \
                --ncluster $N_CLUSTER --nshard 10 --mfcc $USE_MFCC --percent 0.15
    fi
    echo "clustering finished"
    cd ..
    echo "submitting pretraining"
    touch semaphor/$output_dir_suffix/test$CLUSTER_ITER.ok
    echo Start clustering step $CLUSTER_ITER iteration step $RUN_ITER >> semaphor/$output_dir_suffix/test$CLUSTER_ITER.ok
    sbatch run_av_hubert_$modality.sh $CLUSTER_ITER $RUN_ITER $modality $clustering
    echo "pretraining finished"
}

module load python
conda activate avh

modality=$1
clustering="mfcc"
output_dir_suffix=$modality"_"$clustering

mkdir -p semaphor/$output_dir_suffix

N_CLUSTER=100
USE_MFCC=True

if [[ $modality == "image_skeleton" ]]; then
    CLUSTER_ITER=3
    RUN_ITER=1
    USE_MFCC=False
else
    CLUSTER_ITER=2
    RUN_ITER=2
    USE_MFCC=False
fi

iteration_step

sleep 2
USE_MFCC=False

while true
do
    if [[ -e semaphor/$output_dir_suffix/test$CLUSTER_ITER.ok ]]; then
        sleep 60
    else
        if (( $CLUSTER_ITER==5 )); then
            rm -rf semaphor/$output_dir_suffix
            break
        fi
        CLUSTER_ITER=$(($CLUSTER_ITER+1))
        iteration_step
    fi
done