# About this repository

**Notes 2016-01-08**: I noticed the json file for imagenet on S3 was corrupted with only about 380k valid captions. This is now fixed and the json file contains ~919k captions. 

When I started working on deep learning, I found it pretty hard to find quality datasets. Often there were missing pictures, or broken links and so on. 

As a result, I started building my own collection of scripts and datasets. The intention in this project is to make it easy for others to get their hands of the raw material needed to create quality image classifiers. 

Note that images and other attributes referenced in this work are the property of their respective owners. This is a passthrough to the conditions expressed by them. 

# Datasets
## MS COCO
### Specifications

* Source: http://mscoco.org/
* Nb Images: ~125.000
* Size on disk: ~30GB

### About the dataset

[MS Coco](http://mscoco.org/) is a dataset of common objects taken and described in context. It is used in NeuralTalk. 

Just run the 

	mscoco/build-dataset.sh path/to/folder

This script will first download original files from the website. As they are pretty big, it will then check the md5sum and restart if one has failed. 

Then it will unpack them, and prepare the dataset for use by [NeuralTalk2](https://github.com/karpathy/neuraltalk2)

## im2text
### Specifications

* Source: http://vision.cs.stonybrook.edu/~vicente/sbucaptions/
* Nb Images: ~900.000
* Size on disk: ~120GB (300GB needed to download)

### About the dataset

This comes from the [SBU dataset](http://vision.cs.stonybrook.edu/~vicente/sbucaptions/), that classifies about a million images a little bit like MS Coco. The main difference is that MS Coco has several captions for each image, and this one only has one. 

As there is a very large number of images which take time to download, there are 2 ways of downloading this. 

If you select to build the dataset, you can specify the first image and how many images you'd like to download

	build-dataset.sh /path/to/target first_image nb_images

By default this will spin 10 concurrent threads. On my 100Mbps fiber, it took me a couple of days to complete. 

If you select to download the dataset

	download-dataset.sh /path/to/target

then 12 10GB files will be downloaded from Amazon S3 and rebuilt together. This may be a bit faster, but has a higher risk of failure. I would recommend that if you use a public cloud instance to run your compute. 

The dataset contains a folder with ~890k images, along with a JSON file on the same model as the one used by MS Coco. As a result, you can combine the 2 to get a larger set. 

Notes: 
* I didn't have a chance to run a training model yet on this set, hence I couldn't check if all images were OK. However, I suspect it won't be very good as there is only 1 caption per image.
* This set requires AT LEAST 300GB free on the destination hard drive

## ImageNet
### Specifications

* Source: http://www.image-net.org/
* Nb Images: N/A
* Size on disk: N/A

### About the dataset

[ImageNet](http://www.image-net.org/) is a project to index and categorize natural images of all sorts. It has supposedly about 14M images, with their description in English from Wordnet. 

I find that a large number of images are missing in this project. Apparently it is possible to get the original dataset from them if the project is non commercial, but I couldn't find how (didn't get an answer yet)

The **all15** version is my script to download the complete dataset. 
The other **ilsvrc14** is a subset of about 1000 classes used for smaller competitions. 





