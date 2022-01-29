[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT) 

# Serverless epub to pdf converter using pandoc and latex in a docker image-based AWS lambda function

This is serverless implementation of a file converter using custom built image as a lambda function.
Image is built using Amazon Linux 2, document conversion between markdown formats is performed using pandoc.
Conversion to pdf performed using Latex. Pandoc is compiled from source as there are no binaries for Amazon Linux 2 
(will change with Amazon Linux 2022). Latex is installed as texlive with a minimalistic set of packages.
Conversion by pandoc works pretty reliably. Generation of pdf with latex is not 100% succesfull depending on quality of underlying markdown docuemnts. Generated Docker image is pushed to Elastic Container Registry and from there loaded to lambda.

AWS realization uses one S3 bucket to upload files and generate events. Events trigger Python lambda handler function.
Function downloads files from the source bucket, performs conversion and upload converted files to the result bucket.
The architecture is shown in figure below.

![architecture](/figures/architecture.png)

Structure of the Docker image and details of realisation are described in greater detail in a blog post.

If you are interested in pandoc conversion only - there is an easier way of doing it with a lambda layer, without custom image.
[Check this out](https://github.com/serverlesspub/pandoc-aws-lambda-binary)

If you are interested in Latex alone - there is a simpler [alternative]. (https://github.com/samoconnor/lambdalatex) with lambda layers.
I used both above sources for reference.

If you are interested in exactly what is done here, but this solution looks too complicated - wait for Amazon Linux 2022, it will have pandoc and latex packages [natively](https://docs.aws.amazon.com/linux/al2022/release-notes/all-packages-al2022-20220105.html). 

# Repo structure

```
project
│   README.md - this README file
│   Dockerfile contains Docker image configuration   
│   texlive.profile - conatins profile for texlive installation in the DOcker image
│   S3_access_policy.json - policy to be attached to the lambda execution role
│   
└───app
│   │   handler.py - Python code handling requests
│   │   testbook.epub a test epub document from Gutenberg project
│   │   testbook_2.epub another test document
│   │   ric.sh bash script that checks for the presence of lambda runtime, if not present uses emulator (needed for local testing outside of AWS)
│   
└───figures
    │   architecture.png image showing the architecture

```


# Usage

If not familiar with Docker and AWS read first the blog post with extended instructions. 
If experienced enough 

```console
foo@bar:~$ docker build -t pandoc-lambda .
foo@bar:~$ aws ecr get-login-password | docker login --username AWS --password-stdin 12-digit-id.dkr.ecr.your-aws-region.amazonaws.com
foo@bar:~$ docker tag your-image-name:latest 12-digit-id.dkr.ecr.your-aws-region.amazonaws.com/your-image-name:latest
foo@bar:~$ docker push 12-digit-id.dkr.ecr.your-aws-region.amazonaws.com/your-image-name:latest

```

Then create a lambda function using Image option, load image from ECR.
Cretae source S3 bucket with your-bucket-name, set Create event, set lambda as event target.
Create result bucket with converted-your-bucket-name name.
Add S3 access policy to your lambda execution role allowing read from source and write to results.
Give lambda function large memory and timeout limits to allow it to function (2-3 Gb of memory, and time limit of at least several minutes).

# Local testing with runtime emulator

```console
foo@bar:~$ docker run -p 9000:8080  pandoc-lambda

```

Query with a bucket name 'test' will triger conversion from available test documents without the need to access S3

```console
curl -XPOST "http://localhost:9000/2015-03-31/functions/function/invocations" -d '{  "Records": [  {  "s3": {  "bucket": { "name": "test" }, "object": { "key": "testbook.epub"  }  }  }  ] }'

```
