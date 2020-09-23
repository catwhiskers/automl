#!/bin/sh

image=$1

mkdir -p test_dir/model
mkdir -p test_dir/output
mkdir -p test_dir/input
mkdir -p test_dir/input/config 
mkdir -p test_dir/input/data
mkdir -p test_dir/input/data/training
mkdir -p test_dir/input/data/testing

rm test_dir/model/*
rm test_dir/output/*
rm test_dir/input/config/*
rm test_dir/input/data/training/*
rm test_dir/input/data/testing/*
echo "{\"label-column\": \"SalePrice\"}" > test_dir/input/config/hyperparameters.json
cp train.csv test_dir/input/data/training/ 
cp test.csv test_dir/input/data/testing/ 

docker run -v $(pwd)/test_dir:/opt/ml --rm ${image} train
