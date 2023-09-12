#!/bin/bash -l

#SBATCH --job-name=avh_image_skeleton_audio
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH -C a100_80  
#SBATCH --gres=gpu:a100:8
#SBATCH --time=24:00:00
#SBATCH --signal=B:SIGUSR1@15
#SBATCH --export=NONE    

unset SLURM_EXPORT_ENV

module load python
conda activate avh

function sig_handler_USR1()
{
        echo "run iter = "$RUN_ITER
        echo "function sig_handler_USR1 called"
        if (( $RUN_ITER < 2 )); then
            sbatch run_av_hubert_$modality.sh $CLUSTER_ITER $(($RUN_ITER+1)) $modality $clustering
        else
            echo "remove file in run av hubert script"
            rm semaphor/$output_dir_suffix/test$CLUSTER_ITER.ok
            # rm -rf $output_dir_suffix
        fi
        exit 2
}

trap 'sig_handler_USR1' SIGTERM SIGUSR1

# cp $DATASET/ellen_show_datasets/ellen_2016_300_frames.tar $TMPDIR
# cd $TMPDIR
# tar xf ellen_2016_300_frames.tar
# cp /home/atuin/b105dc/data/datasets/ellen_show_datasets/av_hubert_clusters/300_frames/valid.tsv $TMPDIR/ellen_degeneres_2016_all_data_300_frames
# cp /home/atuin/b105dc/data/datasets/ellen_show_datasets/av_hubert_clusters/300_frames/train.tsv $TMPDIR/ellen_degeneres_2016_all_data_300_frames

cd /home/hpc/b105dc/b105dc10/av_hubert/avhubert
CLUSTER_ITER=$1
RUN_ITER=$2
modality=$3
clustering=$4

if (( $CLUSTER_ITER==1 )); then
    LABEL_RATE=100
else
    LABEL_RATE=25
fi

output_dir_suffix=$modality"_"$clustering

if [[ $modality == "skeleton" ]]; then
    TOKENS=1200
else
    TOKENS=1200
fi

echo "modality = "$modality
echo "label rate = "$LABEL_RATE 
echo "run iter = "$RUN_ITER
echo "cluster iter = "$CLUSTER_ITER
echo "tokens = "$TOKENS
echo "start av hubert"
srun fairseq-hydra-train \
    --config-dir /home/hpc/b105dc/b105dc10/av_hubert/avhubert/conf/pretrain \
    --config-name base_lrs3_iter$CLUSTER_ITER.yaml \
    task.data=/home/atuin/b105dc/data/datasets/ellen_show_datasets/av_hubert_clusters/300_frames/data \
    task.label_dir=/home/atuin/b105dc/data/datasets/ellen_show_datasets/av_hubert_clusters/300_frames/$output_dir_suffix/clusters_iter$CLUSTER_ITER \
    model.label_rate=$LABEL_RATE \
    +model.input_modality=$modality \
    dataset.max_tokens=$TOKENS \
    hydra.run.dir=/home/atuin/b105dc/data/work/iburenko/av_hubert/results/$output_dir_suffix \
    common.user_dir=`pwd`
echo "av hubert finished"

# Debugging:
# srun fairseq-hydra-train \
#     --config-dir /home/hpc/b105dc/b105dc10/av_hubert/avhubert/conf/pretrain \
#     --config-name base_lrs3_iter1.yaml \
#     task.data=$DATASET/ellen_show_datasets/ellen_degeneres_2016_all_data_300_frames \
#     task.label_dir=/home/atuin/b105dc/data/datasets/ellen_show_datasets/av_hubert_clusters/300_frames \
#     model.label_rate=100 \
#     hydra.run.dir=/home/atuin/b105dc/data/work/iburenko/av_hubert/results \
#     common.user_dir=`pwd`

