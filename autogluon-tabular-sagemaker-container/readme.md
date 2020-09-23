# Deploy AutoGluon MxNet on SageMaker

![Build Status](https://codebuild.eu-west-1.amazonaws.com/badges?uuid=eyJlbmNyeXB0ZWREYXRhIjoiejdGeFBYcGFCY1J3aC9HUWhwbE95ZEkrcVluZFZvNXE2aG11bDZoMzFHQnJjNmhFWVF1NlpTdUNYSzNBRXdnZ1hNd2txYVJybVhWYWtFK0xRektkN2VBPSIsIml2UGFyYW1ldGVyU3BlYyI6IlVPSldqa0VTUWo4V1M1eG0iLCJtYXRlcmlhbFNldFNlcmlhbCI6MX0%3D&branch=master)


![AutoGluon on SageMaker](./autogluon-on-sagemaker.png)

This repository is a getting-started/ready-to-use kit for deploying your own automl model with AutoGluon MxNet on SageMaker. With SageMaker, you can have
a real-time inference endpoint or run batch predictions with batch transforms. 

## Getting started

### Host the docker image on AWS ECR

* You can train your model locally or on SageMaker. Your model is automatically saved to the SageMaker model directory and, packaged and uploaded to S3 by SageMaker.

* Required packages are already included in the `requirements.txt`. We also defined the installation of some packages in the `Dockerfile`.

* To get your model working make the necessary code changes in the `transformation` function in the file `/model/predictor.py`.

* Run `/build_and_push.sh <image_name` to deploy the docker image to AWS Elastic Container Registry

### Deploy your model in SageMaker
I have included an example notebook which includes how to train locally and on a SageMaker ML instance.

* Start a jupyter notebook called [notebooks/deploy_model.ipynb](notebooks/deploy_model.ipynb)

```python
import boto3
import sagemaker as sage
from sagemaker import get_execution_role
from sagemaker.predictor import csv_serializer

image_tag = 'logistic-regression' # use the <image_name> defined earlier
sess = sage.Session()
role = get_execution_role()
account = sess.boto_session.client('sts').get_caller_identity()['Account']
region = sess.boto_session.region_name
image = f'{account}.dkr.ecr.{region}.amazonaws.com/{image_tag}:latest'

training_data = 's3://autogluon/datasets/Inc/train.csv'
test_data = 's3://autogluon/datasets/Inc/test.csv'

artifacts = 's3://<your-bucket>/artifacts'
sm_model = sage.estimator.Estimator(image,
                                   role,
                                   1,
                                   'ml.c4.xlarge', output_path=artifacts, sagemaker_session=sess)

# Run the train program because it is expected
sm_model.fit(
    {'training': training_data, 'testing': test_data}
)

# Deploy the model.
predictor = sm_model.deploy(1, 'ml.m4.xlarge', serializer=csv_serializer)
```

## More information
SageMaker supports two execution modes: _training_ where the algorithm uses input data to train a new model (we will not use this) and _serving_ where the algorithm accepts HTTP requests and uses the previously trained model to do an inference.

In order to build a production grade inference server into the container, we use the following stack to make the implementer's job simple:

1. __[nginx][nginx]__ is a light-weight layer that handles the incoming HTTP requests and manages the I/O in and out of the container efficiently.
2. __[gunicorn][gunicorn]__ is a WSGI pre-forking worker server that runs multiple copies of your application and load balances between them.
3. __[flask][flask]__ is a simple web framework used in the inference app that you write. It lets you respond to call on the `/ping` and `/invocations` endpoints without having to write much code.

## The Structure of the Sample Code

The components are as follows:

* __Dockerfile__: The _Dockerfile_ describes how the image is built and what it contains. It is a recipe for your container and gives you tremendous flexibility to construct almost any execution environment you can imagine. Here. we use the Dockerfile to describe a pretty standard python science stack and the simple scripts that we're going to add to it. See the [Dockerfile reference][dockerfile] for what's possible here.

* __build\_and\_push.sh__: The script to build the Docker image (using the Dockerfile above) and push it to the [Amazon EC2 Container Registry (ECR)][ecr] so that it can be deployed to SageMaker. Specify the name of the image as the argument to this script. The script will generate a full name for the repository in your account and your configured AWS region. If this ECR repository doesn't exist, the script will create it.

* __model__: The directory that contains the application to run in the container. See the next session for details about each of the files.

* __docker-test__: A directory containing scripts and a setup for running a simple training and inference jobs locally so that you can test that everything is set up correctly. See below for details.

### The application run inside the container

When SageMaker starts a container, it will invoke the container with an argument of either __train__ or __serve__. We have set this container up so that the argument in treated as the command that the container executes. When training, it will run the __train__ program included and, when serving, it will run the __serve__ program.

* __train__: We will only copy the model to `/opt/ml/model.pkl` so SageMaker will create an artifact.
* __serve__: The wrapper that starts the inference server. In most cases, you can use this file as-is.
* __wsgi.py__: The start up shell for the individual server workers. This only needs to be changed if you changed where predictor.py is located or is named.
* __predictor.py__: The algorithm-specific inference server. This is the file that you modify with your own algorithm's code.
* __nginx.conf__: The configuration for the nginx master server that manages the multiple workers.

### Setup for local testing

The subdirectory local-test contains scripts and sample data for testing the built container image on the local machine. When building your own algorithm, you'll want to modify it appropriately.

* __train-local.sh__: Instantiate the container configured for training.
* __serve-local.sh__: Instantiate the container configured for serving.
* __predict.sh__: Run predictions against a locally instantiated server.
* __test-dir__: The directory that gets mounted into the container with test data mounted in all the places that match the container schema.
* __payload.csv__: Sample data for used by predict.sh for testing the server.

#### The directory tree mounted into the container

The tree under test-dir is mounted into the container and mimics the directory structure that SageMaker would create for the running container during training or hosting.

* __input/config/hyperparameters.json__: The hyperparameters for the training job.
* __input/data/training/leaf_train.csv__: The training data.
* __model__: The directory where the algorithm writes the model file.
* __output__: The directory where the algorithm can write its success or failure file.

## Environment variables

When you create an inference server, you can control some of Gunicorn's options via environment variables. These
can be supplied as part of the CreateModel API call.

    Parameter                Environment Variable              Default Value
    ---------                --------------------              -------------
    number of workers        MODEL_SERVER_WORKERS              the number of CPU cores
    timeout                  MODEL_SERVER_TIMEOUT              60 seconds
