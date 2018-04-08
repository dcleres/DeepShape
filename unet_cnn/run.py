""" MAIN FILE run.py where the implementation and run of the U-net is done.
- Setting of the different parameters.
- Creation of the U-net
- Training of the U-net
- Computing the predictions on the training set
- Testing: computing the predictions on the testing set
# Authors: DC"""


from __future__ import division, print_function
import matplotlib.pyplot as plt
import matplotlib
import numpy as np
import os
from PIL import Image

import unet
from util import *
from extract_data import extract_data
from postprocessing import postprocess_test
import matplotlib.image as mpimg
import image_util
from mask_to_submission import masks_to_submission, patch_to_label

""" --------------------------------------------------------- """
""" ---------- SET UP ALL THE FOLLOWING PARAMETERS ---------- """
""" -------- DO NOT CHANGE ANYTHING BELOW THIS BLOCK -------- """
""" --------------------------------------------------------- """
# Input directories
data_dir = '../training/' # training data directory
train_data_filename = data_dir + 'images/' # training images directory
train_labels_filename = data_dir + 'groundtruth/' # training groundtruth directory
test_data_dir = '../test_set_images/' # testing images directory

# Ouput directory
saving_path = 'output_path/' # predictions will be saved in ./output/saving_path
model_path = 'right_epoch_number/' # the model will be saved in ./unet_trained/model_path

# Training and testing parameters
optimizer = "adam" # can be either "adam" or "momentum"
dropout = 0.9 # probability to keep a node
display_step = 5 # used to display the statistics during the training
nb_layers = 5 # number of layers considered in the U-net
features_root = 8 # initial number of features. For each layer, nb_features = features_root*2^iter

TRAINING_SIZE = 100 # size of the training set
TESTING_SIZE = 50 # size of the testing set
batch_size = 20 # size of the considered training batch at each iteration
epochs = 13 # number of epochs

# Model parameters
foreground_threshold = 0.25 # if the probability of a patch to be a road is over 0.25, we classify it as a road
""" Set carefully Re_run! True if we want to create a new model (i.e. redo the training).
    !!! WARNING !!! The training may take very long. With the optimal parameters
    found, i.e. with 13 epochs, the simulation on our computer (no GPU) took
    around 10h30. """
Re_run = False
pred_on_train = False # True if we also want to compute the predictions on the training set, False if we compute them only on the testing set.

# Data augmentation
resize = True   # True if the images are resized (in general, to win some computational power).
resize_pixel_nb = 256 # Number of pixels on each side of the resized images. Matters only if resize_pixel_nb = True.
angles_train = np.array([30, 45, 60, 90, 180, 270]) # Training set will be augmented with the rotations with those angles of each image.
flip_train = True # True if we augment the training set with a right-column flip of each training image.
angles_test = np.array([90, 180, 270]) # Testing set will be augmented with the rotations with those angles of each image. The mean over the predictions will be considered.
pref_rotation = False # If True, the testing set will be augmented with the rotations such that the main direction of the images is vertical.
flip_test = True # True if we augment the testing set with a right-column flip of each testing image. The mean over the predictions will be considered.
divide_test_in_4 = True # True if the original image is divided into 4 sub-images to have images in the testing set of the same size as the images in the training set.
""" --------------------------------------------------------- """
""" --------------------------------------------------------- """

# Parameters determined by the previous inputs
submission_filename = 'output/'+saving_path+'submission.csv'
path_saved_pred = "output/"+saving_path
nb_imgs_per_img_train = angles_train.shape[0] + flip_train*1 + 1
nb_imgs_per_img_test = angles_test.shape[0] + pref_rotation*1 + flip_test*1 + 1
training_iters = int(np.ceil(nb_imgs_per_img_train*TRAINING_SIZE*epochs/batch_size))

print('Total number of epochs:', epochs)
print('Batch size:', batch_size)
print('Number of iterations per epoch:', training_iters)

print('>>> Creating the net...')
net = unet.Unet(channels=3, n_class=2, layers=nb_layers, features_root=features_root)

# Optimizer = "momentum" or "adam"
print('>>> Creating the trainer...')
trainer = unet.Trainer(net, batch_size=batch_size, optimizer=optimizer)

# ----------------------------
# --------- TRAINING ---------
# ----------------------------
# --- Data extraction ---
if Re_run or pred_on_train:
    print('>>> Loading training data...')
    data, original_pixel_nb, _ = extract_data(train_data_filename, TRAINING_SIZE, \
                        train=True, resize=resize, angles=angles_train, \
                        flip=flip_train, imgType='data', resize_pixel_nb=resize_pixel_nb)
    labels, _, _ = extract_data(train_labels_filename, TRAINING_SIZE, \
                            train=True, resize=resize, angles=angles_train, \
                            flip=flip_train, imgType='label', resize_pixel_nb=resize_pixel_nb)
    img_provider = image_util.SimpleDataProvider(data=data, label=labels, \
                                                 channels=3, n_class=2)

    print('Shape train data:', data.shape)
    print('Shape train labels:', labels.shape)
else:
    original_pixel_nb = 400

if Re_run == True:
    print('>>> Training...')
    trained_model_path = trainer.train(data_provider=img_provider, \
                                output_path="./unet_trained/"+model_path, \
                                training_iters=training_iters, epochs=epochs, \
                                dropout=dropout, display_step=display_step, \
                                prediction_path='./prediction/'+saving_path)
else:
    trained_model_path = "./unet_trained/"+model_path+"model.cpkt"

if pred_on_train:
    print('>>> Making predictions on training set...')
    # Resize back the datasets to get only the original images
    data = data[0::nb_imgs_per_img_train]
    labels = labels[0::nb_imgs_per_img_train]
    # Compute the predictions
    prediction = net.predict(trained_model_path, data)

    print('>>> Saving predictions on training set...')
    # Resize back the images, labels and predictions to the original size
    if resize:
        prediction = np.array([resize_img(prediction[i], original_pixel_nb) for i in range(prediction.shape[0])])
        labels = np.array([resize_img(labels[i], original_pixel_nb) for i in range(labels.shape[0])])
        data = np.array([resize_img(data[i], original_pixel_nb) for i in range(data.shape[0])])

    # Plot and save results on the training set.
    for num in range(0,TRAINING_SIZE):
        fig, ax = plt.subplots(1, 4, sharex=True, sharey=True, figsize=(12,5))
        ax[0].imshow(data[num], aspect="auto")
        ax[1].imshow(labels[num,:,:,1], aspect="auto")
        ax[2].imshow(prediction[num,:,:,1], aspect="auto")
        mask = prediction[num,:,:,1] > foreground_threshold
        ax[3].imshow(mask, aspect="auto")
        ax[0].set_title("Input")
        ax[1].set_title("Ground truth")
        ax[2].set_title("Raw prediction")
        ax[3].set_title("Prediction")
        fig.tight_layout()
        if not os.path.exists(path_saved_pred):
            os.makedirs(path_saved_pred)
        fig.savefig(path_saved_pred+"roadSegmentationTrain"+str(num)+".png")
        plt.close(fig)

    # Clear part of the memory
    del data, labels, img_provider, prediction

# ----------------------------
# --------- TESTING ---------
# ----------------------------
print('>>> Loading testing data...')
test_data, original_test_pixels, pref_angles = extract_data(test_data_dir, \
                                    TESTING_SIZE, train=False, resize=resize, \
                                    angles=angles_test, flip=flip_test, \
                                    imgType='data', divide_test_in_4=divide_test_in_4, \
                                    train_pixel_nb=original_pixel_nb, \
                                    resize_pixel_nb=resize_pixel_nb,
                                    pref_rotation=pref_rotation)

print('Shape test data:', test_data.shape)

# Compute the predictions
print('>>> Making predictions on testing set...')
test_prediction = np.empty((test_data.shape[0],test_data.shape[1],test_data.shape[2],2))
step = 10
# We compute the predictions per image packs to limit the amount of RAM needed
for i in range(0,test_data.shape[0],step):
    if i%50==0:
        print('-- Prediction step', i, 'su', test_data.shape[0])
    test_prediction[i:i+step,...] = net.predict(trained_model_path, test_data[i:i+step,...])

print('>>> Postprocessing...')
test_prediction = postprocess_test(test_prediction, resize=resize, \
                                   train_pixel_nb=original_pixel_nb, \
                                   divide_test_in_4=divide_test_in_4, \
                                   nb_imgs_per_img_test=nb_imgs_per_img_test, \
                                   imgType='data', test_pixel_nb=original_test_pixels,
                                   pref_angles=pref_angles)
test_data = postprocess_test(test_data, resize=resize, \
                             train_pixel_nb=original_pixel_nb, \
                             divide_test_in_4=divide_test_in_4, \
                             nb_imgs_per_img_test=nb_imgs_per_img_test, \
                             imgType='data', angles=angles_test, \
                             flip=flip_test, test_pixel_nb=original_test_pixels, \
                             pref_angles=pref_angles)

print('>>> Saving predictions on testing set...')
# Plot and save results on the testing set.
for num in range(0,TESTING_SIZE):
    fig, ax = plt.subplots(1, 3, sharex=True, sharey=True, figsize=(12,6))
    ax[0].imshow(test_data[num], aspect="auto")
    ax[1].imshow(test_prediction[num,:,:,1], aspect="auto")
    mask = test_prediction[num,:,:,1] > 0.2
    ax[2].imshow(mask, aspect="auto")
    ax[0].set_title("Input")
    ax[1].set_title("Raw prediction")
    ax[2].set_title("Prediction")
    fig.tight_layout()
    if not os.path.exists(path_saved_pred):
        os.makedirs(path_saved_pred)
    fig.savefig(path_saved_pred+"roadSegmentationTest"+str(num+1)+".png")
    plt.close(fig)

# Save results in apropriate folder
for num in range(0,TESTING_SIZE):
    mask_ori = test_prediction[num,:,:,1]
    #mask_ori = test_prediction[num,:,:,1] > 0.2
    mask = img_float_to_uint8(mask_ori)
    # Save raw predictions
    Image.fromarray(mask).save(path_saved_pred+"raw_pred"+str(num+1)+".png")

    pred = np.empty(mask_ori.shape)
    patch_size = 16
    for j in range(0, mask_ori.shape[1], patch_size):
        for i in range(0, mask_ori.shape[0], patch_size):
            patch = mask_ori[i:i + patch_size, j:j + patch_size]
            label = patch_to_label(patch, foreground_threshold)
            pred[i:i+patch_size, j:j+patch_size] = label*np.ones((patch_size, patch_size))

    pred_to_show = binary_to_uint8(pred)
    Image.fromarray(pred_to_show).save(path_saved_pred+"patches_pred"+str(num+1)+".png")

    img = test_data[num,:,:,:]
    oimg = make_img_overlay(img, mask_ori)
    oimg.save(path_saved_pred+"overlay_pred"+str(num+1)+".png")

    oimg = make_img_overlay(img, pred)
    oimg.save(path_saved_pred+"overlay_patches_pred"+str(num+1)+".png")


# Make submission -------------------------
print('>>> Making submission...')
image_filenames = []
for i in range(1, 51):
    image_filename = path_saved_pred+"patches_pred"+str(i)+".png"
    image_filenames.append(image_filename)
masks_to_submission(submission_filename, *image_filenames, foreground_threshold=foreground_threshold)
